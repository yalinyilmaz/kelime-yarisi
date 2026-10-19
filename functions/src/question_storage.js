import {isDeepStrictEqual} from 'node:util';
import {reviewDigest, validateQuestion} from './content.js';

// Remove redundant storage only after approval checks. Clues, hints, identities,
// licence references and the single retained source-evidence copy stay intact.
export function compactQuestion(question) {
  if (validateQuestion(question).length) throw new Error('Invalid question cannot be compacted.');
  const q = structuredClone(question);
  delete q.meaningId;
  if (q.hints?.length === 2) delete q.hint;
  const source = q.source;
  let evidence;
  try { evidence = JSON.parse(source.meaningEvidence); } catch { /* Plain text evidence. */ }
  if (source.evidence && isDeepStrictEqual(source.evidence, evidence?.wikidata)) delete source.evidence;
  if (source.encyclopedia && isDeepStrictEqual(source.encyclopedia, evidence?.encyclopedia)) delete source.encyclopedia;
  if (source.hintReference === source.reference) delete source.hintReference;
  for (const key of ['inheritedVerification', 'verificationOrigin', 'hintVerificationMethod']) delete source[key];
  if (source.rights === 'original' && /^Project-authored /u.test(source.termsReference)) {
    source.termsReference = 'Original project-authored content.';
  }
  const duplicatedSupport = [source.meaningEvidence, source.hintEvidence].filter(Boolean).join('\n');
  if (q.review.sourceSupport === source.meaningEvidence || q.review.sourceSupport === duplicatedSupport) delete q.review.sourceSupport;
  if (q.review.rationale === `${source.meaningEvidence} İpucu denetimi: ${source.hintEvidence}`) {
    q.review.rationale = 'Anlam ve ipucu kanıtları source alanında; editör kontrolleri tamamlandı.';
  }
  delete q.review.contentDigest; // review.digest already binds all content fields.
  delete q.review.sourceVerificationScope;
  if (q.generation) {
    delete q.generation.originalWording;
    delete q.generation.candidates;
  }
  if (q.review.status === 'approved') q.review.digest = reviewDigest(q);
  if (validateQuestion(q).length) throw new Error('Compacted question failed approval checks.');
  return q;
}
