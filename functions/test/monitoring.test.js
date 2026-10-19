import test from 'node:test';
import assert from 'node:assert/strict';
import * as Sentry from '@sentry/node';
import {sanitizeEvent, reportFailure} from '../src/monitoring.js';

test('backend scrubs credentials and request payloads, retaining stack location and handling status', () => {
  const event={user:{id:'private-user'},request:{data:'private-answer'},extra:{key:'private-token'},
    breadcrumbs:[{message:'private-crumb'}],message:'private-body',server_name:'private-host',
    tags:{operation:'playRace',error_code:'unavailable',roomId:'private-room'},
    contexts:{runtime:{name:'node'},custom:{token:'private-token'}},
    exception:{values:[{type:'Error',value:'private-provider-body',mechanism:{handled:false},
      stacktrace:{frames:[{filename:'race.js',lineno:12,vars:{token:'private-token'},context_line:'private-source'}]}}]}};
  const clean=sanitizeEvent(event);
  assert.doesNotMatch(JSON.stringify(clean),/private-/u);
  assert.equal(clean.exception.values[0].stacktrace.frames[0].lineno,12);
  assert.equal(clean.exception.values[0].mechanism.handled,false);
  assert.equal(clean.tags.operation,'playRace');
  assert.equal(event.exception.values[0].value,'private-provider-body');
});

test('serverless reporter flushes a sanitized, isolated event without changing caller state', async () => {
  const envelopes=[];
  await Sentry.close();
  Sentry.init({dsn:'https://12345678901234567890123456789012@localhost/1',defaultIntegrations:false,
    beforeSend:sanitizeEvent,transport:()=>({send:async envelope=>{envelopes.push(envelope);return {statusCode:200};},flush:async()=>true})});
  try {
    const failure=new Error('private-provider-body');failure.code='unavailable';
    await reportFailure(failure,'test.backend');
    const data=JSON.stringify(envelopes);
    assert.equal(envelopes.length,1);
    assert.match(data,/test.backend/u);
    assert.match(data,/monitoring.test.js/u);
    assert.doesNotMatch(data,/private-provider-body/u);
    assert.equal(Sentry.getIsolationScope().getScopeData().tags.operation,undefined);
  } finally {await Sentry.close();}
});
