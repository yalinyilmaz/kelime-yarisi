import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {qualityReport} from '../src/content_quality.js';
const args=process.argv.slice(2);
const root=resolve(import.meta.dirname,'../..');
const flag=name=>{const i=args.indexOf(`--${name}`);return i>=0?args[i+1]:undefined;};
try {
  const file=resolve(root,flag('file')??'functions/content/published.json');
  const report=qualityReport(JSON.parse(readFileSync(file,'utf8')),{trials:Number(flag('trials')??10),days:Number(flag('days')??90),gamesPerDay:Number(flag('games-per-day')??3)});
  console.log(JSON.stringify(report,null,2));
  if(report.automaticErrors.length)process.exitCode=1;
}catch(error){console.error(error.message);process.exitCode=1;}
