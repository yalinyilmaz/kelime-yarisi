import {readFileSync, writeFileSync, renameSync, unlinkSync,existsSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {generateQuestion, replenishmentPlan} from '../src/content_generation.js';
import {loadLocalConfig,containsSecret,safeError} from './lib/local_config.js';
import {GenerationBudget,runBoundedBatch} from './lib/generation_budget.js';

const args = process.argv.slice(2);
const flag = name => {
  const index=args.indexOf(`--${name}`);
  return index>=0 && args[index+1] && !args[index+1].startsWith('--') ? args[index+1] : undefined;
};
const root = resolve(import.meta.dirname,'../..');
let lock;
let apiKey='';
let budget;
try {
  const trial=args.includes('--trial');
  const daily=args.includes('--daily');
  if (!flag('sources')) throw new Error('--sources PATH is required (source-backed records with reviewed target meanings).');
  if(daily&&(trial||flag('file')||flag('limit')||flag('target-per-length')||!args.includes('--ai-review')))throw new Error('Daily production requires --ai-review and the default authoring pool; trial, output and quota overrides are disabled.');
  if(trial&&(flag('file')||flag('limit')!=='1'||!args.includes('--ai-review')))throw new Error('Trial requires --limit 1 --ai-review and writes only .local/question-trial.json.');
  const file = resolve(root,trial?'.local/question-trial.json':flag('file') ?? 'content/questions.json');
  const initial=JSON.parse(readFileSync(resolve(root,'content/questions.json'),'utf8'));
  const pool = trial&&!existsSync(file)?initial:JSON.parse(readFileSync(file,'utf8'));
  budget=new GenerationBudget(root);
  if(!args.includes('--dry-run'))budget.acquire();
  // Preserve the quarantine from the original, pre-ledger API trial as well.
  const previousTrial=resolve(root,'.local/question-trial.json');
  const priorRejected=new Set(existsSync(previousTrial)?JSON.parse(readFileSync(previousTrial,'utf8')).filter(q=>q.review?.status==='rejected').map(q=>q.answerId):[]);
  const sources = JSON.parse(readFileSync(resolve(root,flag('sources')),'utf8')).filter(q=>!priorRejected.has(q.answerId)&&!budget.attemptedIds().has(q.answerId));
  const targetPerLength=daily?Math.min(2000,Math.max(...[4,5,6,7,8,9,10].map(l=>pool.filter(q=>q.letterCount===l).length))+budget.limits.approvedPerLength):Number(flag('target-per-length') ?? 40);
  const limit=daily?budget.limits.attempts:Number(flag('limit') ?? 20);
  const counts=budget.approvedCounts();
  const plan = replenishmentPlan(sources.filter(s=>!daily||counts[s.letterCount]<budget.limits.approvedPerLength), pool, {targetPerLength,limit});
  console.log(JSON.stringify({...(daily?{dailyTarget:42}:{targetPerLength:plan.targetPerLength}),
    groups:daily?plan.groups.map(g=>({length:g.length,approvedToday:counts[g.length],missingToday:Math.max(0,6-counts[g.length]),availableSources:g.availableSources})):plan.groups,
    selectedAnswers:plan.selected.map(q=>q.answer),daily,budget:budget.report()},null,2));
  if (args.includes('--dry-run')) process.exit(0);
  if (!plan.selected.length) {console.log('No new eligible sources. Daily target remains unmet; add source-backed words in the missing length groups.');}
  else {
  const config=loadLocalConfig(root);
  apiKey=config.apiKey;
  const model=flag('model') ?? config.model;
  if (!model || !apiKey) throw new Error('Fill OPENAI_API_KEY and OPENAI_MODEL in .local/question-generation.env (mode 600), or set local environment variables. No API calls made.');
  const maxOutputTokens=Number(flag('max-output-tokens')??6000);
  if(!Number.isInteger(maxOutputTokens)||maxOutputTokens<512||maxOutputTokens>12000)throw new Error('Max output tokens must be 512–12000.');
  let calls=0;
  const maximumCalls=limit*(args.includes('--ai-review')?2:1);
  const guardedFetch=async(...params)=>{
    if(calls>=maximumCalls)throw new Error('API call limit reached.');
    calls++;return budget.fetch(...params);
  };
  if(trial&&!existsSync(file)) {
    mkdirSync(resolve(root,'.local'),{recursive:true,mode:0o700});
    writeFileSync(file,`${JSON.stringify(initial,null,2)}\n`,{flag:'wx',mode:0o600});
  }
  const candidateLock=`${file}.lock`;
  writeFileSync(candidateLock,`${process.pid}\n`,{flag:'wx'});
  lock=candidateLock;
  if(JSON.stringify(JSON.parse(readFileSync(file,'utf8'))) !== JSON.stringify(pool)) throw new Error('Content changed during planning. Rerun to preserve those edits.');
  const report=await runBoundedBatch({budget,sources,pool,limit,daily,
    dailyCredit:file===resolve(root,'content/questions.json')&&args.includes('--ai-review'),
    select:(available,current)=>replenishmentPlan(available,current,{targetPerLength,limit:1}).selected[0],
    generate:(source,current)=>generateQuestion(source,current,{model,apiKey,aiReview:args.includes('--ai-review'),maxOutputTokens,fetchImpl:guardedFetch,
      onResponse:usage=>budget.recordUsage(usage)}),
    persist:question=>{
    if(containsSecret(question,apiKey))throw new Error('Credential-like content in generated record; nothing saved.');
    if(JSON.stringify(JSON.parse(readFileSync(file,'utf8'))) !== JSON.stringify(pool)) throw new Error('Content edited during API request. No edits overwritten.');
    const temporary=`${file}.${process.pid}.tmp`;
    writeFileSync(temporary,`${JSON.stringify([...pool,question],null,2)}\n`,{mode:0o600});
    renameSync(temporary,file); // Checkpoint each completed word. Reruns skip it.
    console.log(`${question.answer}: ${question.review.status}. Local only; publish is a separate command.`);
  }});
  console.log(JSON.stringify({...report,trialOnly:trial},null,2));
  }
} catch (error) {console.error(safeError(error,apiKey));if(budget)console.error(JSON.stringify(budget.report()));process.exitCode=1;}
finally {if(lock)unlinkSync(lock);budget?.close();}
