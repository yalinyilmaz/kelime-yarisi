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

// Runtime selection reads only this small ID index, never the full question pool.
export async function loadPublishedSetIds(database) {
  const index = (await database.ref('questionPool/setIndex').get()).val() ?? {};
  if (Object.entries(index).some(([id, published]) =>
    !/^[A-Za-z0-9_-]{1,100}$/.test(id) || published !== true)) throw new Error('Invalid published set index.');
  return Object.keys(index);
}

export async function loadPublishedSet(database, id) {
  if (!/^[A-Za-z0-9_-]{1,100}$/.test(id)) throw new Error('Invalid set ID.');
  const raw = (await database.ref(`questionPool/sets/${id}`).get()).val();
  const manifest = decodeStoredQuestion(raw);
  if (manifest?.id !== id || !Array.isArray(manifest.questionIds) ||
      manifest.questionIds.length !== 14 || new Set(manifest.questionIds).size !== 14 ||
      manifest.questionIds.some(key => typeof key !== 'string' || !/^[A-Za-z0-9_-]{1,100}$/.test(key))) {
    throw new Error('Invalid selected set manifest.');
  }
  const questions = await Promise.all(manifest.questionIds.map(async key => {
    const record = decodeStoredQuestion((await database.ref(`questionPool/published/${key}`).get()).val());
    if (record?.id !== key) throw new Error('Selected set question is missing.');
    return record;
  }));
  // Verify only the selected fourteen records; global editorial checks run at publication.
  return resolveQuestionSets({[id]: manifest}, mergePublishedPool([], questions))[0];
}
