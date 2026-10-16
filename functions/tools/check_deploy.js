import {resolve} from 'node:path';
import {checkDeployment} from './lib/deploy_guard.js';
try {console.log(JSON.stringify({deployProtection:'passed',...checkDeployment(resolve(import.meta.dirname,'../..'))}));}
catch {console.error('Deploy protection failed. Check local config permissions, Git ignore/tracking, firebase.json exclusions and functions files. Secret values are never printed.');process.exitCode=1;}
