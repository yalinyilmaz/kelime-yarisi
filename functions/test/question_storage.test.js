import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {compactQuestion} from '../src/question_storage.js';
import {isPublished, reviewDigest, validateQuestion} from '../src/content.js';
import {generationEvidence} from '../src/content_generation.js';

const pool=JSON.parse(readFileSync(new URL('../content/published.json',import.meta.url)));

test('compaction preserves playable content, approval, source evidence and licence attribution',()=>{
 for(const q of pool){
  const compact=compactQuestion(q);
  assert(isPublished(compact));
  for(const key of ['id','answerId','answer','clue','hints','acceptedAnswers','rootId','relatedAnswerIds','topic','difficulty'])assert.deepEqual(compact[key],q[key]);
  assert.equal(compact.source.reference,q.source.reference);
  assert.equal(compact.source.meaningEvidence,q.source.meaningEvidence);
  assert.equal(compact.source.rights,q.source.rights);
  if(q.source.rights==='licensed')assert.equal(compact.source.termsReference,q.source.termsReference);
  const before=generationEvidence(q),after=generationEvidence(compact);
  for(const key of ['reference','meaningEvidence','rights'])assert.deepEqual(after[key],before[key]);
  if(q.source.rights==='licensed')assert.equal(after.termsReference,before.termsReference);
  assert.equal(compact.review.reviewedAtMs,q.review.reviewedAtMs);
  assert.equal(compact.meaningId,undefined);assert.equal(compact.review.contentDigest,undefined);
  assert.deepEqual(compactQuestion(compact),compact);
 }
});

test('metadata pruning never repairs an invalid approval or permits changed hints',()=>{
 const q=pool[0];
 assert.throws(()=>compactQuestion({...q,clue:'Onaysız değişiklik.'}),/Invalid question/);
 const compact=compactQuestion(q);
 assert(validateQuestion({...compact,hints:['Sonradan değiştirildi.','İkinci ipucu.']}).includes('invalid-editor-approval'));
 assert.equal(compact.review.digest,reviewDigest(compact));
});

test('legacy duplicate evidence is removed without losing attribution or modifying its input',()=>{
 const q=structuredClone(pool.find(q=>{try{return JSON.parse(q.source.meaningEvidence).encyclopedia;}catch{return false;}}));
 const evidence=JSON.parse(q.source.meaningEvidence);
 q.meaningId='legacy-meaning-copy';
 q.source.evidence=evidence.wikidata;q.source.encyclopedia=evidence.encyclopedia;
 q.source.hintReference=q.source.reference;q.review.sourceSupport=q.source.meaningEvidence;
 q.review.digest=reviewDigest(q);q.review.contentDigest=reviewDigest(q);
 const compact=compactQuestion(q);
 assert.equal(compact.source.evidence,undefined);assert.equal(compact.source.encyclopedia,undefined);
 assert.equal(compact.source.hintReference,undefined);assert.equal(compact.review.sourceSupport,undefined);
 const retained=JSON.parse(compact.source.meaningEvidence).encyclopedia;
 assert.equal(retained.license,evidence.encyclopedia.license);
 assert.equal(retained.attribution,evidence.encyclopedia.attribution);
 assert.equal(retained.reference,evidence.encyclopedia.reference);
 assert(q.source.encyclopedia);assert(isPublished(compact));
});
