/* ميزان — التشغيل، التنقّل، القفل، البيانات التجريبيّة */
(function () {
  'use strict';
  const E = window.Engine, U = window.UI, S = window.Store, V = window.Views;
  const { $, esc, ic } = U;

  const NAV = [
    ['dash', '#/', 'home', 'الخلاصة'], ['accounts', '#/accounts', 'users', 'الحسابات'], ['debts', '#/debts', 'coins', 'ديوني'], ['trips', '#/trips', 'plane', 'مصاريف السفر'],
    ['journal', '#/journal', 'list', 'القيود'], ['reports', '#/reports', 'chart', 'التقارير'], ['chart', '#/chart', 'tree', 'دليل الحسابات'], ['settings', '#/settings', 'gear', 'الإعدادات'],
  ];
  const ROUTES = {
    '': 'dash', accounts: 'accounts', acc: 'acc', chart: 'chart', journal: 'journal', new: 'newEntry', edit: 'newEntry', reports: 'reports', report: 'report',
    settings: 'settings', debts: 'debts', trips: 'trips', trip: 'trip', more: 'more',
  };

  const App = {
    route() { const h = location.hash.replace(/^#\/?/, ''); const parts = h.split('/').filter(Boolean).map(decodeURIComponent); return { name: parts[0] || '', args: parts.slice(1) }; },
    render() {
      if (!S.book) return first();
      const r = this.route();
      const view = ROUTES[r.name] || 'dash';
      const main = $('#main');
      const el = document.createElement('div');
      main.innerHTML = ''; main.appendChild(el);
      const args = r.args.slice();
      if (r.name === 'edit') args.edit = r.args[0];
      try { (V[view] || V.dash)(el, args); } catch (err) { console.error(err); el.innerHTML = '<div class="card"><div class="empty"><b>صار خطأ بهذي الشاشة</b>' + esc(err.message) + '<br><a href="#/">رجوع للخلاصة</a></div></div>'; }
      this.chrome(view);
      if (!this._keepScroll) window.scrollTo(0, 0);
      this._keepScroll = false;
    },
    chrome(view) {
      const b = S.book; if (!b) return;
      view = view || ROUTES[this.route().name] || 'dash';
      const act = (k) => (k === view || (k === 'accounts' && (view === 'acc')) || (k === 'trips' && view === 'trip') || (k === 'reports' && view === 'report') || (k === 'journal' && (view === 'newEntry')) ? ' on' : '');
      const d = E.debts(b);
      $('#side').innerHTML = `<div class="brand"><span class="logo">${ic('scale')}</span><b>ميزان</b></div>
        <button class="bookbtn" data-books><span><small>الدفتر</small>${esc(b.meta.name)}</span>${ic('chev')}</button>
        <a class="btn pri block newbtn" href="#/new">${ic('plus')} سند جديد</a>
        <nav class="nav">${NAV.map(([k, h, i, n], idx) => (idx === 6 ? '<div class="sep"></div>' : '') + '<a href="' + h + '" class="' + act(k) + '">' + ic(i) + '<span class="grow">' + n + '</span>' + (k === 'debts' && d.overdue ? '<span class="pill neg">!</span>' : '') + '</a>').join('')}</nav>
        <div class="grow"></div><div class="hint" style="padding:10px 8px">${b.entries.length} قيد · ${S.prefs.sync && S.prefs.sync.on ? '☁︎ متزامن' : 'محفوظ بهذا الجهاز'}</div>`;
      $('#tabs').innerHTML = [['dash', '#/', 'home', 'الخلاصة'], ['accounts', '#/accounts', 'users', 'الحسابات'], ['new', '#/new', 'plus', 'سند'], ['debts', '#/debts', 'coins', 'ديوني'], ['more', '#/more', 'more', 'المزيد']]
        .map(([k, h, i, n]) => k === 'new' ? '<a href="' + h + '" class="plus"><span class="o">' + ic(i) + '</span></a>' : '<a href="' + h + '" class="' + (act(k) || (k === 'more' && ['journal', 'reports', 'report', 'chart', 'settings', 'trips', 'trip', 'more'].includes(view) ? ' on' : '')) + '">' + ic(i) + n + '</a>').join('');
      $('[data-books]', $('#side')).onclick = () => booksMenu();
      document.title = 'ميزان — ' + b.meta.name;
    },
    theme() { const t = S.prefs.theme; if (t === 'auto') document.documentElement.removeAttribute('data-theme'); else document.documentElement.setAttribute('data-theme', t); },
    async hash(s) { const h = await crypto.subtle.digest('SHA-256', new TextEncoder().encode('mizan:' + s)); return Array.from(new Uint8Array(h), (x) => x.toString(16).padStart(2, '0')).join(''); },
    boot() { if (!S.book) S.boot(); location.hash = '#/'; this.render(); },
  };
  window.App = App;

  // ——— «المزيد» على الموبايل ———
  V.more = function (el) {
    const b = S.book;
    el.innerHTML = '<div class="ph"><div><h1>المزيد</h1><div class="sub">' + esc(b.meta.name) + '</div></div></div><div class="rep-grid">' +
      [['#/trips', 'plane', 'مصاريف السفر', 'رحلات وميزانيّاتها'], ['#/journal', 'list', 'القيود', 'دفتر اليوميّة'], ['#/reports', 'chart', 'التقارير', 'ميزان، دخل، ميزانيّة…'], ['#/chart', 'tree', 'دليل الحسابات', 'الشجرة الكاملة'], ['#/settings', 'gear', 'الإعدادات', 'دفاتر، عملات، نسخ، مزامنة']]
        .map(([h, i, n, d]) => '<div class="card rep" data-go="' + h + '"><span class="av">' + ic(i) + '</span><div><b>' + n + '</b><span>' + d + '</span></div></div>').join('') +
      '<div class="card rep" data-books><span class="av">' + ic('book') + '</span><div><b>تبديل الدفتر</b><span>' + S.books().length + ' دفتر</span></div></div></div>';
    V.bindCommon(el);
    $('[data-books]', el).onclick = booksMenu;
  };

  function booksMenu() {
    const list = S.books();
    U.modal({ title: 'الدفاتر', foot: false, body: '<div class="list">' + list.map((x) => '<div class="li" data-id="' + x.id + '"><span class="av" style="background:var(--accbg);color:var(--acc2)">' + ic('book') + '</span><div class="grow"><div class="t">' + esc(x.name) + '</div><div class="s">' + (x.entries || 0) + ' قيد · ' + x.base + '</div></div>' + (x.id === S.book.id ? ic('check') : '') + '</div>').join('') + '</div><button class="btn block" data-new style="margin-top:10px">' + ic('plus') + ' دفتر جديد</button>',
      onMount: (ov, close) => {
        ov.querySelector('.list').onclick = (e) => { const li = e.target.closest('[data-id]'); if (!li) return; close(); if (li.dataset.id !== S.book.id) { S.open(li.dataset.id); App.boot(); U.toast('انفتح «' + S.book.meta.name + '»'); } };
        $('[data-new]', ov).onclick = () => { close(); V.newBook(); };
      } });
  }

  // ——— أوّل تشغيل ———
  function first() {
    $('#side').innerHTML = ''; $('#tabs').innerHTML = '';
    $('#main').innerHTML = `<div class="welcome"><span class="av" style="width:58px;height:58px;border-radius:17px;background:var(--acc);color:#fff">${ic('scale')}</span>
      <h1>ميزان</h1><p class="hint" style="font-size:15.5px">محاسبة كاملة بالقيد المزدوج بكلام بسيط: حسابات بلا حدود، لكلّ حساب كشف جاري ومصاريف، ديونك، مصاريف السفر، وكلّ التقارير الماليّة.</p>
      <div class="card"><div class="form"><label class="f">اسم الدفتر<input class="in" id="fbn" placeholder="مثلًا: شركتي، حساباتي الشخصيّة"></label>
        <label class="f">العملة الأساسيّة<select class="in" id="fbc"><option value="IQD">دينار عراقيّ (IQD)</option><option value="USD">دولار (USD)</option><option value="EUR">يورو (EUR)</option></select></label>
        <div class="row"><button class="btn pri" id="fbgo">${ic('check')} ابدأ</button><button class="btn ghost" id="fbdemo">${ic('bolt')} جرّب ببيانات تجريبيّة</button><label class="btn ghost">${ic('up')} عندي نسخة<input type="file" accept=".json" id="fbrest" hidden></label></div></div></div>
      <p class="hint" style="margin-top:14px">${ic('lock').replace('<svg', '<svg style="display:inline;width:14px;vertical-align:-2px"')} بياناتك تنحفظ بجهازك فقط. المزامنة اختياريّة ومشفّرة.</p></div>`;
    $('#fbgo').onclick = () => { S.create($('#fbn').value.trim() || 'دفتري', $('#fbc').value); App.boot(); };
    $('#fbdemo').onclick = () => { window.Demo.make(); App.boot(); };
    $('#fbrest').onchange = async (e) => { try { S.importBook(JSON.parse(await e.target.files[0].text())); App.boot(); } catch (err) { U.toast('ملفّ غير صالح', true); } };
  }

  // ——— القفل ———
  function lock() {
    return new Promise((res) => {
      if (!S.prefs.pin) return res();
      const w = document.createElement('div'); w.className = 'lock';
      let v = '';
      const draw = () => { w.innerHTML = '<div class="box"><span class="av" style="width:54px;height:54px;border-radius:16px;background:var(--acc);color:#fff;margin:auto">' + ic('lock') + '</span><h2 style="margin:12px 0 0">ميزان</h2><div class="pin">' + [0, 1, 2, 3].map((i) => '<i class="' + (i < v.length ? 'f' : '') + '"></i>').join('') + (v.length > 4 ? '<i class="f"></i>'.repeat(v.length - 4) : '') + '</div><div class="pad">' + [1, 2, 3, 4, 5, 6, 7, 8, 9, '⌫', 0, '✓'].map((k) => '<button data-k="' + k + '">' + k + '</button>').join('') + '</div></div>'; };
      const tryIt = async () => { if ((await App.hash(v)) === S.prefs.pin) { w.remove(); document.removeEventListener('keydown', kd); res(); } else if (v.length >= 4) { v = ''; draw(); w.querySelector('.pin').animate([{ transform: 'translateX(-8px)' }, { transform: 'translateX(8px)' }, { transform: 'none' }], 260); } };
      const press = (k) => { if (k === '⌫') v = v.slice(0, -1); else if (k === '✓') return tryIt(); else if (v.length < 8) v += k; draw(); if (v.length >= 4) tryIt(); };
      const kd = (e) => { if (/^\d$/.test(e.key)) press(e.key); else if (e.key === 'Backspace') press('⌫'); else if (e.key === 'Enter') press('✓'); };
      w.onclick = (e) => { const b = e.target.closest('[data-k]'); if (b) press(b.dataset.k); };
      document.addEventListener('keydown', kd);
      draw(); document.body.appendChild(w);
    });
  }

  // ——— بيانات تجريبيّة ———
  window.Demo = {
    make() {
      const b = S.create('دفتر تجريبيّ', 'IQD');
      const A = (o) => E.addAccount(b, o);
      const box = E.acc(b, 'a1101');
      const usd = A({ name: 'صندوق الدولار', sub: 'cash', cur: 'USD' });
      const bank = A({ name: 'المصرف', sub: 'bank' });
      const c1 = A({ name: 'مؤسّسة النخيل', sub: 'customer', phone: '07701234567', limit: 5_000_000 });
      const c2 = A({ name: 'سعد كريم', sub: 'customer' });
      const s1 = A({ name: 'شركة المواد الإنشائيّة', sub: 'supplier' });
      const s2 = A({ name: 'معرض الكهربائيّات', sub: 'supplier' });
      const p1 = A({ name: 'الشريك الأوّل', sub: 'partner', share: 60 });
      const p2 = A({ name: 'الشريك الثاني', sub: 'partner', share: 40 });
      const emp = A({ name: 'حسين (موظّف)', sub: 'employee' });
      const prj1 = A({ name: 'مشروع عمارة الجادريّة', sub: 'project' });
      const prj2 = A({ name: 'مشروع ترميم المحلّ', sub: 'project' });
      const fr = A({ name: 'مصطفى', sub: 'person', phone: '07801112233' });
      const fr2 = A({ name: 'أبو علي', sub: 'person' });
      const trip = A({ name: 'سفرة إسطنبول', sub: 'trip', cur: 'USD', budget: 2500, place: 'إسطنبول', people: 2 });
      const V2 = (v) => { try { E.voucher(b, v); } catch (e) { console.warn(e.message, v); } };
      const now = new Date(); const day = (back) => { const d = new Date(now); d.setDate(d.getDate() - back); return U.iso(d); };
      V2({ kind: 'opening', date: day(200), account: box.id, amount: 25_000_000 });
      V2({ kind: 'opening', date: day(200), account: usd.id, amount: 6000, cur: 'USD', rate: 1500 });
      V2({ kind: 'opening', date: day(200), account: bank.id, amount: 40_000_000 });
      V2({ kind: 'opening', date: day(200), account: c2.id, amount: 1_200_000, memo: 'دين قديم' });
      const cats = ['a5101', 'a5102', 'a5103', 'a5104', 'a5105', 'a5106', 'a5107', 'a5109'];
      let seed = 7; const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
      for (let m = 6; m >= 0; m--) {
        const base = m * 30;
        V2({ kind: 'expense', date: day(base + 25), cat: 'a5101', from: bank.id, amount: 1_500_000, memo: 'إيجار المكتب' });
        V2({ kind: 'expense', date: day(base + 24), cat: 'a5102', from: box.id, amount: 2_000_000, cc: rnd() > 0.5 ? prj1.id : '', memo: 'رواتب' });
        V2({ kind: 'sale', date: day(base + 20), account: c1.id, cat: 'a4101', amount: Math.round(3 + rnd() * 6) * 1_000_000, cc: prj1.id, memo: 'مستخلص مشروع الجادريّة' });
        V2({ kind: 'receipt', date: day(base + 10), account: c1.id, to: bank.id, amount: Math.round(3 + rnd() * 4) * 1_000_000, ref: 'ص' + (100 + m) });
        V2({ kind: 'purchase', date: day(base + 18), account: s1.id, cat: 'a5106', amount: Math.round(1 + rnd() * 3) * 1_000_000, cc: prj1.id, memo: 'مواد بناء' });
        V2({ kind: 'payment', date: day(base + 5), account: s1.id, from: bank.id, amount: 1_500_000 });
        V2({ kind: 'income', date: day(base + 12), cat: 'a4102', to: box.id, amount: Math.round(5 + rnd() * 10) * 100_000, cc: prj2.id, memo: 'أعمال ترميم' });
        for (let i = 0; i < 4; i++) V2({ kind: 'expense', date: day(base + Math.floor(rnd() * 28)), cat: cats[2 + Math.floor(rnd() * 6)], from: box.id, amount: Math.round(2 + rnd() * 20) * 25_000, cc: rnd() > 0.55 ? (rnd() > 0.5 ? prj1.id : prj2.id) : '' });
      }
      V2({ kind: 'purchase', date: day(40), account: s2.id, cat: 'a5106', amount: 2_750_000, cc: prj2.id, memo: 'تأسيسات كهرباء' });
      V2({ kind: 'payment', date: day(33), account: emp.id, from: box.id, amount: 500_000, memo: 'سلفة حسين', due: day(-20) });
      V2({ kind: 'expense', date: day(15), cat: 'a5104', from: box.id, amount: 90_000, cc: c2.id, onParty: true, memo: 'نقل بضاعة على حساب سعد' });
      V2({ kind: 'payment', date: day(70), account: fr.id, from: box.id, amount: 750_000, memo: 'سلفة لمصطفى', due: day(10) });
      V2({ kind: 'receipt', date: day(30), account: fr.id, to: box.id, amount: 250_000 });
      V2({ kind: 'receipt', date: day(20), account: fr2.id, to: usd.id, amount: 400, cur: 'USD', memo: 'استلفت من أبو علي', due: day(-25) });
      V2({ kind: 'transfer', date: day(60), from: usd.id, to: box.id, amount: 1000, toAmount: 1_480_000, memo: 'صرف دولار' });
      V2({ kind: 'payment', date: day(45), account: p1.id, from: box.id, amount: 1_000_000, memo: 'مسحوبات شخصيّة' });
      // الرحلة
      V2({ kind: 'expense', date: day(16), cat: 'a5201', from: bank.id, amount: 1_350_000, cc: trip.id, memo: 'تذاكر طيران' });
      V2({ kind: 'transfer', date: day(13), from: usd.id, to: trip.id, amount: 1800, memo: 'فلوس السفرة' });
      [[12, 'a5202', 420, 'فندق ٣ ليالي'], [12, 'a5204', 35, 'تكسي المطار'], [11, 'a5203', 62, 'عشاء'], [11, 'a5207', 80, 'رحلة البوسفور'], [10, 'a5205', 210, 'هدايا'], [10, 'a5203', 48, 'غداء'], [9, 'a5204', 25, 'مترو وتكاسي'], [9, 'a5208', 15, 'شريحة إنترنت']]
        .forEach(([d, c, a, m]) => V2({ kind: 'expense', date: day(d), cat: c, from: trip.id, cc: trip.id, amount: a, cur: 'USD', memo: m }));
      Object.assign(trip, { start: day(12), end: day(9) });
      S.save();
      return b;
    },
  };

  // ——— تشغيل ———
  window.addEventListener('hashchange', () => App.render());
  S.listeners.push(() => App.chrome());
  App.theme();
  if (matchMedia) matchMedia('(prefers-color-scheme: dark)').addEventListener && matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => App.theme());
  S.boot();
  lock().then(async () => {
    App.render();
    if (S.prefs.sync && S.prefs.sync.on) {
      try { const r = await window.Sync.pull(); if (r) { if (!S.dirty || (await U.confirm('أكو نسخة أحدث من جهاز ثاني. أسحبها؟', 'اسحب'))) { window.Sync.apply(r); App.render(); U.toast('انسحبت آخر نسخة'); } } } catch (e) { /* بلا نت */ }
    }
  });
  window.addEventListener('beforeunload', () => { if (S.prefs.sync && S.prefs.sync.on && S.dirty) window.Sync.push().catch(() => {}); });
  if ('serviceWorker' in navigator && location.protocol === 'https:') navigator.serviceWorker.register('sw.js').catch(() => {});
})();
