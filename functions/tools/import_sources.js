// Public CC0 metadata only. Never downloads competition/question archives.
import {readFileSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {answerId, normalizeWord} from '../src/content.js';
import {setTimeout as delay} from 'node:timers/promises';

const args = process.argv.slice(2);
const flag = name => args[args.indexOf(`--${name}`) + 1];
const root = resolve(import.meta.dirname, '../..');
try {
  if (!args.includes('--out')) throw new Error('An explicit --out PATH is required; existing content is never overwritten.');
  const destination = resolve(root,flag('out'));
  const {existsSync} = await import('node:fs');
  if (existsSync(destination)) throw new Error('Output already exists. Choose a new source batch.');
  const lines = readFileSync(resolve(root,args.includes('--seeds') ? flag('seeds') : 'content/seed_words.tsv'), 'utf8').trim().split('\n').slice(1);
  const seeds = lines.map(line => {
    const [word, wikiTitle, topic, level, grammaticalType] = line.split('\t');
    const answer = normalizeWord(word), difficulty = Number(level);
    const wordLengths=answer.split(' ').map(part=>[...part].length),letterCount=wordLengths.reduce((a,b)=>a+b,0);
    if (!/^[A-ZÇĞİÖŞÜ]+(?: [A-ZÇĞİÖŞÜ]+)?$/u.test(answer) || letterCount<4 || letterCount>10 || !wikiTitle || !topic || ![1,2,3].includes(difficulty)) throw new Error(`Invalid seed: ${word}`);
    return {answer, wikiTitle, topic, difficulty, wordLengths, letterCount, ...(grammaticalType?{grammaticalType}:{})};
  });
  if (new Set(seeds.map(s => s.answer)).size !== seeds.length) throw new Error('Duplicate seed answer.');
  const records = [], missing = [];
  for (let offset = 0; offset < seeds.length; offset += 50) {
    if (offset) await delay(3000);
    const chunk = seeds.slice(offset, offset + 50);
    const params = new URLSearchParams({action: 'wbgetentities', sites: 'enwiki', titles: chunk.map(s => s.wikiTitle).join('|'),
      props: 'info|labels|descriptions|sitelinks', languages: 'tr|en', sitefilter: 'enwiki|trwiki', redirects: 'yes', format: 'json'});
    let response;
    for (let attempt = 0; attempt < 3; attempt++) {
      response = await fetch(`https://www.wikidata.org/w/api.php?${params}`, {
        headers: {'User-Agent': 'KelimeYarisiContent/1.0 (CC0 source verification; local authoring)'}, signal: AbortSignal.timeout(30000)});
      if (![429, 502, 503].includes(response.status)) break;
      await response.body?.cancel();
      await delay(Math.min(30000, Math.max(10000, Number(response.headers.get('retry-after') ?? 0) * 1000)));
    }
    if (!response.ok) throw new Error(`Wikidata HTTP ${response.status}; no output written.`);
    const data = await response.json();
    if (data.error) throw new Error(`Wikidata error: ${data.error.code}`);
    for (const seed of chunk) {
      const entity = Object.values(data.entities ?? {}).find(e => e.sitelinks?.enwiki?.title === seed.wikiTitle);
      if (!entity?.id?.startsWith('Q') || !entity.descriptions?.en?.value || /disambiguation|Wikimedia category/iu.test(entity.descriptions.en.value)) {
        missing.push(seed.answer); continue;
      }
      const evidence = {entityId: entity.id, revision: entity.lastrevid, retrievedAt: new Date().toISOString(),
        labels: Object.fromEntries(Object.entries(entity.labels ?? {}).map(([language, v]) => [language, v.value])),
        descriptions: Object.fromEntries(Object.entries(entity.descriptions ?? {}).map(([language, v]) => [language, v.value])),
        titles: Object.fromEntries(Object.entries(entity.sitelinks ?? {}).map(([site, v]) => [site, v.title]))};
      const id = `tr_${answerId(seed.answer).slice(4, 28)}`;
      records.push({id, answer: seed.answer, answerId: answerId(seed.answer), letterCount: seed.letterCount,
        wordLengths:seed.wordLengths, answerType:seed.wordLengths.length===2?'phrase':seed.grammaticalType==='conjunction'?'conjunction':'word',
        ...(seed.grammaticalType?{grammaticalType:seed.grammaticalType}:{}),
        meaningId: `${entity.id}_sense`, meaning: entity.descriptions.tr?.value ?? entity.descriptions.en.value, clue: '', topic: seed.topic, difficulty: seed.difficulty,
        rootId: answerId(seed.answer), rootText: seed.answer, relatedAnswerIds: [], origin: 'production',
        source: {reference: `https://www.wikidata.org/wiki/${entity.id}`, meaningEvidence: JSON.stringify(evidence),
          termsReference: 'https://www.wikidata.org/wiki/Wikidata:Licensing', rights: 'public-domain', evidence},
        review: {status: 'draft'}, publication: 'unpublished'});
    }
  }
  if (missing.length) throw new Error(`Unresolved or ambiguous sources: ${missing.join(', ')}. No output written.`);
  writeFileSync(destination, `${JSON.stringify(records, null, 2)}\n`, {flag: 'wx'});
  console.log(`Imported ${records.length} source-backed drafts with source meanings. Turkish wording, question and editorial review still required.`);
} catch (error) {console.error(error.message); process.exitCode = 1;}
