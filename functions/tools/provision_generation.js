// Explicit dev-only provisioning. Values travel via stdin, never CLI arguments.
import {execFileSync} from 'node:child_process';
import {resolve} from 'node:path';
import {loadLocalConfig} from './lib/local_config.js';
import {checkDeployment} from './lib/deploy_guard.js';

const args=process.argv.slice(2),project=args[args.indexOf('--project')+1];
const root=resolve(import.meta.dirname,'../..');
function gcloud(command,{input,missingOK=false}={}) {
  try {return execFileSync('gcloud',[...command,`--project=${project}`,'--quiet','--format=json'],{input,encoding:'utf8',stdio:['pipe','pipe','pipe']});}
  catch(error){if(missingOK&&/NOT_FOUND|does not exist/u.test(error.stderr??''))return null;throw new Error(`Dev provisioning failed at ${command.slice(0,3).join(' ')}; values are not logged.`);}
}
try {
  if(!args.includes('--project')||project!=='kelime-yarisi-yalin'||!args.includes('--set-secret'))throw new Error('Requires --project kelime-yarisi-yalin --set-secret. Production provisioning is not enabled.');
  checkDeployment(root);
  const config=loadLocalConfig(root);
  if(!config.apiKey||config.model!=='gpt-6-luna')throw new Error('Local key and explicitly selected gpt-6-luna are required.');
  const billing=JSON.parse(gcloud(['billing','projects','describe',project]));
  if(billing.billingEnabled!==true)throw new Error('Dev billing must be enabled before provisioning.');
  const email=`question-generator@${project}.iam.gserviceaccount.com`;
  if(!gcloud(['iam','service-accounts','describe',email],{missingOK:true}))gcloud(['iam','service-accounts','create','question-generator','--display-name=Daily question generator']);
  for(const role of ['roles/firebasedatabase.admin','roles/logging.logWriter'])gcloud(['projects','add-iam-policy-binding',project,`--member=serviceAccount:${email}`,`--role=${role}`,'--condition=None']);
  if(!gcloud(['secrets','describe','OPENAI_API_KEY'],{missingOK:true}))gcloud(['secrets','create','OPENAI_API_KEY','--replication-policy=automatic']);
  gcloud(['secrets','versions','add','OPENAI_API_KEY','--data-file=-'],{input:config.apiKey});
  gcloud(['secrets','add-iam-policy-binding','OPENAI_API_KEY',`--member=serviceAccount:${email}`,'--role=roles/secretmanager.secretAccessor','--condition=None']);
  console.log(JSON.stringify({project,serviceAccount:email,secretConfigured:true,keyLogged:false}));
}catch(error){console.error(error.message);process.exitCode=1;}
