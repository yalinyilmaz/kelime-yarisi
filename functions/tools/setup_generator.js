import {mkdirSync,writeFileSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {localConfigPath,loadLocalConfig} from './lib/local_config.js';
const root=resolve(import.meta.dirname,'../..');
try {
  mkdirSync(resolve(root,'.local'),{recursive:true,mode:0o700});
  const path=localConfigPath(root);
  if(!existsSync(path))writeFileSync(path,'# Local only. Never commit or put this file inside functions.\n# Enter values here; do not paste the API key into chat.\nOPENAI_API_KEY=\nOPENAI_MODEL=\n',{flag:'wx',mode:0o600});
  const config=loadLocalConfig(root);
  console.log(JSON.stringify({file:path,keyConfigured:Boolean(config.apiKey),modelConfigured:Boolean(config.model),firstTrialQuestions:1,maximumApiCalls:2},null,2));
}catch(error){console.error(error.message);process.exitCode=1;}
