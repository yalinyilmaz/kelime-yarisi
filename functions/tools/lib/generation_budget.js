import {existsSync, lstatSync, mkdirSync, readFileSync, realpathSync, renameSync, unlinkSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';

import {GENERATION_LIMITS,generationDay as dayKey,blankGenerationDay as blankDay,validateGenerationLedger as validateState,
  approvedCounts,monthlyCharge,generationStopReason,reserveRequest,settleUsage} from '../../src/generation_policy.js';
export {GENERATION_LIMITS} from '../../src/generation_policy.js';
const lengths=[4,5,6,7,8,9,10];

export class GenerationBudget {
  constructor(root,{now=Date.now,limits=GENERATION_LIMITS}={}) {
    this.now=now;this.limits=limits;this.startedAt=now();this.date=dayKey(this.startedAt);
    this.directory=resolve(realpathSync(root),'.local');
    this.file=resolve(this.directory,'question-generation-ledger.json');
    this.lock=resolve(this.directory,'question-generation-ledger.lock');
    this.state={version:1,days:{}};
    this.load();
  }
  load() {
    if(existsSync(this.directory)&&(!lstatSync(this.directory).isDirectory()||realpathSync(this.directory)!==this.directory))throw new Error('Generation ledger directory must not be a symlink.');
    if(existsSync(this.file)) {
      if(!lstatSync(this.file).isFile()||lstatSync(this.file).isSymbolicLink())throw new Error('Generation ledger must be a regular file.');
      this.state=validateState(JSON.parse(readFileSync(this.file,'utf8')));
    }
  }
  acquire() {
    mkdirSync(this.directory,{recursive:true,mode:0o700});
    this.load();
    // An interrupted process leaves the lock in place: inspect it, never auto-retry.
    writeFileSync(this.lock,`${process.pid}\n`,{flag:'wx',mode:0o600});
    this.locked=true;
    this.load();
    this.state.days[this.date]??=blankDay();
    const day=this.day;
    // A killed/failed request can still be billed. Retain its full reservation.
    day.pending=null;
    for(const attempt of day.attempts) if(attempt.status==='started') {attempt.status='failed';day.consecutiveFailures++;}
    this.save();
  }
  get day() {return this.state.days[this.date]??blankDay();}
  save() {
    if(!this.locked)throw new Error('Generation budget lock required.');
    const temporary=`${this.file}.${process.pid}.tmp`;
    writeFileSync(temporary,`${JSON.stringify(this.state,null,2)}\n`,{flag:'wx',mode:0o600});
    renameSync(temporary,this.file);
  }
  close() {if(this.locked){unlinkSync(this.lock);this.locked=false;}}
  attemptedIds() {return new Set(Object.values(this.state.days).flatMap(d=>d.attempts.map(a=>a.answerId)));}
  approvedCounts() {return approvedCounts(this.day);}
  monthlyMicros() {return monthlyCharge(this.state,this.date);}
  stopReason({duringAttempt=false}={}) {
    return generationStopReason(this.state,this.date,{now:this.now(),startedAt:this.startedAt,limits:this.limits,duringAttempt});
  }
  begin(source,{dailyCredit=false}={}) {
    const reason=this.stopReason();if(reason)throw new Error(`Generation stopped: ${reason}.`);
    if(this.attemptedIds().has(source.answerId))throw new Error('Word already attempted; automatic retries are disabled.');
    const attempt={answerId:source.answerId,length:source.letterCount,status:'started',dailyCredit};
    this.day.attempts.push(attempt);this.save();return attempt;
  }
  async fetch(url,request,transport=fetch) {
    reserveRequest(this.state,this.date,url,request,{now:this.now(),startedAt:this.startedAt,limits:this.limits});
    this.save(); // Persist before network I/O. Unknown usage retains the reservation.
    return transport(url,request);
  }
  recordUsage(usage) {
    const error=settleUsage(this.day,usage);this.save();
    if(error)throw new Error(error);
  }
  finish(attempt,status) {
    if(attempt.status!=='started')throw new Error('Attempt already completed.');
    attempt.status=status;this.day.pending=null; // Unknown usage keeps its reserved charge.
    this.day.consecutiveFailures=status==='approved'?0:this.day.consecutiveFailures+1;
    this.save();
  }
  report() {
    const approved=this.approvedCounts();
    return {date:this.date,timeZone:'Europe/Istanbul',attempts:this.day.attempts.length,apiCalls:this.day.calls,
      chargedOrReservedUsd:this.day.chargedMicros/1e6,monthlyChargedOrReservedUsd:this.monthlyMicros()/1e6,
      approvedToday:approved,missingToday:Object.fromEntries(lengths.map(l=>[l,Math.max(0,this.limits.approvedPerLength-approved[l])])),
      consecutiveFailures:this.day.consecutiveFailures,stopped:this.stopReason(),limits:this.limits};
  }
}

// Each source is tried at most once. A rejection consumes an attempt, never adds
// another iteration by itself. Only distinct remaining sources can fill a gap.
export async function runBoundedBatch({budget,sources,pool,limit=20,daily=false,dailyCredit=daily,generate,persist,select}) {
  let completed=0;
  let reason;
  while(completed<limit) {
    reason=budget.stopReason();if(reason)break;
    const counts=budget.approvedCounts();
    if(daily&&lengths.every(l=>counts[l]>=budget.limits.approvedPerLength)){reason='daily-target-reached';break;}
    const attempted=budget.attemptedIds();
    const available=sources.filter(s=>!attempted.has(s.answerId)&&(!daily||counts[s.letterCount]<budget.limits.approvedPerLength));
    const source=select(available,pool);
    if(!source){reason='source-stock-exhausted';break;}
    const attempt=budget.begin(source,{dailyCredit});
    try {
      const question=await generate(source,pool);
      await persist(question); // Save approved record before granting daily credit.
      pool.push(question);budget.finish(attempt,question.review.status);completed++;
    }catch(error){if(attempt.status==='started')budget.finish(attempt,'failed');throw error;}
  }
  return {completed,reason:reason??'batch-limit',...budget.report()};
}
