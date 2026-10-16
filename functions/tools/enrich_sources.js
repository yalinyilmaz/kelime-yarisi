// Capture short, attributed encyclopedia extracts for editorial fact checking.
// Extracts stay on the backend. Question wording must be original.
import {readFileSync, writeFileSync, existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {setTimeout as delay} from 'node:timers/promises';
const args=process.argv.slice(2);
const root=resolve(import.meta.dirname,'../..');
const flag=name=>{const i=args.indexOf(`--${name}`);return i>=0?args[i+1]:undefined;};
try {
  if (!flag('file') || !flag('out')) throw new Error('--file and a new --out path are required.');
  const output=resolve(root,flag('out'));
  if (existsSync(output)) throw new Error('Output already exists.');
  const pool=JSON.parse(readFileSync(resolve(root,flag('file')),'utf8'));
  for (let start=0;start<pool.length;start+=20) {
    if(start) await delay(3000);
    const chunk=pool.slice(start,start+20);
    const params=new URLSearchParams({action:'query',format:'json',prop:'extracts|revisions',titles:chunk.map(q=>q.source.evidence.titles.enwiki).join('|'),
      exintro:'1',explaintext:'1',exchars:'1800',exlimit:'20',rvprop:'ids',redirects:'1'});
    let response;
    for(let attempt=0;attempt<3;attempt++) {
      response=await fetch(`https://en.wikipedia.org/w/api.php?${params}`,{signal:AbortSignal.timeout(30000),headers:{'User-Agent':'KelimeYarisiContent/1.0 (attributed source verification)'}});
      if(![429,502,503].includes(response.status))break;
      await response.body?.cancel();await delay(10000);
    }
    if(!response.ok)throw new Error(`Wikipedia HTTP ${response.status}.`);
    const data=await response.json();
    if(data.error)throw new Error(`Wikipedia error: ${data.error.code}`);
    for(const q of chunk) {
      let title=q.source.evidence.titles.enwiki;
      const redirects=[...(data.query?.normalized??[]),...(data.query?.redirects??[])];
      const visited=new Set();
      while(!visited.has(title)) {
        visited.add(title);
        const redirect=redirects.find(r=>r.from===title);
        if(!redirect)break;
        title=redirect.to;
      }
      const page=Object.values(data.query?.pages??{}).find(p=>p.title===title);
      if(!page?.extract?.trim() || !page.revisions?.[0]?.revid)throw new Error(`Missing encyclopedia evidence: ${q.answer}`);
      q.source.encyclopedia={title:page.title,reference:`https://en.wikipedia.org/w/index.php?oldid=${page.revisions[0].revid}`,
        attribution:`Wikipedia contributors, ${page.title}`,license:'CC-BY-SA-4.0',
        termsReference:'https://en.wikipedia.org/wiki/Wikipedia:Copyrights',retrievedAt:new Date().toISOString(),extract:page.extract};
      q.source.rights='licensed';
      q.source.termsReference='https://en.wikipedia.org/wiki/Wikipedia:Copyrights';
      q.source.meaningEvidence=JSON.stringify({wikidata:q.source.evidence,encyclopedia:q.source.encyclopedia});
    }
  }
  writeFileSync(output,`${JSON.stringify(pool,null,2)}\n`,{flag:'wx'});
  console.log(`Captured attributed source extracts for ${pool.length} drafts. Editorial approval still required.`);
}catch(error){console.error(error.message);process.exitCode=1;}
