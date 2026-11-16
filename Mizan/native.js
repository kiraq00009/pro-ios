/* جسر ميزان ↔ الآيفون: مشاركة الملفّات، الطباعة/PDF، نسخة احتياطيّة على الجهاز، المزامنة، وصور الشاشات */
(function () {
  'use strict';
  var H = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mz;
  if (!H) return;
  document.documentElement.classList.add('ios-app');
  var st = document.createElement('style');
  st.textContent = 'html,body{-webkit-tap-highlight-color:transparent;-webkit-touch-callout:none;overscroll-behavior:none}';
  document.head.appendChild(st);

  // ملفّات: CSV / نسخة احتياطيّة ⇒ ورقة المشاركة بالآيفون (حفظ بالملفّات، واتساب، بريد…)
  window.Files.download = function (name, text, type) { H.postMessage({ op: 'share', name: String(name), text: String(text), type: String(type || '') }); };
  window.Files.backup = function () {
    var b = window.Store.book; if (!b) return;
    window.Files.download('ميزان-' + b.meta.name + '-' + window.Engine.today() + '.json', JSON.stringify(b), 'application/json');
    b.meta.backupAt = Date.now(); window.Store.save(true);
  };
  // الطباعة ⇒ نافذة الطباعة بالآيفون (طابعة أو حفظ PDF)
  window.print = function () { H.postMessage({ op: 'print', title: document.title }); };

  // نسخة من كلّ الدفاتر بملفّ داخل التطبيق — ترجع لحالها إذا انمسح تخزين المتصفّح
  var t = null;
  function snap() {
    try {
      var o = {};
      for (var i = 0; i < localStorage.length; i++) { var k = localStorage.key(i); if (k && k.indexOf('mizan.') === 0) o[k] = localStorage.getItem(k); }
      H.postMessage({ op: 'snap', data: JSON.stringify(o) });
    } catch (e) {}
  }
  function later() { clearTimeout(t); t = setTimeout(snap, 700); }
  ['save', 'savePrefs', 'removeBook', 'create', 'rename'].forEach(function (m) {
    var f = window.Store[m]; if (typeof f !== 'function') return;
    window.Store[m] = function () { var r = f.apply(this, arguments); later(); return r; };
  });
  if (window.Sync && typeof window.Sync.apply === 'function') {
    var ap = window.Sync.apply; window.Sync.apply = function () { var r = ap.apply(this, arguments); later(); return r; };
  }
  document.addEventListener('visibilitychange', function () { if (document.hidden) snap(); });
  window.MZ_SNAP = snap;
  setTimeout(snap, 2500);

  // المزامنة تروح لسيرفر دورلي مباشرة
  if (window.Sync) window.Sync.api = 'https://dawwirli.watch/mizan/api/';

  // وضع صور الشاشات (CI)
  var shot = window.MZ_SHOT;
  if (shot) {
    setTimeout(function () {
      try {
        if (!window.Store.book) { window.Demo.make(); window.App.boot(); }
        var m = { dash: '#/', accounts: '#/accounts', debts: '#/debts', trips: '#/trips', reports: '#/reports', journal: '#/journal', more: '#/more', diag: '#/' };
        if (m[shot]) location.hash = m[shot];
        if (shot === 'diag') setTimeout(diag, 400);
      } catch (e) { document.body.insertAdjacentHTML('afterbegin', '<pre style="position:fixed;top:60px;left:0;right:0;z-index:999;background:#fee;color:#900;padding:10px">' + e + '</pre>'); }
    }, 350);
  }
  function diag() {
    var ls = false; try { localStorage.setItem('mz.t', '1'); ls = localStorage.getItem('mz.t') === '1'; } catch (e) {}
    var rows = [['isSecureContext', window.isSecureContext], ['crypto.subtle', !!(window.crypto && crypto.subtle)], ['localStorage', ls],
      ['font', document.fonts ? document.fonts.check('16px "IBM Plex Sans Arabic"') : 'n/a'], ['origin', location.origin], ['books', window.Store.books().length]];
    var h = '<div style="position:fixed;top:90px;left:16px;right:16px;z-index:999;background:#111;color:#fff;font:15px/1.8 monospace;padding:14px;border-radius:14px;direction:ltr">' +
      rows.map(function (r) { return r[0] + ': <b style="color:' + (r[1] === false ? '#f66' : '#6f6') + '">' + r[1] + '</b>'; }).join('<br>') + '</div>';
    document.body.insertAdjacentHTML('beforeend', h);
  }
})();
