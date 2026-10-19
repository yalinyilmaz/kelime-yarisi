import {existsSync,lstatSync,readFileSync,readdirSync} from 'node:fs';
import {resolve,relative} from 'node:path';
import {execFileSync} from 'node:child_process';
import {containsSecret,loadLocalConfig} from './local_config.js';

const requiredIgnores=['node_modules','test','tools','.env','.env.*','**/.env','**/.env.*','.local','**/.local/**','.secret.local','**/.secret.local','src/content_quality.js','*.log','sentry.properties','**/sentry.properties','.sentryclirc','**/.sentryclirc'];
const localOnly=new Set(['node_modules','test','tools','.local']);
const excludedSources=new Set(['src/content_quality.js','content/examples.json']);

export function checkDeployment(root) {
  const config=JSON.parse(readFileSync(resolve(root,'firebase.json'),'utf8'));
  const functionsConfig=config.functions?.find(c=>c.codebase==='question-pool');
  if(functionsConfig?.source!=='functions'||requiredIgnores.some(p=>!functionsConfig.ignore?.includes(p)))throw new Error('Deploy protection missing: keep local config, env files and generation tools outside the upload.');
  if(!functionsConfig.predeploy?.some(p=>p.includes('tools/check_deploy.js')))throw new Error('Deploy protection hook is missing.');
  for(const name of ['.local/question-generation.env','functions/.env','functions/.env.prod','functions/.env.local']) {
    try {execFileSync('git',['check-ignore','--no-index','--quiet',name],{cwd:root,stdio:'ignore'});}
    catch {throw new Error('Local credentials/env paths must be ignored by Git.');}
  }
  const tracked=execFileSync('git',['ls-files','--','.local','.env','.env.*','functions/.env','functions/.env.*'],{cwd:root,encoding:'utf8'});
  if(tracked.trim())throw new Error('A local config/env file is already tracked by Git. Untrack it before deployment; values are not printed.');
  const {apiKey}=loadLocalConfig(root);
  let filesChecked=0;
  const scan=directory=>{
    for(const name of readdirSync(directory)) {
      const path=resolve(directory,name), pathInFunctions=relative(resolve(root,'functions'),path).replaceAll('\\','/');
      if(localOnly.has(pathInFunctions.split('/')[0])||excludedSources.has(pathInFunctions)||name.endsWith('.log'))continue;
      const stat=lstatSync(path);
      if(stat.isSymbolicLink())throw new Error('Symlinks are not allowed in the functions upload.');
      if(stat.isDirectory()){scan(path);continue;}
      if(['sentry.properties','.sentryclirc'].includes(name))throw new Error('Sentry upload authentication must remain outside the functions upload.');
      const text=readFileSync(path,'utf8');
      // Firebase can read .env before packaging. Ignore patterns alone do not stop that.
      if(name==='.env'||name.startsWith('.env.')||name==='.secret.local') {
        const assignments=text.split(/\r?\n/u).filter(line=>line.trim()&&!line.trimStart().startsWith('#'));
        if(assignments.some(line=>!/^QUESTION_POOL_EXAMPLES=(?:true|false)\s*$/u.test(line)&&!/^SENTRY_DSN=https:\/\/[a-f\d]{32}@[a-z\d.-]+\.ingest(?:\.[a-z]+)?\.sentry\.io\/\d+\s*$/u.test(line)))throw new Error('Only QUESTION_POOL_EXAMPLES and a public SENTRY_DSN ingestion address are allowed in functions env files. Keep API/auth credentials in the root .local directory.');
        continue;
      }
      if(/(?:sntrys|sntryu)_[a-z\d_-]{20,}|SENTRY_AUTH_TOKEN\s*[=:]\s*['"][^'"\s]+/iu.test(text)||containsSecret(text,apiKey)||/-----BEGIN (?:[A-Z ]*PRIVATE KEY)-----|"private_key"\s*:\s*"[^"\s]/u.test(text)||/\.(?:pem|p8|p12|pfx|key)$/iu.test(name))throw new Error('A credential or private-key file was detected in the functions upload. Deployment stopped; values are not printed.');
      filesChecked++;
    }
  };
  scan(resolve(root,'functions'));
  if(existsSync(resolve(root,'pubspec.yaml'))) {
    const pubspec=readFileSync(resolve(root,'pubspec.yaml'),'utf8');
    if(containsSecret(pubspec,apiKey)||/\.local\/|question-generation\.env/u.test(pubspec))throw new Error('Local credentials must not be included in Flutter configuration/assets.');
  }
  return {filesChecked,localConfigExcluded:true,functionsEnvChecked:true};
}
