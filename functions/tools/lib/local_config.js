import {existsSync, lstatSync, readFileSync, realpathSync} from 'node:fs';
import {resolve} from 'node:path';

export const localConfigPath=root=>resolve(root,'.local/question-generation.env');
const allowed=new Set(['OPENAI_API_KEY','OPENAI_MODEL']);
export function loadLocalConfig(root,{env=process.env}={}) {
  const path=localConfigPath(realpathSync(root));
  let values={};
  if(existsSync(path)) {
    const info=lstatSync(path);
    if(!info.isFile()||info.isSymbolicLink()||realpathSync(path)!==path) throw new Error('Local generator config must be a regular file at .local/question-generation.env.');
    if(process.platform!=='win32'&&(info.mode&0o077)!==0)throw new Error('Local generator config must have mode 600. Run chmod 600 .local/question-generation.env.');
    for(const line of readFileSync(path,'utf8').split(/\r?\n/u)) {
      if(!line.trim()||line.trimStart().startsWith('#'))continue;
      const match=line.match(/^([A-Z_]+)=(.*)$/u);
      if(!match||!allowed.has(match[1])||Object.hasOwn(values,match[1]))throw new Error('Invalid local config. Use OPENAI_API_KEY and OPENAI_MODEL only; no shell syntax or duplicate entries.');
      let value=match[2].trim();
      if((value.startsWith('"')&&value.endsWith('"'))||(value.startsWith("'")&&value.endsWith("'")))value=value.slice(1,-1);
      if(/[\r\n\x00]/u.test(value))throw new Error('Invalid local config value.');
      values[match[1]]=value;
    }
  }
  // Explicit process environment wins. File contents are never evaluated as shell.
  return {apiKey:env.OPENAI_API_KEY?.trim()||values.OPENAI_API_KEY||'',model:env.OPENAI_MODEL?.trim()||values.OPENAI_MODEL||''};
}

export const secretPattern=/sk-(?:(?:proj|svcacct)-)?[A-Za-z0-9_-]{20,}/gu;
export function containsSecret(value,apiKey='') {
  const text=typeof value==='string'?value:JSON.stringify(value);
  return Boolean(apiKey&&text.includes(apiKey))||new RegExp(secretPattern.source,'u').test(text);
}
export function safeError(error,apiKey='') {
  let message=typeof error?.message==='string'?error.message:'Generator failed.';
  if(apiKey)message=message.split(apiKey).join('[REDACTED]');
  return message.replace(secretPattern,'[REDACTED]');
}
