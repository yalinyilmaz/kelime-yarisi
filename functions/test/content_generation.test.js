import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import {answerId, approveQuestion, REVIEW_CHECKS, validateQuestion} from '../src/content.js';
import {callStructured, generateQuestion, replenishmentPlan, handoffDigest} from '../src/content_generation.js';
import {requestReservation} from '../src/generation_policy.js';
const fixture=JSON.parse(readFileSync(new URL('../content/examples.json',import.meta.url)))[0];
const source={...fixture,origin:'production',publication:'unpublished',review:{status:'draft'}};
const checks=Object.fromEntries([...REVIEW_CHECKS,'hintConsistency','hintNoLeak'].map(k=>[k,true]));
const clues=['Duvar açıklığını örten, giriş çıkış için hareket ettirilen yapı.', 'Bir oda girişini kapatan menteşeli bölüm.', 'Geçişi açmak için kanadı hareket ettirilen bina bölümü.'];
const output=value=>({ok:true,json:async()=>({id:'response-id',model:'explicit-test-model',status:'completed',usage:{input_tokens:50,output_tokens:25},output:[{type:'message',content:[{type:'output_text',text:JSON.stringify(value)}]}]})});
const options=responses=>{const requests=[];return {model:'explicit-test-model',apiKey:'test-only-key',aiReview:true,
  requests,fetchImpl:async(url,request)=>{requests.push({url,body:JSON.parse(request.body)});return responses.shift();}};};
const pass={decision:'approve',selectedIndex:1,checks,rationale:'Girişin açılıp kapanması ayırt edicidir.',sourceSupport:'Hareketli giriş örtüsü anlamı kaynakta bulunur.',alternativesRejected:[{answer:'PANO',reason:'Giriş çıkışı kapatan hareketli bölüm değildir.'}]};
test('explicit model/key required; no network call without credentials',async()=>{
 let called=false;await assert.rejects(callStructured({model:'m',fetchImpl:async()=>{called=true;}}),/OPENAI_API_KEY/);assert.equal(called,false);
});
test('separate generation/editor requests preserve model, remain unpublished and bind approval to content',async()=>{
 const opts=options([output({meaning:'Giriş açıklığını kapatan hareketli yapı.',candidates:clues.map(clue=>({clue,hints:['Genellikle menteşelerle tutturulur.','Evde odalar arasında geçişi sağlayan bir kanadı vardır.'],hintEvidence:'Test kaynağında hareketli kanadın bağlantısı desteklenir.'}))}),output(pass)]);
 const q=await generateQuestion(source,[],opts);
 assert.equal(opts.requests.length,2);assert(opts.requests.every(r=>r.body.model==='explicit-test-model'&&r.body.store===false&&r.body.service_tier==='default'));
 assert.equal(q.clue,clues[1]);assert.deepEqual(q.hints,['Genellikle menteşelerle tutturulur.','Evde odalar arasında geçişi sağlayan bir kanadı vardır.']);assert.equal(q.generation.handoffDigest,handoffDigest);assert.equal(q.review.kind,'ai-self-review');assert.equal(q.publication,'unpublished');assert.deepEqual(validateQuestion(q),[]);
 assert.deepEqual(q.generation.tokenUsage,{inputTokens:50,outputTokens:25});assert.deepEqual(q.review.tokenUsage,{inputTokens:50,outputTokens:25});
 assert(validateQuestion({...q,clue:'Değiştirilen soru.'}).includes('invalid-editor-approval'));
 assert(validateQuestion({...q,review:{...q.review,alternativesRejected:undefined}}).includes('missing-ai-editor-audit'));
});
test('public-source requests exclude the entire existing corpus and local source audit data',async()=>{
 const selected={...source,source:{...source.source,privateNotes:'PRIVATE-SOURCE-NOTE',encyclopedia:{reference:'https://en.wikipedia.org/w/index.php?oldid=1',extract:'A public description of a movable entrance barrier.',termsReference:'https://en.wikipedia.org/wiki/Wikipedia:Copyrights'}}};
 const existing={...source,id:'old-record',answer:'SAAT',answerId:answerId('SAAT'),clue:'PRIVATE-OLD-CLUE'};
 const opts=options([output({meaning:'Giriş açıklığını kapatan hareketli yapı.',candidates:clues.map(clue=>({clue,hints:['Genellikle menteşelerle tutturulur.','Evde odalar arasında geçişi sağlayan bir kanadı vardır.'],hintEvidence:'Test kaynağında hareketli kanadın bağlantısı desteklenir.'}))}),output(pass)]);
 await generateQuestion(selected,[existing],opts);
 const bodies=JSON.stringify(opts.requests);
 assert(!bodies.includes('PRIVATE-OLD-CLUE'));assert(!bodies.includes('PRIVATE-SOURCE-NOTE'));assert(!bodies.includes('existingClues'));
 assert(bodies.includes('A public description of a movable entrance barrier.'));
});
test('ambiguity, absent rationale or failed semantic checks never gain approval',async()=>{
 for(const review of [{...pass,decision:'reject'},{...pass,rationale:''},{...pass,checks:{...checks,uniqueAnswer:false}}]){
  const q=await generateQuestion(source,[],options([output({meaning:'Giriş açıklığını kapatan hareketli yapı.',candidates:clues.map(clue=>({clue,hints:['Genellikle menteşelerle tutturulur.','Evde odalar arasında geçişi sağlayan bir kanadı vardır.'],hintEvidence:'Test kaynağında hareketli kanadın bağlantısı desteklenir.'}))}),output(review)]));
  assert.equal(q.review.status,'rejected');assert.equal(q.publication,'unpublished');
  assert.deepEqual(q.review.tokenUsage,{inputTokens:50,outputTokens:25});assert(q.review.sourceSupport);assert(q.review.checks);
 }
});

