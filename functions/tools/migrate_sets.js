import {readFileSync} from 'node:fs';
import {ResponseIndex,RESPONSE_INDEX_PATH,responseIndexUpdates} from '../src/response_index.js';
import {execFileSync} from 'node:child_process';
import {partitionExistingQuestions,resolveQuestionSets} from '../src/question_sets.js';
import {mergePublishedPool,decodeStoredQuestion} from '../src/published_pool.js';

// Explicit dev-only, repeatable migration. Never prints credentials or question text.
const args=process.argv.slice(2);
if(!args.includes('--project=kelime-yarisi-yalin')||args.some(a=>!['--project=kelime-yarisi-yalin','--apply'].includes(a))) {
  throw new Error('Use --project=kelime-yarisi-yalin [--apply]. Production is not supported by this migration.');
}
const config=JSON.parse(readFileSync(new URL('../../android/app/src/dev/google-services.json',import.meta.url)));
if(config.project_info.project_id!=='kelime-yarisi-yalin')throw new Error('Unexpected native dev config.');
const base=config.project_info.firebase_url.replace(/\/$/u,'');
const token=execFileSync('gcloud',['auth','print-access-token'],{encoding:'utf8',stdio:['ignore','pipe','pipe']}).trim();
const headers={Authorization:`Bearer ${token}`,'Content-Type':'application/json'};
async function request(path,method='GET',body,extra={}) {
 const response=await fetch(`${base}/${path}.json`,{method,headers:{...headers,...extra},...(body===undefined?{}:{body:JSON.stringify(body)})});
 if(!response.ok)throw new Error(`Dev migration request failed (${response.status}).`);
 return {value:await response.json(),etag:response.headers.get('etag')};
}
async function main() {
 const [{value:pool},{value:generation}]=await Promise.all([request('questionPool'),request('questionGeneration')]);
 if(generation?.setMigrationVersion===1) {
  const bundled=JSON.parse(readFileSync(new URL('../content/published.json',import.meta.url)));
  const sets=resolveQuestionSets(pool?.sets,mergePublishedPool(bundled,Object.values(pool?.published??{}).map(decodeStoredQuestion)));
  console.log(JSON.stringify({alreadyMigrated:true,sets:sets.length,playableQuestions:sets.length*14,backlogQuestions:Object.keys(generation.backlog??{}).length}));return;
 }
 if(generation?.lease?.expiresAtMs>Date.now())throw new Error('Generator is running; migrate after it finishes.');
 const bundled=JSON.parse(readFileSync(new URL('../content/published.json',import.meta.url)));
 const questions=mergePublishedPool(bundled,Object.values(pool?.published??{}).map(decodeStoredQuestion));
 const plan=partitionExistingQuestions(questions);
 const ids=new Set(Object.values(plan.sets).flatMap(s=>s.questionIds));
 console.log(JSON.stringify({dryRun:!args.includes('--apply'),approvedQuestions:questions.length,sets:Object.keys(plan.sets).length,playableQuestions:ids.size,privateBacklogQuestions:Object.keys(plan.backlog).length}));
 if(!args.includes('--apply'))return;
 const control=await request('questionGeneration/control','GET',undefined,{'X-Firebase-ETag':'true'});
 if(control.value?.projectId!=='kelime-yarisi-yalin')throw new Error('Dev generation control mismatch.');
 await request('questionGeneration/control','PUT',{...control.value,enabled:false},{'if-match':control.etag});
 try {
  const updates={'questionPool/sets':plan.sets,'questionGeneration/setMigrationVersion':1,
   ...(pool?.generationIndex?.version===1?responseIndexUpdates(questions):{[RESPONSE_INDEX_PATH]:ResponseIndex.fromQuestions(questions).data})};
  for(const q of questions) {
   if(ids.has(q.id))updates[`questionPool/published/${q.id}`]=JSON.stringify(q);
   else {updates[`questionPool/published/${q.id}`]=null;updates[`questionGeneration/backlog/${q.id}`]=plan.backlog[q.id];}
  }
  await request('','PATCH',updates);
  const after=await request('questionPool');
  const resolved=resolveQuestionSets(after.value.sets,Object.values(after.value.published).map(decodeStoredQuestion));
  if(resolved.length!==Object.keys(plan.sets).length)throw new Error('Post-migration verification failed.');
  console.log(JSON.stringify({migration:'verified',sets:resolved.length,playableQuestions:resolved.length*14}));
 } finally {
  const paused=await request('questionGeneration/control','GET',undefined,{'X-Firebase-ETag':'true'});
  if(paused.value?.projectId==='kelime-yarisi-yalin'&&paused.value.enabled===false)
   await request('questionGeneration/control','PUT',control.value,{'if-match':paused.etag});
 }
}
main().catch(()=>{console.error('Dev set migration failed. No credentials or question content were logged.');process.exitCode=1;});
