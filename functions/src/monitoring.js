import * as Sentry from '@sentry/node';

export function sanitizeEvent(event) {
  // SDK/global exceptions can contain provider response bodies or player input.
  const clean = {...event};
  for (const key of ['request','user','extra','breadcrumbs','transaction','server_name','logentry','message']) delete clean[key];
  clean.tags = Object.fromEntries(Object.entries(event.tags ?? {}).filter(([key]) =>
    ['operation','component','error_code'].includes(key)));
  if (event.exception?.values) clean.exception = {values:event.exception.values.map(value => ({
    type:value.type, value:clean.tags.error_code ?? 'Details omitted; inspect type and stack trace',
    mechanism:value.mechanism ? {type:value.mechanism.type,handled:value.mechanism.handled} : undefined,
    stacktrace:value.stacktrace ? {frames:value.stacktrace.frames?.map(frame => {
      const {vars,pre_context,post_context,context_line,...safe}=frame;
      return safe;
    })} : undefined,
  }))};
  if (clean.contexts) clean.contexts = Object.fromEntries(Object.entries(clean.contexts).filter(([key]) => ['runtime','os','trace'].includes(key)));
  delete clean.threads;
  return clean;
}

const projectId = process.env.GCLOUD_PROJECT;
const dsn = process.env.SENTRY_DSN;
Sentry.init({
  dsn,
  enabled: Boolean(dsn) && ['kelime-yarisi-yalin','kelime-yarisi-prod'].includes(projectId),
  environment: projectId === 'kelime-yarisi-prod' ? 'prod' : 'dev',
  release: process.env.K_REVISION,
  sendDefaultPii:false,
  sampleRate:1,
  enableOpenTelemetrySetup:false,
  dataCollection:{userInfo:false,cookies:false,httpHeaders:false,httpBodies:[],urlQueryParams:false,
    graphQL:{document:false,variables:false},genAI:{inputs:false,outputs:false},
    databaseQueryData:false,queues:false,stackFrameVariables:false,frameContextLines:0},
  enableLogs:false,
  maxBreadcrumbs:0,
  beforeBreadcrumb:()=>null,
  beforeSend:sanitizeEvent,
  // Do not hook console output or collect request/response data from OpenAI/Firebase.
  integrations: defaults => defaults.filter(integration =>
    !['Console','Http','NodeFetch','RequestData','ContextLines','LocalVariables'].includes(integration.name)),
});

const recentFailures=new Map();

export async function reportFailure(error, operation, {expected=false}={}) {
  try {
    const type=error instanceof Error ? error.name : 'NonErrorFailure';
    const code=typeof error?.code==='string' && /^[a-z\d_/-]{1,80}$/iu.test(error.code) ? error.code : undefined;
    const key=`${operation}:${type}:${code}`;
    const now=Date.now();
    for(const [entry,time] of recentFailures)if(now-time>=60000)recentFailures.delete(entry);
    if(recentFailures.has(key))return;
    if(recentFailures.size>=100)recentFailures.delete(recentFailures.keys().next().value);
    recentFailures.set(key,now);
    await Sentry.withIsolationScope(async scope => {
      scope.setTags({operation,component:'functions',...(code?{error_code:code}:{})});
      scope.setLevel(expected?'warning':'error');
      const safe=new Error(type);
      safe.name=type;
      // Preserve source locations without copying the raw message (first line).
      if(typeof error?.stack==='string') safe.stack=`${type}\n${error.stack.split('\n').slice(1).filter(line=>/^\s+at /u.test(line)).join('\n')}`;
      Sentry.captureException(safe);
      // Cloud Functions may freeze the instance immediately after a response.
      await Sentry.flush(2000);
    });
  } catch {
    // A telemetry outage must not change the original result/error.
  }
}
