import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,rmSync,chmodSync,symlinkSync} from 'node:fs';
import {resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {execFileSync} from 'node:child_process';
import {loadLocalConfig,containsSecret,safeError} from '../tools/lib/local_config.js';
import {checkDeployment} from '../tools/lib/deploy_guard.js';
import {callStructured} from '../src/content_generation.js';

const fakeKey=`sk-proj-${'x'.repeat(32)}`; // Deliberately synthetic, never usable.
const root=resolve(import.meta.dirname,'../..');
function sandbox(run) {
 const dir=mkdtempSync(resolve(tmpdir(),'kelime-generator-security-'));
 try {
  execFileSync('git',['init','--quiet',dir]);
  mkdirSync(resolve(dir,'.local'),{mode:0o700});mkdirSync(resolve(dir,'functions/src'),{recursive:true});
  writeFileSync(resolve(dir,'.gitignore'),readFileSync(resolve(root,'.gitignore')));
  writeFileSync(resolve(dir,'firebase.json'),readFileSync(resolve(root,'firebase.json')));
  writeFileSync(resolve(dir,'functions/.env.local'),'QUESTION_POOL_EXAMPLES=false\n');
  writeFileSync(resolve(dir,'functions/src/index.js'),'export const safe=true;\n');
  writeFileSync(resolve(dir,'.local/question-generation.env'),`OPENAI_API_KEY=${fakeKey}\nOPENAI_MODEL=explicit-test-model\n`,{mode:0o600});
  run(dir);
 }finally {rmSync(dir,{recursive:true,force:true});}
}
test('private local config loads without shell evaluation; process env overrides it',()=>sandbox(dir=>{
 const config=loadLocalConfig(dir,{env:{}});assert.equal(config.apiKey,fakeKey);assert.equal(config.model,'explicit-test-model');
 assert.equal(loadLocalConfig(dir,{env:{OPENAI_MODEL:'chosen-model'}}).model,'chosen-model');
 writeFileSync(resolve(dir,'.local/question-generation.env'),'OPENAI_API_KEY=$(this-is-not-executed)\nOPENAI_MODEL=m\n',{mode:0o600});
 assert.equal(loadLocalConfig(dir,{env:{}}).apiKey,'$(this-is-not-executed)');
}));
test('loose file permissions, duplicate fields and symlinks are rejected',()=>sandbox(dir=>{
 const file=resolve(dir,'.local/question-generation.env');
 chmodSync(file,0o644);assert.throws(()=>loadLocalConfig(dir),/mode 600/);chmodSync(file,0o600);
 writeFileSync(file,'OPENAI_MODEL=m\nOPENAI_MODEL=n\n');assert.throws(()=>loadLocalConfig(dir),/duplicate/);
 rmSync(file);writeFileSync(resolve(dir,'other.env'),'OPENAI_MODEL=m');symlinkSync(resolve(dir,'other.env'),file);assert.throws(()=>loadLocalConfig(dir),/regular file/);
}));
test('private root config is safe for deploy, but function env credentials stop deployment',()=>sandbox(dir=>{
 assert.equal(checkDeployment(dir).localConfigExcluded,true);
 writeFileSync(resolve(dir,'functions/.env.prod'),`OPENAI_API_KEY=${fakeKey}\n`);
 assert.throws(()=>checkDeployment(dir),/Only QUESTION_POOL_EXAMPLES/);
}));
test('runtime credential contamination, unsafe assets and broken ignore rules stop deployment',()=>sandbox(dir=>{
 const runtime=resolve(dir,'functions/src/leak.js');writeFileSync(runtime,`export const token='${fakeKey}';`);
 assert.throws(()=>checkDeployment(dir),/credential/);rmSync(runtime);
 writeFileSync(resolve(dir,'pubspec.yaml'),'flutter:\n  assets:\n    - .local/\n');assert.throws(()=>checkDeployment(dir),/Flutter/);rmSync(resolve(dir,'pubspec.yaml'));
 const firebase=JSON.parse(readFileSync(resolve(dir,'firebase.json')));firebase.functions[0].ignore=firebase.functions[0].ignore.filter(p=>p!=='.env.*');
 writeFileSync(resolve(dir,'firebase.json'),JSON.stringify(firebase));assert.throws(()=>checkDeployment(dir),/protection missing/);
}));
test('Git force-adding a credential file defeats ignore but deploy guard still rejects it',()=>sandbox(dir=>{
 execFileSync('git',['add','--force','.local/question-generation.env'],{cwd:dir});
 assert.throws(()=>checkDeployment(dir),/already tracked/);
}));
test('transport failures and malformed/credential-echoing API responses do not expose secrets',async()=>{
 const settings={model:'m',apiKey:fakeKey,schema:{},name:'test',instructions:'test',input:'test'};
 for(const fetchImpl of [async()=>{throw new Error(`Bearer ${fakeKey}`);},async()=>({ok:true,json:async()=>{throw new Error(fakeKey);}}),async()=>({ok:true,json:async()=>({status:'completed',output:[{type:'message',content:[{type:'output_text',text:fakeKey}]}]})})]) {
  await assert.rejects(callStructured({...settings,fetchImpl}),error=>!error.message.includes(fakeKey));
 }
 assert(containsSecret({clue:fakeKey}));assert(!safeError(new Error(`secret ${fakeKey}`),fakeKey).includes(fakeKey));
});
test('request ceiling is explicit, redirects are refused and per-call token limit is enforced',async()=>{
 let request;
 const result=await callStructured({model:'chosen-model',apiKey:fakeKey,schema:{},name:'x',input:'x',instructions:'x',maxOutputTokens:1200,
  fetchImpl:async(url,args)=>{request=args;return {ok:true,json:async()=>({status:'completed',output:[{type:'message',content:[{type:'output_text',text:'{}'}]}]})};}});
 assert.deepEqual(result.value,{});assert.equal(request.redirect,'error');assert.equal(JSON.parse(request.body).max_output_tokens,1200);
 await assert.rejects(callStructured({model:'m',apiKey:fakeKey,maxOutputTokens:0}),/512/);
});
