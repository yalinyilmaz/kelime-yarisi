import {randomUUID} from 'node:crypto';
import {LENGTHS,candidatePrompt,isPublished,validateQuestion,validatePool} from './content.js';
import {generateQuestion,replenishmentPlan} from './content_generation.js';
import {createQuestionSet,fitsDraft} from './question_sets.js';
import {transaction} from './database_transaction.js';
import {loadPublishedPool,decodeStoredQuestion} from './published_pool.js';
import {compactQuestion} from './question_storage.js';
import {GENERATION_LIMITS,generationDay,blankGenerationDay,validateGenerationLedger,approvedCounts,
  monthlyCharge,generationStopReason,reserveRequest,settleUsage} from './generation_policy.js';

const leaseMs=35*60*1000;
function normalize(raw) {
  const state=raw??{version:1};
  if(state.version===undefined&&!state.ledger)state.version=1; // A control-only bootstrap has no spending state yet.
  if(state.version!==1)throw new Error('Invalid cloud generation state.');
  state.ledger??={version:1};state.ledger.days??={};state.outbox??={};state.backlog??={};
  for(const day of Object.values(state.ledger.days)){day.attempts??=[];day.pending??=null;}
  validateGenerationLedger(state.ledger);return state;
}
export function cloudGenerationReport(state,date,reason,limits=GENERATION_LIMITS) {
  const day=state.ledger.days[date]??blankGenerationDay(),approved=approvedCounts(day);
  return {date,reason,attempts:day.attempts.length,apiCalls:day.calls,approvedToday:approved,
    setsPublishedToday:Object.keys(day.publishedSetIds??{}).length,
    missingSetsToday:Math.max(0,3-Object.keys(day.publishedSetIds??{}).length),
    draftQuestions:Object.keys(state.draft?.questions??{}).length,
    draftByLength:Object.fromEntries(LENGTHS.map(length=>[length,Object.values(state.draft?.questions??{}).map(decodeStoredQuestion).filter(q=>q.letterCount===length).length])),
    backlogQuestions:Object.keys(state.backlog??{}).length,
    chargedOrReservedUsd:day.chargedMicros/1e6,monthlyChargedOrReservedUsd:monthlyCharge(state.ledger,date)/1e6};
}

