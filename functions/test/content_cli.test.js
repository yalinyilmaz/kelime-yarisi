import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';

test('draft → manual source entry → explicit review → production artifact; missing approval cannot publish', () => {
  const dir = mkdtempSync(join(tmpdir(),'kelime-content-'));
  const file = join(dir,'drafts.json'), output = join(dir,'published.json');
  writeFileSync(file,'[]');
  const run = args => spawnSync(process.execPath,[new URL('../tools/content.js',import.meta.url).pathname,...args,'--file',file],{encoding:'utf8'});
  try {
    assert.equal(run(['draft','--answer','o\u0308rdek','--id','bird']).status,0);
    const q=JSON.parse(readFileSync(file))[0];
    assert.equal(q.answer,'ÖRDEK');assert.equal(q.letterCount,5);
    assert.notEqual(run(['validate']).status,0);
    Object.assign(q,{meaning:'Test meaning',clue:'Perdeli ayaklı su kuşu.',topic:'doğa',source:{rights:'original',reference:'Test fixture source',meaningEvidence:'Test-only meaning evidence',termsReference:'Project-authored test'}});
    writeFileSync(file,JSON.stringify([q]));
    const checks='spelling,meaning,uniqueAnswer,noLeak,originality,sourceRights';
    assert.notEqual(run(['review','--id','bird','--checks',checks]).status,0);
    assert.equal(run(['publish','--out',output]).status,0);
    assert.deepEqual(JSON.parse(readFileSync(output)),[]);
    assert.equal(run(['review','--id','bird','--checks',checks,'--editor','test-editor']).status,0);
    assert.equal(run(['publish','--out',output]).status,0);
    assert.equal(JSON.parse(readFileSync(output)).length,1);
    const reviewed=JSON.parse(readFileSync(file))[0];reviewed.clue='Changed text';writeFileSync(file,JSON.stringify([reviewed]));
    assert.notEqual(run(['publish','--out',output]).status,0);
  } finally {rmSync(dir,{recursive:true,force:true});}
});
