// Dev-only, additive backfill/benchmark. No paid model call, no question changes.
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {randomUUID} from 'node:crypto';
import {performance} from 'node:perf_hooks';
import {isDeepStrictEqual} from 'node:util';
import {ResponseIndex} from '../src/response_index.js';
import {decodeStoredQuestion, mergePublishedPool} from '../src/published_pool.js';
import {validatePool, validateQuestion} from '../src/content.js';

const args = process.argv.slice(2);
if (!args.includes('--project=kelime-yarisi-yalin') ||
    args.some(a => !['--project=kelime-yarisi-yalin', '--apply'].includes(a))) {
  throw new Error('Use --project=kelime-yarisi-yalin [--apply]. Production is not supported.');
}
let phase = 'configuration';
async function main() {
  const config = JSON.parse(readFileSync(new URL('../../android/app/src/dev/google-services.json', import.meta.url)));
  if (config.project_info.project_id !== 'kelime-yarisi-yalin') throw new Error('Unexpected project.');
  const token = execFileSync('gcloud', ['auth', 'print-access-token', '--project=kelime-yarisi-yalin'], {encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']}).trim();
  const base = config.project_info.firebase_url.replace(/\/$/u, '');
  async function request(path, method = 'GET', value, extra = {}) {
    const result = await fetch(`${base}/${path}.json`, {
      method, headers: {Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', ...extra},
      ...(value === undefined ? {} : {body: JSON.stringify(value)}), signal: AbortSignal.timeout(60000),
    });
    if (!result.ok) {const error = new Error('Database request failed.');error.status = result.status;throw error;}
    return {value: await result.json(), etag: result.headers.get('etag')};
  }
  const owner = `response-index-${randomUUID()}`;
  let locked = false;
  try {
    phase = 'lease';
    const lease = await request('questionGeneration/lease', 'GET', undefined, {'X-Firebase-ETag': 'true'});
    if (lease.value?.expiresAtMs > Date.now()) throw new Error('Generator active.');
    if (args.includes('--apply')) {
      await request('questionGeneration/lease', 'PUT', {owner, expiresAtMs: Date.now() + 300000}, {'if-match': lease.etag});
      locked = true;
    }
    phase = 'read-and-validate';
    const snapshot = await request('questionPool', 'GET', undefined, {'X-Firebase-ETag': 'true'});
    const pool = snapshot.value ?? {};
    const bundled = JSON.parse(readFileSync(new URL('../content/published.json', import.meta.url)));
    const questions = mergePublishedPool(bundled, Object.values(pool.published ?? {}).map(decodeStoredQuestion));
    const previous = pool.generationIndex ? new ResponseIndex(pool.generationIndex).data : ResponseIndex.fromQuestions([]).data;
    const current = ResponseIndex.fromQuestions(questions).data;
    const index = new ResponseIndex({version: 1,
      uniqueResponses: {...previous.uniqueResponses, ...current.uniqueResponses},
      acceptedResponses: {...previous.acceptedResponses, ...current.acceptedResponses},
      questions: {...previous.questions, ...current.questions},
    });
    const measure = action => {
      const samples = Array.from({length: 5}, () => {const start = performance.now();action();return performance.now() - start;}).sort((a,b) => a-b);
      return Number(samples[2].toFixed(3));
    };
    const candidate = questions[0];
    console.log(JSON.stringify({project: 'kelime-yarisi-yalin', dryRun: !args.includes('--apply'),
      publishedQuestions: questions.length, uniqueResponses: Object.keys(index.data.uniqueResponses).length,
      acceptedResponses: Object.keys(index.data.acceptedResponses).length,
      fullRecordBytes: Buffer.byteLength(JSON.stringify(questions)),
      indexBytes: Buffer.byteLength(JSON.stringify(index.data)),
      answersOnlyBytes: Buffer.byteLength(JSON.stringify(index.data.uniqueResponses)),
      candidateCheckMedianMs: candidate ? {
        previous: measure(() => validatePool([...questions, candidate])),
        indexed: measure(() => {validateQuestion(candidate);index.candidateErrors(candidate);}),
      } : null,
      paidApiCalls: 0,
    }));
    if (!args.includes('--apply')) return;
    phase = 'conditional-write';
    // Compare-and-swap the exact snapshot: concurrent publication aborts rather
    // than overwriting a question. Only generationIndex differs from the read.
    await request('questionPool', 'PUT', {...pool, generationIndex: index.data}, {'if-match': snapshot.etag});
    phase = 'verify';
    const stored = new ResponseIndex((await request('questionPool/generationIndex')).value);
    if (!isDeepStrictEqual(stored.data, index.data)) throw new Error('Index verification failed.');
    console.log(JSON.stringify({index: 'verified', uniqueResponses: Object.keys(stored.data.uniqueResponses).length, questionsChanged: 0}));
  } finally {
    if (locked) {
      const lease = await request('questionGeneration/lease', 'GET', undefined, {'X-Firebase-ETag': 'true'});
      if (lease.value?.owner === owner) await request('questionGeneration/lease', 'DELETE', undefined, {'if-match': lease.etag});
    }
  }
}
main().catch(error => {
  console.error(`Dev response index failed at ${phase}${Number.isInteger(error.status) ? ` (HTTP ${error.status})` : ''}; no credentials or question text logged.`);
  process.exitCode = 1;
});
