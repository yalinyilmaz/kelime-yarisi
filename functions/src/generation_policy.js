import {LENGTHS} from './content.js';

// GPT-6 Luna standard short-context prices, USD / million tokens, 2026-10-15.
export const GENERATION_LIMITS=Object.freeze({attempts:60,calls:120,consecutiveFailures:5,
  dailyMicros:500000,monthlyMicros:10000000,runtimeMs:1500000,approvedPerLength:6});
export const generationDay=now=>new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Istanbul',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(now));
export const blankGenerationDay=()=>({attempts:[],calls:0,chargedMicros:0,consecutiveFailures:0,pending:null});
const integer=n=>Number.isSafeInteger(n)&&n>=0;
export function validateGenerationLedger(state) {
  if(state?.version!==1||!state.days||typeof state.days!=='object'||Array.isArray(state.days))throw new Error('Invalid generation ledger; refusing to reset spending counters.');
  for(const [date,day] of Object.entries(state.days)) {
    if(!/^\d{4}-\d{2}-\d{2}$/u.test(date)||!Array.isArray(day.attempts)||
      !['calls','chargedMicros','consecutiveFailures'].every(k=>integer(day[k]))||
      day.attempts.some(a=>typeof a.answerId!=='string'||!LENGTHS.includes(a.length)||
        !['started','approved','rejected','in-review','failed'].includes(a.status)||typeof a.dailyCredit!=='boolean')||
      (day.pending!==null&&(!integer(day.pending?.reservedMicros)||!integer(day.pending?.inputBound)||!integer(day.pending?.outputLimit))))throw new Error('Invalid generation ledger; refusing to reset spending counters.');
  }
  return state;
}
export const approvedCounts=day=>Object.fromEntries(LENGTHS.map(l=>[l,day.attempts.filter(a=>a.length===l&&a.status==='approved'&&a.dailyCredit).length]));
export const monthlyCharge=(state,date)=>Object.entries(state.days).filter(([d])=>d.startsWith(date.slice(0,7))).reduce((sum,[,d])=>sum+d.chargedMicros,0);
export function generationStopReason(state,date,{now,startedAt,limits=GENERATION_LIMITS,duringAttempt=false}) {
  const day=state.days[date]??blankGenerationDay();
  if(generationDay(now)!==date)return 'day-changed';
  if(now-startedAt>=limits.runtimeMs)return 'runtime-limit';
  if(day.consecutiveFailures>=limits.consecutiveFailures)return 'consecutive-failures';
  if(!duringAttempt&&day.attempts.length>=limits.attempts)return 'attempt-limit';
  if(day.calls>=limits.calls)return 'api-call-limit';
  if(day.chargedMicros>=limits.dailyMicros)return 'daily-budget';
  if(monthlyCharge(state,date)>=limits.monthlyMicros)return 'monthly-budget';
  return null;
}
export function requestReservation(url,request) {
  const body=JSON.parse(request.body);
  if(url!=='https://api.openai.com/v1/responses'||body.model!=='gpt-6-luna'||body.service_tier!=='default'||body.tools?.length)throw new Error('Budget pricing is configured only for gpt-6-luna at the default service tier; model unchanged, no request sent.');
  const bytes=Buffer.byteLength(request.body,'utf8');
  if(bytes>96000||!integer(body.max_output_tokens)||body.max_output_tokens<512||body.max_output_tokens>12000)throw new Error('Request exceeds local size/token limits.');
  const inputBound=bytes+4096;
  return {inputBound,outputLimit:body.max_output_tokens,reservedMicros:Math.ceil(inputBound*0.10+body.max_output_tokens*0.50)};
}
export function reserveRequest(state,date,url,request,options) {
  const reason=generationStopReason(state,date,{...options,duringAttempt:true});
  if(reason)throw new Error(`Generation stopped: ${reason}.`);
  const day=state.days[date];
  if(!day?.attempts.some(a=>a.status==='started'))throw new Error('No active generation attempt.');
  if(day.pending)throw new Error('Previous API usage is unresolved; no retry allowed.');
  const reservation=requestReservation(url,request),limits=options.limits??GENERATION_LIMITS;
  if(day.chargedMicros+reservation.reservedMicros>limits.dailyMicros)throw new Error('Generation stopped: daily-budget reservation.');
  if(monthlyCharge(state,date)+reservation.reservedMicros>limits.monthlyMicros)throw new Error('Generation stopped: monthly-budget reservation.');
  day.calls++;day.chargedMicros+=reservation.reservedMicros;day.pending=reservation;
}
export function settleUsage(day,{inputTokens,outputTokens}) {
  const pending=day.pending;if(!pending)throw new Error('No API reservation for response.');
  if(!integer(inputTokens)||!integer(outputTokens)||inputTokens===0||outputTokens===0)return;
  day.chargedMicros+=Math.ceil(inputTokens*0.10+outputTokens*0.50)-pending.reservedMicros;day.pending=null;
  return inputTokens>pending.inputBound||outputTokens>pending.outputLimit?'Usage exceeded reserved bounds; generation stopped.':null;
}
