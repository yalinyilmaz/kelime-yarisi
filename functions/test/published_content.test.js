import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {LENGTHS,validatePool,isPublished} from '../src/content.js';
import {qualityReport} from '../src/content_quality.js';
import {selectSet} from '../src/set_selector.js';
const pool=JSON.parse(readFileSync(new URL('../content/published.json',import.meta.url)));
test('real corpus has at least 20 source-backed AI-reviewed distinct answers per length, with no fixture promotion',()=>{
 assert.deepEqual(validatePool(pool),[]);
 assert(pool.length>=140);assert(pool.every(q=>q.origin==='production'&&isPublished(q)));
 for(const length of LENGTHS)assert(new Set(pool.filter(q=>q.letterCount===length).map(q=>q.answerId)).size>=20);
 for(const q of pool){assert.equal(q.review.kind,'ai-self-review');assert(q.review.sourceSupport||q.source.meaningEvidence);assert(Array.isArray(q.review.alternativesRejected));
  assert(q.review.alternativesRejected.length||q.review.alternativePolicy==='allow-synonyms');
  let evidence;try{evidence=JSON.parse(q.source.meaningEvidence);}catch{}
  const encyclopedia=q.source.encyclopedia??evidence?.encyclopedia;
  if(encyclopedia) {
   assert((q.source.evidence??evidence.wikidata).revision);assert.match(q.source.reference,/^https:\/\/www.wikidata.org\/wiki\/Q\d+$/);
   assert(encyclopedia.attribution);assert.equal(encyclopedia.license,'CC-BY-SA-4.0');assert.match(encyclopedia.reference,/oldid=\d+$/);
  } else {
   assert.equal(q.source.rights,'original');assert(q.source.termsReference);assert(q.source.meaningEvidence);
   assert.match(q.source.reference,/^https:\/\//);
   assert(q.source.verificationStatus==='verified'||
    q.source.evidence?.provider==='TDK Güncel Türkçe Sözlük'&&q.source.evidence.entryIds?.length);
  }
 }
 assert(pool.some(q=>q.answer==='OBUA'));assert(pool.some(q=>q.answer==='TRANSİSTÖR'));assert(!pool.some(q=>q.answer==='TRANZİSTÖR'));
});
test('published corpus provides new common sets after shown answers and respects each root family',()=>{
 const seenAnswerIds=[],seenQuestionIds=[];
 for(let game=0;game<5;game++){
  const {questions}=selectSet(pool,[{seenAnswerIds,seenQuestionIds}],{random:()=>0.5});
  assert.equal(questions.length,14);assert.equal(new Set(questions.map(q=>q.rootId)).size,14);
  for(const q of questions){assert(!seenAnswerIds.includes(q.answerId));seenAnswerIds.push(q.answerId);seenQuestionIds.push(q.id);}
 }
 assert.equal(new Set(seenAnswerIds).size,70);
});
test('quality report exposes actual capacity and the 90-day deficit instead of a false endless-content guarantee',()=>{
 const report=qualityReport(pool,{trials:2});
 assert.equal(report.distinctPublishedAnswers,new Set(pool.map(q=>q.answerId)).size);
 assert(report.capacity.upperBoundSets>=10);assert.equal(report.sourceCoverage,pool.length);
 assert.equal(report.target.answersPerLength,540);assert(report.target.deficits.every(g=>g.missingAnswers>=0));
 assert(report.simulatedClassicGames.minimum>=5);assert(report.simulatedClassicGames.maximum<=report.capacity.upperBoundSets);
});
