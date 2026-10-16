import {readFileSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {candidatePrompt,validateQuestion} from '../src/content.js';
import {containsSecret} from './lib/local_config.js';

const args=process.argv.slice(2),root=resolve(import.meta.dirname,'../..');
const flag=name=>{const i=args.indexOf(`--${name}`);return i>=0?args[i+1]:undefined;};
try {
  if(!flag('sources')||!flag('out'))throw new Error('--sources PATH and a new --out PATH are required.');
  const records=JSON.parse(readFileSync(resolve(root,flag('sources')),'utf8'));
  if(!Array.isArray(records)||!records.length||records.length>1000)throw new Error('Queue batch must contain 1–1000 source records.');
  const queued={};
  for(const record of records) {
    const q={...record,clue:'',review:{status:'draft'},publication:'unpublished'};
    if(q.origin!=='production'||containsSecret(q))throw new Error('Invalid source origin or credential-like source content.');
    candidatePrompt(q);
    const errors=validateQuestion({...q,clue:'Kaynak denetimi için geçici açıklama.'})
      .filter(code=>!['answer-leak','root-leak'].includes(code)); // Placeholder text is not a candidate clue.
    if(errors.length)throw new Error('Source validation failed; no queue output written.');
    if(queued[q.answerId])throw new Error('Duplicate source answer.');
    queued[q.answerId]=JSON.stringify(q); // Preserve [] and the exact source metadata in RTDB.
  }
  writeFileSync(resolve(root,flag('out')),`${JSON.stringify(queued,null,2)}\n`,{flag:'wx',mode:0o600});
  console.log(JSON.stringify({draftSources:Object.keys(queued).length,publishedQuestions:0,networkCalls:0}));
}catch(error){console.error(error.message);process.exitCode=1;}
