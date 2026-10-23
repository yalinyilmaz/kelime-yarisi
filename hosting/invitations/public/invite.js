(() => {
  'use strict';
  const config = window.invitationConfig || {};
  const element = (id) => document.getElementById(id);
  let match;
  try {
    match = /^\/invite\/([a-z0-9]{3})-?([a-z0-9]{3})\/?$/i.exec(decodeURIComponent(window.location.pathname));
  } catch (_) { /* Malformed escape sequences are invalid invitations. */ }
  if (!match) {
    element('title').textContent = 'Davet bağlantısını kontrol et';
    element('message').textContent = 'Bu bağlantıda geçerli bir oda kodu bulunamadı. Arkadaşından daveti tekrar paylaşmasını iste.';
    return;
  }
  const code = `${match[1]}-${match[2]}`.toUpperCase();
  element('code').textContent = code;
  element('invitation').hidden = false;
  element('copy').addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(code);
      element('copied').textContent = 'Oda kodu kopyalandı.';
    } catch (_) {
      element('copied').textContent = 'Kopyalanamadı. Yukarıdaki kodu uygulamaya yazabilirsin.';
    }
  });
  function storeLink(id, value, allowedHosts) {
    if (!value) return null;
    try {
      const url = new URL(value);
      if (url.protocol !== 'https:' || !allowedHosts.includes(url.hostname)) return null;
      element(id).href = url.href;
      element(id).hidden = false;
      return url.href;
    } catch (_) { return null; }
  }
  const android = storeLink('android', config.androidStoreUrl, ['play.google.com']);
  const ios = storeLink('ios', config.iosStoreUrl, ['apps.apple.com']);
  const agent = navigator.userAgent;
  const isApple = /iPhone|iPad|iPod/i.test(agent) || (/Macintosh/i.test(agent) && navigator.maxTouchPoints > 1);
  const target = /Android/i.test(agent) ? android : isApple ? ios : null;
  // App/Universal Links are handled by the OS before this fallback page loads.
  if (target) window.location.replace(target);
})();
