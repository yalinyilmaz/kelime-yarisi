import {readFileSync, writeFileSync, existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {answerId, approveQuestion, normalizeWord, reviewDigest, validatePool, REVIEW_CHECKS} from '../src/content.js';
import {mergePublishedPool} from '../src/published_pool.js';
import {selectSet} from '../src/set_selector.js';
import {compactQuestion} from '../src/question_storage.js';

// Offline conversion only. No Firebase connection, credentials or paid API.
export function prepareExchange(batch, existingPool = [], now = Date.now()) {
  if (batch?.schemaVersion !== 'kelime-yarisi-content-pilot-1' ||
      !Array.isArray(batch.sets) || !batch.sets.length) throw new Error('Invalid exchange batch.');
  const questions = [], sets = [];
  const ids = new Set(existingPool.map(q => q.id));
  const answers = new Set(existingPool.map(q => q.answerId));
  const setIds = new Set();
  for (const set of batch.sets) {
    if (typeof set.id !== 'string' || setIds.has(set.id) || set.questions?.length !== 14) throw new Error('Invalid or duplicate set.');
    setIds.add(set.id);
    const converted = [];
    for (const input of set.questions) {
      if (input.review?.decision !== 'approve' ||
          [...REVIEW_CHECKS, 'hintConsistency', 'hintNoLeak'].some(key => input.review.checks?.[key] !== true) ||
          input.source?.verificationStatus !== 'verified' || input.hints?.length !== 2 || !input.source.hintEvidence?.trim()) {
        throw new Error(`Editorial/source checks incomplete: ${input.id}`);
      }
      const answer = normalizeWord(input.answer), identity = answerId(answer);
      if (ids.has(input.id) || answers.has(identity)) throw new Error(`Duplicate question/answer: ${input.id}`);
      ids.add(input.id); answers.add(identity);
      const record = {
        id: input.id, answer, answerId: identity, letterCount: input.letterCount,
        wordLengths: input.wordLengths, answerType: input.answerType,
        grammaticalType: input.grammaticalType, acceptedAnswers: input.acceptedAnswers ?? [],
        meaningId: `${input.id}_sense`, meaning: input.meaning,
        clue: input.clue, hints: input.hints, topic: input.topic, difficulty: input.difficulty,
        rootText: normalizeWord(input.rootText), rootId: answerId(input.rootText),
        relatedAnswerIds: (input.relatedAnswers ?? []).map(answerId), origin: 'production',
        source: {...input.source, termsReference: 'Project-authored questions, hints and factual summaries. Reference material is not reproduced; no television question archive used.'},
        generation: {method: 'chat-authored-exchange', batchId: batch.batchId, setId: set.id},
        review: {status: 'draft'}, publication: 'unpublished',
      };
      const checked = approveQuestion(record, 'Codex — Türkçe editör öz incelemesi', input.review.checks, now);
      checked.review = {...checked.review, kind: 'ai-self-review',
        model: 'Codex current session (no separate model API request)',
        contentDigest: reviewDigest(checked), rationale: input.review.rationale,
        sourceSupport: `${input.source.meaningEvidence}\n${input.source.hintEvidence}`,
        alternativePolicy: input.review.alternativePolicy,
        alternativesRejected: input.review.alternativesRejected,
        sourceVerificationScope: input.review.sourceVerificationScope};
      const compacted=compactQuestion(checked);
      converted.push(compacted); questions.push(compacted);
    }
    const lengths = converted.map(q => q.letterCount).sort((a, b) => a - b);
    if (JSON.stringify(lengths) !== JSON.stringify([4,4,5,5,6,6,7,7,8,8,9,9,10,10])) throw new Error(`Invalid length balance: ${set.id}`);
    const counts = Object.fromEntries([...new Set(converted.map(q => q.grammaticalType))]
      .map(type => [type, converted.filter(q => q.grammaticalType === type).length]));
    if (JSON.stringify(Object.entries(counts).sort()) !== JSON.stringify(Object.entries(set.grammaticalTypeCounts ?? {}).sort())) throw new Error(`Invalid category counts: ${set.id}`);
    // Uses the real selector to enforce root, topic and difficulty constraints.
    selectSet(converted.map(q => ({...q, publication: 'published'})), [], {random: () => 0.5});
    sets.push({id: set.id, questionIds: converted.map(q => q.id)});
  }
  const errors = validatePool(questions);
  if (errors.length) throw new Error(JSON.stringify(errors, null, 2));
  const published = questions.map(q => ({...q, publication: 'published'}));
  const merged = mergePublishedPool(existingPool, published);
  return {questions, rtdb: Object.fromEntries(published.map(q => [q.id, JSON.stringify(q)])),
    summary: {batchId: batch.batchId, sets, questionCount: questions.length,
      acceptedAlternatives: questions.reduce((sum, q) => sum + q.acceptedAnswers.length, 0),
      combinedPoolQuestions: merged.length, localChecksPassed: true, deployed: false,
      requiresRuntimeUpdate: true, hintUiImplemented: true,
      sourceVerificationNote: batch.validation?.sourceVerificationNote ?? null}};
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args = process.argv.slice(2);
    const flag = name => {const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : undefined;};
    const input = flag('input'), output = flag('out');
    if (!input || !output) throw new Error('Required: --input EXCHANGE.json --out NEW_OUTPUT_PREFIX');
    const root = resolve(import.meta.dirname, '../..');
    const paths = ['questions.json', 'rtdb.json', 'ready.json'].map(suffix => `${resolve(root, output)}.${suffix}`);
    if (paths.some(existsSync)) throw new Error('Output exists; select a new prefix. No files overwritten.');
    const batch = JSON.parse(readFileSync(resolve(root, input), 'utf8'));
    const pool = JSON.parse(readFileSync(resolve(root, flag('pool') ?? 'functions/content/published.json'), 'utf8'));
    const prepared = prepareExchange(batch, pool);
    for (const [i, data] of [prepared.questions, prepared.rtdb, prepared.summary].entries()) {
      writeFileSync(paths[i], `${JSON.stringify(data, null, 2)}\n`, {flag: 'wx'});
    }
    console.log(JSON.stringify({questionCount: prepared.questions.length, localChecksPassed: true, deployed: false}));
  } catch (error) {console.error(error.message); process.exitCode = 1;}
}
