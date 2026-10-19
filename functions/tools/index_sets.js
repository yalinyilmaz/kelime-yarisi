import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {resolveQuestionSets} from '../src/question_sets.js';
import {decodeStoredQuestion,mergePublishedPool} from '../src/published_pool.js';

// One-time, additive dev index backfill. No question, manifest or history is changed.
const args=process.argv.slice(2);
if(!args.includes('--project=kelime-yarisi-yalin')||args.some(a=>!['--project=kelime-yarisi-yalin','--apply'].includes(a))) {
  throw new Error('Use --project=kelime-yarisi-yalin [--apply]. Production is not supported.');
}
async function main() {
  const config=JSON.parse(readFileSync(new URL('../../android/app/src/dev/google-services.json',import.meta.url)));
  if(config.project_info.project_id!=='kelime-yarisi-yalin')throw new Error('Unexpected dev project.');
  const token=execFileSync('gcloud',['auth','print-access-token'],{encoding:'utf8',stdio:['ignore','pipe','pipe']}).trim();
  const base=config.project_info.firebase_url.replace(/\/$/u,'');
  async function request(path,method='GET',value) {
    const response=await fetch(`${base}/${path}.json`,{method,
      headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},
      ...(value===undefined?{}:{body:JSON.stringify(value)}),signal:AbortSignal.timeout(30000)});
    if(!response.ok)throw new Error(`Dev index request HTTP ${response.status}`);
    return response.json();
  }
  const [pool,lease]=await Promise.all([request('questionPool'),request('questionGeneration/lease')]);
  if(lease?.expiresAtMs>Date.now())throw new Error('Generator active; retry after publication finishes.');
  const questions=mergePublishedPool([],Object.values(pool?.published??{}).map(decodeStoredQuestion));
  const sets=resolveQuestionSets(pool?.sets,questions);
  const updates=Object.fromEntries(sets.map(set=>[`questionPool/setIndex/${set.id}`,true]));
  console.log(JSON.stringify({project:'kelime-yarisi-yalin',dryRun:!args.includes('--apply'),
    verifiedSets:sets.length,verifiedQuestions:questions.length,indexBytes:Buffer.byteLength(JSON.stringify(Object.fromEntries(sets.map(s=>[s.id,true]))))}));
  if(!args.includes('--apply')||!sets.length)return;
  await request('','PATCH',updates);
  const index=await request('questionPool/setIndex');
  if(sets.some(set=>index?.[set.id]!==true))throw new Error('Index verification failed.');
  console.log(JSON.stringify({index:'verified',sets:sets.length}));
}
main().catch(()=>{console.error('Dev set index failed; credentials and question content are not logged.');process.exitCode=1;});
