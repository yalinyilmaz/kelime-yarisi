import {reportFailure} from './monitoring.js';
import {readFileSync} from 'node:fs';
import {initializeApp} from 'firebase-admin/app';
import {getDatabase} from 'firebase-admin/database';
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {onValueWritten} from 'firebase-functions/v2/database';
import {defineSecret} from 'firebase-functions/params';
import {QuestionService, ServiceError} from './question_service.js';
import {CloudQuestionGenerator} from './cloud_generation.js';
import {loadPublishedSetIds,loadPublishedSet} from './published_pool.js';
import {RaceService} from './race.js';
import {cleanupEmptyRoom} from './room_cleanup.js';

const emulator = process.env.FUNCTIONS_EMULATOR === 'true';
const projectId=process.env.GCLOUD_PROJECT??JSON.parse(process.env.FIREBASE_CONFIG??'{}').projectId;
if(!projectId)throw new Error('Firebase project ID is required.');
if (emulator && process.env.GCLOUD_PROJECT !== 'demo-kelime-yarisi') throw new Error('Use the demo-kelime-yarisi emulator project.');
initializeApp(emulator ? {projectId: 'demo-kelime-yarisi', databaseURL: 'https://demo-kelime-yarisi-default-rtdb.firebaseio.com'} : undefined);
const useExamples = emulator && process.env.QUESTION_POOL_EXAMPLES === 'true';
const pool = JSON.parse(readFileSync(new URL(useExamples ? '../content/examples.json' : '../content/published.json', import.meta.url)));
const service = new QuestionService({database: getDatabase(), pool, includeExamples: useExamples, allowSolo: emulator,
  allowDebugSolo:projectId==='kelime-yarisi-yalin',
  loadSetIds:useExamples?undefined:()=>loadPublishedSetIds(getDatabase()),
  loadSet:useExamples?undefined:id=>loadPublishedSet(getDatabase(),id)});
const options = {region: 'europe-west1', maxInstances: 3, enforceAppCheck: !emulator};
const callable = (name, action) => onCall(options, async request => {
  try {return await action(request.auth?.uid, request.data ?? {});}
  catch (error) {
    await reportFailure(error, name, {expected:error instanceof ServiceError});
    if (error instanceof ServiceError) throw new HttpsError(error.code, error.message, error.details);
    console.error('question-service-failed', error.name);
    throw new HttpsError('internal', 'Soru servisi geçici olarak kullanılamıyor.');
  }
});
export const prepareQuestionHistory = callable('prepareQuestionHistory', (uid, data) => service.prepare(uid, data));
export const startQuestionGame = callable('startQuestionGame', (uid, data) => service.start(uid, data));
export const getSoloQuestionSet = callable('getSoloQuestionSet', (uid, data) => service.solo(uid, data));
const raceService = new RaceService({database: getDatabase(),
  demoQuestions: JSON.parse(readFileSync(new URL('../content/demo.json', import.meta.url))),
  allowDebugSolo: emulator || projectId === 'kelime-yarisi-yalin'});
export const startDemoRaceGame = callable('startDemoRaceGame', (uid, data) => raceService.startDemo(uid, data));
export const playRace = callable('playRace', (uid, data) => raceService.play(uid, data));
export const cleanupEmptyRooms = onValueWritten({
  ref: '/rooms/{roomId}/players/{uid}/isOnline',
  instance: `${projectId}-default-rtdb`,
  region: 'europe-west1', maxInstances: 3, retry: true,
}, async event => {
  if (event.data.before.val() !== true || event.data.after.val() === true) return;
  try {return await cleanupEmptyRoom(getDatabase().ref(`rooms/${event.params.roomId}`));}
  catch (error) {await reportFailure(error, 'cleanupEmptyRooms');throw error;}
});
export const cleanupQuestionReservations = onSchedule({schedule: 'every 10 minutes', region: 'europe-west1', maxInstances: 1}, async () => {
  try {return await service.cleanup();}
  catch(error){await reportFailure(error,'cleanupQuestionReservations');throw error;}
});

const generationKey=defineSecret('OPENAI_API_KEY');
const generationSources=JSON.parse(readFileSync(new URL('../content/source_queue.json',import.meta.url)));
export const generateDailyQuestions=onSchedule({schedule:'0 4 * * *',timeZone:'Europe/Istanbul',region:'europe-west1',
  retryCount:0,maxInstances:1,concurrency:1,timeoutSeconds:1800,memory:'512MiB',
  serviceAccount:`question-generator@${projectId}.iam.gserviceaccount.com`,secrets:[generationKey]},async event=>{
  // Emulator tests inject a mock provider into CloudQuestionGenerator directly.
  if(emulator)throw new Error('Scheduled paid generation is disabled in the emulator. Use injected mock-provider tests.');
  const job=new CloudQuestionGenerator({database:getDatabase(),projectId,
    bundledPool:pool,sources:generationSources,model:'gpt-6-luna',apiKey:()=>generationKey.value()});
  try {
    console.info('daily-question-generation',await job.run(event));
    if(job.failure)await reportFailure(job.failure,'generateDailyQuestions.provider');
  }
  catch(error) {await reportFailure(error,'generateDailyQuestions');console.error('daily-question-generation-failed');throw new Error('Daily generation failed; inspect private status.');}
});
