import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';
const directory = new URL('../hosting/invitations/public/', import.meta.url);
const configScript = fs.readFileSync(new URL('config.js', directory), 'utf8');
const script = fs.readFileSync(new URL('invite.js', directory), 'utf8');
function landing(pathname, userAgent = 'Desktop', maxTouchPoints = 0) {
 const elements = new Map();
 let redirectedTo;
 const window = {location:{pathname, replace:value => redirectedTo=value}};
 const context = vm.createContext({window, URL, navigator:{userAgent,maxTouchPoints,clipboard:{writeText:async()=>{}}},document:{getElementById(id){
  if(!elements.has(id)) elements.set(id,{hidden:true,addEventListener(){}});
  return elements.get(id);
 }}});
 vm.runInContext(configScript, context);
 vm.runInContext(script, context);
 return {elements,redirectedTo};
}
test('desktop landing exposes full invitation and configured stores without redirect', () => {
 const result=landing('/invite/abc234');
 assert.equal(result.elements.get('code').textContent, 'ABC-234');
 assert.equal(result.elements.get('invitation').hidden, false);
 assert.equal(result.elements.get('android').href, 'https://play.google.com/apps/internaltest/4700389131999758394');
 assert.equal(result.elements.get('ios').href, 'https://apps.apple.com/');
 assert.equal(result.redirectedTo, undefined);
});
test('mobile fallbacks choose Android test or Apple App Store including iPad desktop UA', () => {
 assert.equal(landing('/invite/ABC-234','Android').redirectedTo, 'https://play.google.com/apps/internaltest/4700389131999758394');
 assert.equal(landing('/invite/ABC-234','iPhone').redirectedTo, 'https://apps.apple.com/');
 assert.equal(landing('/invite/ABC-234','Macintosh',5).redirectedTo, 'https://apps.apple.com/');
});
test('malformed, overlong and injected invitations never redirect', () => {
 for(const path of ['/', '/invite/ABC', '/invite/ABC2347', '/invite/%3Csvg%3E', '/invite/ABC-234/extra', '/invite/%ZZ']) {
  const result=landing(path,'Android');
  assert.equal(result.redirectedTo,undefined);
  assert.equal(result.elements.get('title').textContent,'Davet bağlantısını kontrol et');
 }
});
test('public associations are dev only and production destinations remain blank', () => {
 const android=JSON.parse(fs.readFileSync(new URL('.well-known/assetlinks.json',directory)));
 assert.equal(android[0].target.package_name,'com.yalinyilmaz.kelime_yarisi.dev');
 assert.ok(android[0].target.sha256_cert_fingerprints.every(sha=>/^([A-F0-9]{2}:){31}[A-F0-9]{2}$/.test(sha)));
 const apple=JSON.parse(fs.readFileSync(new URL('.well-known/apple-app-site-association',directory)));
 assert.deepEqual(apple.applinks.details[0].appIDs,['SMM9SXSRF9.com.yalinyilmaz.kelimeYarisi.dev']);
 const prod=JSON.parse(fs.readFileSync(new URL('../production.example.json',directory)));
 assert.deepEqual(Object.values(prod),['','','']);
});
