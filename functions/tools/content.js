import {readFileSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {randomUUID} from 'node:crypto';
import {answerId, approveQuestion, candidatePrompt, isPublished, normalizeWord, REVIEW_CHECKS, validatePool} from '../src/content.js';
import {capacityReport} from '../src/set_selector.js';

const [command, ...args] = process.argv.slice(2);
const flag = name => {
  const index = args.indexOf(`--${name}`);
  return index >= 0 && args[index + 1] && !args[index + 1].startsWith('--') ? args[index + 1] : undefined;
};
const root = resolve(import.meta.dirname, '../..');
const file = resolve(root, args.includes('--file') ? flag('file') : 'content/questions.json');
const pool = JSON.parse(readFileSync(file, 'utf8'));
try {
  if (command === 'draft') {
    const answer = normalizeWord(flag('answer') ?? '');
    if (!/^[A-ZÇĞİÖŞÜ]{4,10}$/u.test(answer)) throw new Error('A Turkish single-word answer of 4–10 letters is required.');
    const id = flag('id') ?? randomUUID();
    if (!/^[A-Za-z0-9_-]{1,100}$/.test(id) || pool.some(q => q.id === id)) throw new Error('Question ID must be valid and unique.');
    pool.push({id, answer, answerId: answerId(answer), letterCount: [...answer].length,
      meaningId: `${id}_sense`, meaning: '', clue: '', topic: '', difficulty: 1,
      rootId: answerId(answer), rootText: answer, relatedAnswerIds: [], origin: 'production',
      source: {reference: '', meaningEvidence: '', termsReference: '', rights: 'unknown'},
      review: {status: 'draft'}, publication: 'unpublished'});
    writeFileSync(file, `${JSON.stringify(pool, null, 2)}\n`);
    console.log(`Draft ${id} created. Complete meaning, clue, topic, difficulty, root family and cleared source references before review.`);
  } else if (command === 'review') {
    const index = pool.findIndex(q => q.id === flag('id'));
    if (index < 0) throw new Error('Question not found.');
    const confirmed = (flag('checks') ?? '').split(',');
    pool[index] = approveQuestion(pool[index], flag('editor'), Object.fromEntries(REVIEW_CHECKS.map(k => [k, confirmed.includes(k)])));
    writeFileSync(file, `${JSON.stringify(pool, null, 2)}\n`);
    console.log('Editor approval recorded. Publication remains off.');
  } else if (command === 'publish') {
    const errors = validatePool(pool);
    if (errors.length) throw new Error(JSON.stringify(errors));
    const production = pool.filter(q => q.origin === 'production' && q.review.status === 'approved')
      .map(q => ({...q, publication: 'published'})).filter(q => isPublished(q));
    const destination = args.includes('--out') ? resolve(root, flag('out')) : `${root}/functions/content/published.json`;
    writeFileSync(destination, `${JSON.stringify(production, null, 2)}\n`);
    console.log(`Published artifact: ${production.length} production question records. No remote deploy performed.`);
  } else if (command === 'validate') {
    const errors = validatePool(pool);
    if (errors.length) throw new Error(JSON.stringify(errors, null, 2));
    console.log(`Validated ${pool.length} records. Semantic correctness still requires an editor.`);
  } else if (command === 'report') {
    console.log(JSON.stringify(capacityReport(pool, [], {includeExamples: args.includes('--examples')}), null, 2));
  } else if (command === 'prompt') {
    const question = pool.find(q => q.id === flag('id'));
    if (!question) throw new Error('Question not found.');
    console.log(candidatePrompt(question));
  } else {
    throw new Error('Commands: draft --answer WORD [--id ID] | validate | report | review --id ID --editor NAME --checks spelling,meaning,uniqueAnswer,noLeak,originality,sourceRights | publish | prompt --id ID. Optional --file PATH.');
  }
} catch (error) {console.error(error.message); process.exitCode = 1;}
