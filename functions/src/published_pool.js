import {isPublished,validatePool} from './content.js';
import {resolveQuestionSets} from './question_sets.js';

export function mergePublishedPool(bundled,remote=[]) {
  if(!Array.isArray(remote)||remote.some(q=>!isPublished(q)))throw new Error('Invalid remote published question pool.');
  const merged=new Map(bundled.map(q=>[q.id,q]));
  for(const q of remote)merged.set(q.id,q);
  const pool=[...merged.values()];
  if(validatePool(pool).length||new Set(pool.map(q=>q.answerId)).size!==pool.length)throw new Error('Published question pool validation failed.');
  return pool;
}
// RTDB removes empty arrays/objects. Preserve the exact reviewed JSON so its
// approval digest survives storage (including relatedAnswerIds: []).
export const decodeStoredQuestion=record=>typeof record==='string'?JSON.parse(record):record;
export const loadPublishedPool=async(database,bundled)=>mergePublishedPool(bundled,Object.values((await database.ref('questionPool/published').get()).val()??{}).map(decodeStoredQuestion));

export async function loadPublishedSets(database, bundled) {
  // Read manifests and their questions from the same committed snapshot.
  const value=(await database.ref('questionPool').get()).val()??{};
  const pool=mergePublishedPool(bundled,Object.values(value.published??{}).map(decodeStoredQuestion));
  return resolveQuestionSets(value.sets, pool);
}