export class CloudQuestionGenerator {
  constructor({database,projectId,bundledPool,sources=[],apiKey,model='gpt-6-luna',now=Date.now,
    generate=generateQuestion,fetchImpl=fetch,limits=GENERATION_LIMITS}) {
    Object.assign(this,{database,projectId,bundledPool,sources,apiKey,model,now,generate,fetchImpl,limits});
    this.owner=randomUUID();this.startedAt=now();this.date=generationDay(this.startedAt);
  }
  async change(update,{acquire=false}={}) {
    let error;
    const result=await transaction(this.database.ref('questionGeneration'),raw=>{
      try {
        error=null;const state=normalize(raw);
        if(!acquire&&(state.lease?.owner!==this.owner||state.lease.expiresAtMs<=this.now()))throw new Error('Generation lease lost; no further API requests.');
        update(state);return state;
      }catch(e){error=e;return undefined;}
    });
    if(!result.committed)throw error??new Error('Cloud generation transaction aborted.');
    return normalize(result.snapshot.val());
  }
  async flushOutbox(state) {
    const entries=Object.entries(state.outbox).map(([id,raw])=>[id,decodeStoredQuestion(raw)]);
    if(!entries.length)return state;
    // Old individual outbox entries must never bypass the complete-set gate.
    if(entries.some(([,entry])=>!entry.manifest)) {
      state=await this.change(s=>{
        for(const [id,entry] of entries)if(!entry.manifest){s.backlog[id]=JSON.stringify({...entry,publication:'unpublished'});delete s.outbox[id];}
      });
      return this.flushOutbox(state);
    }
    // Approved records and removal of their outbox entries commit atomically.
    const current=await loadPublishedPool(this.database,this.bundledPool);
    const combined=new Map(current.map(q=>[q.id,q]));
    for(const [,entry] of entries)for(const q of entry.questions){if(!isPublished(q))throw new Error('Invalid publication outbox.');combined.set(q.id,q);}
    if(validatePool([...combined.values()]).length)throw new Error('Publication quality checks failed.');
    const updates={};
    for(const [id,entry] of entries){
      const manifest=createQuestionSet(id,entry.questions,entry.manifest.publishedAtMs);
      if(manifest.fingerprint!==entry.manifest.fingerprint)throw new Error('Invalid publication set.');
      for(const q of entry.questions)updates[`questionPool/published/${q.id}`]=JSON.stringify(compactQuestion(q));
      updates[`questionPool/sets/${id}`]=manifest;
      updates[`questionGeneration/ledger/days/${entry.date}/publishedSetIds/${id}`]=true;
      updates[`questionGeneration/outbox/${id}`]=null;
    }
    await this.database.ref().update(updates);
    return normalize((await this.database.ref('questionGeneration').get()).val());
  }
  async publishDraft(state) {
    const questions=Object.values(state.draft?.questions??{}).map(decodeStoredQuestion);
    if(questions.length!==14)return state;
    const published=questions.map(q=>({...q,publication:'published'}));
    const manifest=createQuestionSet(state.draft.id,published,this.now());
    state=await this.change(s=>{
      s.outbox[manifest.id]=JSON.stringify({date:this.date,manifest,questions:published});
      s.draft=null;
    });
    return this.flushOutbox(state);
  }
  async run({scheduleTime=new Date(this.now()).toISOString()}={}) {
    if(generationDay(Date.parse(scheduleTime))!==this.date)return {reason:'stale-schedule'};
    const configuration=(await this.database.ref('questionGeneration/control').get()).val();
    if(configuration?.enabled!==true||configuration.projectId!==this.projectId)return {reason:'disabled'};
    if(this.model!=='gpt-6-luna')throw new Error('Configured model has no budget pricing; no model switching.');
    let state,reason='unknown',acquired=false;
    try {
      state=await this.change(s=>{
        if(s.lease?.expiresAtMs>this.now())throw new Error('Generation already running.');
        s.lease={owner:this.owner,expiresAtMs:this.now()+leaseMs};
        // Retain charges for interrupted requests; never resend the same word.
        for(const day of Object.values(s.ledger.days)) {
          day.pending=null;
          for(const a of day.attempts)if(a.status==='started'){a.status='failed';day.consecutiveFailures++;}
        }
        const day=s.ledger.days[this.date]??=blankGenerationDay();
        if(!day.runId){day.runId=this.owner;day.runStartedAtMs=this.startedAt;}
      },{acquire:true});acquired=true;
      state=await this.flushOutbox(state);
      if(state.ledger.days[this.date].runId!==this.owner){reason='already-ran-today';return cloudGenerationReport(state,this.date,reason,this.limits);}
      let pool=await loadPublishedPool(this.database,this.bundledPool);
      const queued=Object.values((await this.database.ref('questionSources').get()).val()??{}).map(decodeStoredQuestion);
      const sources=[...new Map([...this.sources,...queued].map(s=>[s.answerId,s])).values()];
      while(true) {
        state=await this.publishDraft(state);
        reason=generationStopReason(state.ledger,this.date,{now:this.now(),startedAt:this.startedAt,limits:this.limits});if(reason)break;
        if(Object.keys(state.ledger.days[this.date].publishedSetIds??{}).length>=3){reason='daily-target-reached';break;}
        const draft=Object.values(state.draft?.questions??{}).map(decodeStoredQuestion);
        const backlog=Object.values(state.backlog).map(decodeStoredQuestion);
        const reusable=backlog.find(q=>fitsDraft(q,draft));
        if(reusable){
          state=await this.change(s=>{
            s.draft??={id:`daily_${randomUUID().replaceAll('-','')}`,questions:{},startedAtMs:this.now()};
            s.draft.questions[reusable.id]=JSON.stringify({...reusable,publication:'unpublished'});delete s.backlog[reusable.id];
          });
          continue;
        }
        const known=new Set([...pool.map(q=>q.answerId),...draft.map(q=>q.answerId),...backlog.map(q=>q.answerId),...Object.values(state.ledger.days).flatMap(d=>d.attempts.map(a=>a.answerId))]);
        const eligible=sources.filter(q=>!known.has(q.answerId)&&fitsDraft(q,draft));
        const target=Math.min(2000,Math.max(...LENGTHS.map(l=>pool.filter(q=>q.letterCount===l).length))+this.limits.approvedPerLength);
        const source=replenishmentPlan(eligible,pool,{targetPerLength:target,limit:1}).selected[0];
        if(!source){reason='source-stock-exhausted';break;}
        candidatePrompt(source); // Reject unclear sources before charging any tokens.
        const key=typeof this.apiKey==='function'?this.apiKey():this.apiKey;
        if(!key?.trim())throw new Error('Generation secret is unavailable.');
        state=await this.change(s=>{
          const reason=generationStopReason(s.ledger,this.date,{now:this.now(),startedAt:this.startedAt,limits:this.limits});
          if(reason)throw new Error(`Generation stopped: ${reason}.`);
          s.ledger.days[this.date].attempts.push({answerId:source.answerId,length:source.letterCount,status:'started',dailyCredit:true});
        });
        try {
          const knownQuestions=[...new Map([...pool,...draft,...backlog].map(q=>[q.id,q])).values()];
          const q=await this.generate(source,knownQuestions,{model:this.model,apiKey:key,aiReview:true,now:this.now(),maxOutputTokens:6000,
            fetchImpl:async(url,request)=>{
              state=await this.change(s=>{
                if(s.control?.enabled!==true||s.control.projectId!==this.projectId)throw new Error('Generation disabled.');
                reserveRequest(s.ledger,this.date,url,request,{now:this.now(),startedAt:this.startedAt,limits:this.limits});
              });
              return this.fetchImpl(url,request);
            },onResponse:async usage=>{
              let boundError;
              state=await this.change(s=>{boundError=settleUsage(s.ledger.days[this.date],usage);});
              if(boundError)throw new Error(boundError);
            }});
          if(JSON.stringify(q).includes(key)||/sk-(?:(?:proj|svcacct)-)?[A-Za-z0-9_-]{20,}/u.test(JSON.stringify(q)))throw new Error('Credential-like generation result refused.');
          if(validateQuestion(q).length||!['approved','rejected'].includes(q.review?.status))throw new Error('Invalid editorial result.');
          const storedQuestion=compactQuestion(q);
          state=await this.change(s=>{
            const day=s.ledger.days[this.date],attempt=day.attempts.at(-1);
            if(attempt.answerId!==q.answerId||attempt.status!=='started')throw new Error('Attempt identity changed.');
            attempt.status=q.review.status;attempt.questionId=q.id;day.pending=null;
            day.consecutiveFailures=q.review.status==='approved'?0:day.consecutiveFailures+1;
            if(q.review.status==='approved'){
              s.draft??={id:`daily_${randomUUID().replaceAll('-','')}`,questions:{},startedAtMs:this.now()};
              if(!fitsDraft(q,Object.values(s.draft.questions).map(decodeStoredQuestion)))throw new Error('Editorial result does not fit the pending set.');
              s.draft.questions[q.id]=JSON.stringify({...storedQuestion,publication:'unpublished'});
            }
            // Rejections retain the editorial audit, never enter the published pool.
            else s.rejections={...(s.rejections??{}),[q.id]:JSON.stringify(storedQuestion)};
          });
          state=await this.publishDraft(state);
          if(q.review.status==='approved')pool.push(q);
        }catch(error) {
          this.failure=error; // In-memory diagnostics only; never persisted or logged.
          state=await this.change(s=>{
            const day=s.ledger.days[this.date],attempt=day.attempts.at(-1);
            if(attempt.status==='started'){attempt.status='failed';day.consecutiveFailures++;}
            day.pending=null; // Keep the charge for unknown/timeout responses.
          });
          // Do not persist or log raw transport/provider errors or secret values.
          reason=['daily-budget','monthly-budget','api-call-limit','runtime-limit','day-changed'].find(code=>error.message?.includes(code))??'generation-error';break;
        }
      }
      return cloudGenerationReport(state,this.date,reason,this.limits);
    }catch(error) {
      if(!acquired&&error.message==='Generation already running.')return {reason:'already-running'};
      reason='job-error';throw new Error('Daily question job failed; inspect private counters and source inventory.');
    }finally {
      if(acquired)await this.change(s=>{s.lastRun=cloudGenerationReport(s,this.date,reason,this.limits);s.lease=null;});
    }
  }
}