test('daily writer and editor allow postpositions, conjunctions, infinitives and two-word phrases',async()=>{
 for(const [answer,type,meaning] of [
  ['İÇİN','postposition','Amaç veya neden ilişkisi kuran edat.'],
  ['FAKAT','conjunction','İki yargı arasında karşıtlık kuran bağlaç.'],
  ['OKUMAK','infinitive','Harflerle oluşturulmuş metni anlamlandırmak.'],
  ['EL KİTABI','noun','Bir konu için pratik başvuru kaynağı.'],
  ['DEV GİBİ','postposition_phrase','Çok büyük olmayı benzetmeyle anlatan öbek.'],
  ['NEFES ALMAK','verb_phrase','Ciğerlere hava çekme eylemi.'],
 ]) {
  const wordLengths=answer.split(' ').map(w=>w.length);
  const draft={...source,id:'mixed-test',answer,answerId:answerId(answer),letterCount:wordLengths.reduce((a,b)=>a+b,0),
   meaning,rootText:answer,rootId:answerId(answer),wordLengths,grammaticalType:type,
   answerType:wordLengths.length===2?'phrase':type==='conjunction'?'conjunction':'word'};
  const review={...pass,acceptedAnswers:answer==='NEFES ALMAK'?['SOLUK ALMAK']:[],alternativesRejected:[]};
  const opts=options([output({meaning,candidates:clues.map(clue=>({clue,hints:['Genellikle menteşelerle tutturulur.','Evde odalar arasında geçişi sağlayan bir kanadı vardır.'],hintEvidence:'Test kaynağında hareketli kanadın bağlantısı desteklenir.'}))}),output(review)]);
  const q=await generateQuestion(draft,[],opts);
  assert.equal(q.review.status,'approved',answer);assert.deepEqual(validateQuestion(q),[]);
  assert.deepEqual(q.wordLengths,wordLengths);assert.equal(q.answer,answer);
  assert(opts.requests[0].body.instructions.includes('edat'));
  assert(opts.requests[1].body.instructions.includes('Eş anlamlı'));
  assert(opts.requests[1].body.text.format.schema.required.includes('acceptedAnswers'));
 }
});
test('malformed source layout incurs no API call; invalid synonyms never gain approval',async()=>{
 const invalid=options([]);
 await assert.rejects(generateQuestion({...source,answer:'BİR İKİ ÜÇ'},[],invalid),/Invalid source format/);
 assert.equal(invalid.requests.length,0);
 const bad=options([output({meaning:source.meaning,candidates:clues.map(clue=>({clue,hints:['Genellikle menteşelerle tutturulur.','Evde odalar arasında geçişi sağlayan bir kanadı vardır.'],hintEvidence:'Test kaynağında hareketli kanadın bağlantısı desteklenir.'}))}),output({...pass,acceptedAnswers:['UZUN SÖZ']})]);
 assert.equal((await generateQuestion(source,[],bad)).review.status,'rejected');
});
test('generation alone creates in-review content, no silent AI approval',async()=>{
 const opts=options([output({meaning:'Giriş açıklığını kapatan hareketli yapı.',candidates:clues.map(clue=>({clue,hints:['Genellikle menteşelerle tutturulur.','Evde odalar arasında geçişi sağlayan bir kanadı vardır.'],hintEvidence:'Test kaynağında hareketli kanadın bağlantısı desteklenir.'}))})]);opts.aiReview=false;
 assert.equal((await generateQuestion(source,[],opts)).review.status,'in-review');assert.equal(opts.requests.length,1);
});
test('the API schema always requires two hints, and invalid hint counts stop before the editor call',async()=>{
 const good={clue:clues[0],hints:['Menteşelerle tutturulabilir.','Ahşaptan veya metalden yapılabilir.'],hintEvidence:'İki bilgi de test kaynağında desteklenir.'};
 const opts=options([output({meaning:source.meaning,candidates:clues.map(clue=>({...good,clue}))}),output(pass)]);
 await generateQuestion(source,[],opts);
 const candidate=opts.requests[0].body.text.format.schema.properties.candidates.items;
 assert(candidate.required.includes('hints'));
 assert.deepEqual(candidate.properties.hints,{type:'array',minItems:2,maxItems:2,items:{type:'string'}});
 const editor=JSON.parse(opts.requests[1].body.input);
 assert(editor.candidates.every(c=>c.hints.length===2));
 for(const hints of [[good.hints[0]],[...good.hints,'Üçüncü ipucu.'],['Aynı metin.','Aynı metin.'],['','Boş olmayan metin.']]){
  const bad=options([output({meaning:source.meaning,candidates:clues.map(clue=>({...good,clue,hints}))})]);
  await assert.rejects(generateQuestion(source,[],bad));assert.equal(bad.requests.length,1);
 }
});
test('writer and editor receive the same deployed handoff, including hints, figurative meanings and slang',async()=>{
 const handoff=readFileSync(new URL('../content/question_set_final_handoff.md',import.meta.url),'utf8');
 const opts=options([output({meaning:source.meaning,candidates:clues.map(clue=>({clue,hints:['Menteşelerle tutturulabilir.','Evde odalar arasında geçişi sağlayan bir kanadı vardır.'],hintEvidence:'Test kaynağında bağlantı desteklenir.'}))}),output(pass)]);
 const q=await generateQuestion(source,[],opts);
 for(const {body} of opts.requests){
  assert(body.instructions.includes(handoff));
  assert(body.instructions.includes('Mecazi olarak')&&body.instructions.includes('Argoda'));
  assert.doesNotThrow(()=>requestReservation('https://api.openai.com/v1/responses',
   {body:JSON.stringify({...body,model:'gpt-6-luna'})}));
 }
 assert.equal(q.review.handoffDigest,handoffDigest);
 assert.equal(q.source.hintReference??q.source.reference,source.source.reference);
 assert(validateQuestion({...q,hint:'İncelemeden sonra değiştirilmiş bir ipucu.'}).includes('invalid-editor-approval'));
});
test('missing hints, leaking hints and a failed hint review cannot receive approval',async()=>{
 for(const candidates of [clues.map(clue=>({clue})),clues.map(clue=>({clue,hints:['Kapıyı kullanırsın.','Evde odalar arasında geçişi sağlayan bir kanadı vardır.'],hintEvidence:'Test.'}))]){
  const opts=options([output({meaning:source.meaning,candidates})]);
  await assert.rejects(generateQuestion(source,[],opts));assert.equal(opts.requests.length,1);
 }
 const opts=options([output({meaning:source.meaning,candidates:clues.map(clue=>({clue,hints:['Menteşelerle tutturulabilir.','Evde odalar arasında geçişi sağlayan bir kanadı vardır.'],hintEvidence:'Test kaynağı.'}))}),
  output({...pass,checks:{...checks,hintConsistency:false}})]);
 assert.equal((await generateQuestion(source,[],opts)).review.status,'rejected');
});
test('an alternative revealed by the chosen clue or hint cannot receive approval',async()=>{
 for(const [answer,hint] of [['YAPI','Menteşelerle tutturulabilir.'],['AĞAÇ','Ağaç işlenerek üretilebilir.']]){
  const opts=options([output({meaning:source.meaning,candidates:clues.map(clue=>({clue,hints:[hint,'Evde odalar arasında geçişi sağlayan bir kanadı vardır.'],hintEvidence:'Test kaynağı.'}))}),
   output({...pass,selectedIndex:0,acceptedAnswers:[answer]})]);
  const q=await generateQuestion(source,[],opts);
  assert.equal(q.review.status,'rejected');assert.match(q.review.rationale,/answer-leak/);
 }
});
test('answer leaks, duplicate clues, unclear rights and invalid responses stop before review',async()=>{
 const opts=options([output({meaning:'Giriş açıklığını kapatan hareketli yapı.',candidates:Array(3).fill({clue:'Kapıyı açarak girilir.',hints:['Menteşelerle hareket edebilir.','Evde odalar arasında geçişi sağlayan bir kanadı vardır.'],hintEvidence:'Test kanıtı.'})})]);
 await assert.rejects(generateQuestion(source,[],opts),/failed automated/);assert.equal(opts.requests.length,1);
 await assert.rejects(generateQuestion({...source,source:{...source.source,rights:'unknown'}},[],options([])),/cleared rights/);
 await assert.rejects(callStructured({...options([{ok:true,json:async()=>({status:'incomplete',output:[]})}]),schema:{},name:'x'}),/incomplete/);
 await assert.rejects(callStructured({...options([{ok:false,status:429}]),schema:{},name:'x'}),/HTTP 429/);
});
test('replenishment prioritizes weak lengths and never treats clue variants as new words',()=>{
 const sources=JSON.parse(readFileSync(new URL('../content/examples.json',import.meta.url))).map(q=>({...q,origin:'production'}));
 const already=sources.filter(q=>q.letterCount!==10).map(q=>approveQuestion(q,'test',checks));
 const plan=replenishmentPlan(sources,already,{targetPerLength:8,limit:3});
 assert.equal(plan.selected.length,3);assert(plan.selected.every(q=>q.letterCount===10));
 const same={...sources[0],id:'new-clue-same-answer'};
 assert(!replenishmentPlan([same],already,{targetPerLength:8}).selected.length);
 assert.equal(answerId('kapı'),fixture.answerId);
});
test('CLI paths resolve from repository root even when npm --prefix changes cwd; dry run needs no key',()=>{
 const run=spawnSync(process.execPath,[new URL('../tools/replenish.js',import.meta.url).pathname,'--sources','content/questions.json','--dry-run'],
  {cwd:new URL('..',import.meta.url),encoding:'utf8',env:{...process.env,OPENAI_API_KEY:''}});
 assert.equal(run.status,0,run.stderr);
 const report=JSON.parse(run.stdout);assert.equal(report.groups.length,7);assert.deepEqual(report.selectedAnswers,[]);
});
