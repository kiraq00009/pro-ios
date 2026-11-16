/* ميزان — اللوحة، الحسابات، صفحة الحساب، دليل الحسابات */
(function () {
  'use strict';
  const E = window.Engine, U = window.UI;
  const { $, $$, esc, ic, av, M, BAL } = U;
  const B = () => window.Store.book;
  const V = (window.Views = window.Views || {});
  const save = () => window.Store.save();
  const go = (h) => (location.hash = h);

  const SUB_TABS = [
    ['all', 'الكلّ', null], ['person', 'أشخاص (ديون)', ['person']], ['customer', 'زبائن', ['customer']], ['supplier', 'موردين', ['supplier']], ['partner', 'شركاء', ['partner']],
    ['employee', 'موظّفين', ['employee']], ['project', 'مشاريع', ['project']], ['cash', 'صناديق ومصارف', ['cash', 'bank']],
    ['trip', 'رحلات', ['trip']], ['loan', 'قروض', ['loan']], ['asset', 'أصول', ['asset']], ['expense', 'أنواع المصاريف', ['expense']], ['revenue', 'أنواع الإيرادات', ['revenue']],
  ];
  const PARTY_SUBS = ['person', 'trip', 'customer', 'supplier', 'partner', 'employee', 'project', 'cash', 'bank', 'loan', 'asset', 'general'];

  // ———————————— اللوحة ————————————
  V.dash = function (el) {
    const b = B();
    if (!b.entries.length) return V.welcome(el);
    const d = E.dashboard(b);
    const base = b.meta.base;
    const mNet = d.month.net;
    const moneyOf = (n) => M(n, base);
    el.innerHTML = `
      <div class="ph"><div><div class="sub">${esc(b.meta.name)} · ${new Date().toLocaleDateString('ar-IQ-u-nu-latn', { weekday: 'long', day: 'numeric', month: 'long' })}</div><h1>الخلاصة</h1></div>
        <div class="row noprint">${quick()}</div></div>
      <div class="stack">
        <div class="kpis">
          <div class="kpi hero" data-go="#/accounts/cash"><div class="l">الفلوس الموجودة (صناديق ومصارف)</div><div class="v">${moneyOf(d.cash)}</div><div class="d">${d.boxes.length} صندوق ومصرف</div></div>
          <div class="kpi" data-go="#/report/aging"><div class="l">لنا عند الناس</div><div class="v drc">${moneyOf(d.recv)}</div><div class="d">زبائن وسلف ومشاريع</div></div>
          <div class="kpi" data-go="#/report/aging/pay"><div class="l">علينا للناس</div><div class="v crc">${moneyOf(d.pay)}</div><div class="d">موردين وقروض</div></div>
          <div class="kpi" data-go="#/report/income"><div class="l">ربح هذا الشهر</div><div class="v ${mNet >= 0 ? 'pos' : 'neg'}">${moneyOf(mNet)}</div><div class="d">إيراد ${E.fmt(d.month.totalRev)} · مصروف ${E.fmt(d.month.totalExp)}</div></div>
        </div>
        <div class="cols">
          <div class="stack">
            <div class="card"><h3>آخر ١٢ شهر <small>ربح السنة: <b class="${d.year.net >= 0 ? 'pos' : 'neg'}">${E.fmt(d.year.net)}</b></small></h3>${U.barChart(d.trend)}</div>
            <div class="card"><h3>آخر الحركات <a href="#/journal" class="hint">الكلّ ←</a></h3>${entryList(d.recent)}</div>
          </div>
          <div class="stack">
            <div class="card"><h3>الصناديق والمصارف <a href="#/accounts/cash" class="hint">الكلّ ←</a></h3><div class="list">${d.boxes.map((x) => accRow(x)).join('') || '<div class="empty">ماكو</div>'}</div></div>
            <div class="card"><h3>مصاريف هذا الشهر <small class="num">${E.fmt(d.month.totalExp)}</small></h3>${U.hbars(d.topExp, d.month.totalExp)}</div>
            ${topParties()}
          </div>
        </div>
      </div>`;
    bindCommon(el);
  };

  function topParties() {
    const b = B();
    const rows = E.partyList(b, { sub: ['customer', 'supplier', 'partner', 'employee', 'project', 'loan'] }).filter((x) => Math.abs(x.base) > 0.005).sort((x, y) => Math.abs(y.base) - Math.abs(x.base)).slice(0, 6);
    if (!rows.length) return '';
    return '<div class="card"><h3>أكبر الأرصدة <a href="#/accounts" class="hint">الحسابات ←</a></h3><div class="list">' + rows.map(accRow).join('') + '</div></div>';
  }
  function quick() {
    return [['receipt', 'in', 'قبض'], ['payment', 'out', 'دفع'], ['expense', 'tag', 'مصروف']].map(([k, i, n]) => '<a class="btn sm" href="#/new/' + k + '">' + ic(i) + n + '</a>').join('') + '<a class="btn sm pri" href="#/new">' + ic('plus') + 'سند جديد</a>';
  }
  function accRow(x) {
    const a = x.a;
    return '<div class="li" data-acc="' + a.id + '">' + av(a) + '<div class="grow" style="min-width:0"><div class="t">' + esc(a.name) + '</div><div class="s">' + esc(E.SUBS[a.sub] ? E.SUBS[a.sub].name : '') +
      (x.last ? ' · آخر حركة ' + x.last : ' · بلا حركات') + (a.cur !== B().meta.base ? ' · ' + a.cur : '') + '</div></div><div class="amt">' + BAL(a, x.bal, a.cur) + '</div></div>';
  }
  /** قائمة قيود مختصرة */
  function entryList(list, ctx) {
    const b = B();
    if (!list.length) return '<div class="empty">ماكو حركات بعد</div>';
    return '<div class="list">' + list.map((e) => {
      const amt = E.amountOf(e);
      const names = [...new Set(e.lines.map((l) => (E.acc(b, l.a) || {}).name).filter(Boolean))].slice(0, 3).join(' ← ');
      return '<div class="li" data-e="' + e.id + '">' + kindAv(e.kind) + '<div class="grow" style="min-width:0"><div class="t">' + esc(e.memo || E.KINDS[e.kind]) + '</div><div class="s">#' + e.no + ' · ' + e.date + ' · ' + esc(names) + '</div></div><div class="amt"><b class="num">' + E.fmt(amt) + '</b><div class="s">' + E.KINDS[e.kind] + '</div></div></div>';
    }).join('') + '</div>';
    void ctx;
  }
  const KIND_LOOK = { receipt: ['in', 'pos'], payment: ['out', 'neg'], expense: ['tag', 'neg'], income: ['in', 'pos'], transfer: ['swap', 'acc'], sale: ['receipt', 'pos'], purchase: ['cart', 'neg'], opening: ['flag', 'acc'], journal: ['book', 'acc'], closing: ['lock', 'acc'], profit: ['pie', 'acc'], reverse: ['undo', 'warn'] };
  function kindAv(k) {
    const [i, c] = KIND_LOOK[k] || ['book', 'acc'];
    const col = { pos: ['var(--pos)', 'var(--posbg)'], neg: ['var(--neg)', 'var(--negbg)'], acc: ['var(--acc2)', 'var(--accbg)'], warn: ['var(--warn)', 'var(--warnbg)'] }[c];
    return '<span class="av" style="color:' + col[0] + ';background:' + col[1] + '">' + ic(i) + '</span>';
  }
  V.kindAv = kindAv; V.entryList = entryList; V.accRow = accRow;

  function bindCommon(el) {
    if (el._bound) return;
    el._bound = true;
    el.addEventListener('click', (e) => {
      if (e.defaultPrevented || e.target.closest('button[data-pay],button[data-wa],[data-addin]')) return;
      const g = e.target.closest('[data-go]'); if (g) return go(g.dataset.go);
      const a = e.target.closest('[data-acc]'); if (a && a.dataset.acc !== '—') return go('#/acc/' + a.dataset.acc);
      const en = e.target.closest('[data-e]'); if (en) return V.showEntry(en.dataset.e);
    });
  }
  V.bindCommon = bindCommon;

  // ———————————— الترحيب (دفتر فارغ) ————————————
  V.welcome = function (el) {
    const b = B();
    el.innerHTML = `<div class="welcome">
      <span class="av" style="width:54px;height:54px;border-radius:16px;background:var(--acc);color:#fff">${ic('scale')}</span>
      <h1>أهلًا بدفترك «${esc(b.meta.name)}»</h1>
      <p class="hint" style="font-size:15px">ميزان يسجّل كلّ حركة بالقيد المزدوج مثل المحاسبين، بس إنت تكتب بكلام بسيط: «قبضت من فلان»، «صرفت وقود على المشروع».</p>
      <div class="card"><div class="steps">
        <div><div><b>سجّل الموجود عندك هسّه</b><div class="hint">كم بالصندوق وبالمصرف، وكم لك عند الناس وكم عليك — رصيد افتتاحيّ.</div></div></div>
        <div><div><b>ضيف حساباتك</b><div class="hint">زبائن، موردين، شركاء، موظّفين، مشاريع… كلّ واحد إله كشف جاري ومصاريف.</div></div></div>
        <div><div><b>سجّل الحركات يوميًّا</b><div class="hint">قبض، دفع، مصروف، بيع آجل… والتقارير تطلع لحالها.</div></div></div>
      </div>
      <div class="row" style="margin-top:14px"><a class="btn pri" href="#/new/opening">${ic('flag')} أبدي بالرصيد الافتتاحيّ</a><button class="btn" data-add>${ic('plus')} حساب جديد</button><button class="btn ghost" data-demo>${ic('bolt')} جرّب ببيانات تجريبيّة</button></div></div>
    </div>`;
    $('[data-add]', el).onclick = async () => { const a = await V.accountForm(); if (a) go('#/acc/' + a.id); };
    $('[data-demo]', el).onclick = async () => {
      if (!(await U.confirm('أسوّي دفتر جديد اسمه «دفتر تجريبيّ» بيه حسابات وحركات وهميّة حتى تشوف البرنامج شلون يشتغل؟ دفترك الحاليّ يبقى مثل ما هو.', 'سوّي'))) return;
      window.Demo.make(); window.App.boot(); U.toast('انفتح الدفتر التجريبيّ');
    };
  };

  // ———————————— قائمة الحسابات ————————————
  const listState = { tab: 'all', q: '', sort: 'bal', arch: false };
  V.accounts = function (el, p) {
    const b = B();
    if (p[0]) listState.tab = p[0];
    const tab = SUB_TABS.find((t) => t[0] === listState.tab) || SUB_TABS[0];
    const subs = tab[2] || PARTY_SUBS;
    const all = E.partyList(b, { sub: subs, archived: listState.arch });
    const q = listState.q.trim();
    let rows = all.filter((x) => !q || x.a.name.includes(q) || x.a.code.startsWith(q) || (x.a.phone || '').includes(q));
    rows.sort(listState.sort === 'name' ? (x, y) => x.a.name.localeCompare(y.a.name, 'ar') : listState.sort === 'last' ? (x, y) => (y.last || '').localeCompare(x.last || '') : (x, y) => Math.abs(y.base) - Math.abs(x.base));
    const on = rows.filter((x) => x.base > 0.005 && !['expense', 'cash', 'bank'].includes(x.a.sub)).reduce((s, x) => s + x.base, 0);
    const off = rows.filter((x) => x.base < -0.005 && !['revenue'].includes(x.a.sub)).reduce((s, x) => s - x.base, 0);
    const counts = {}; E.partyList(b, {}).forEach((x) => (counts[x.a.sub] = (counts[x.a.sub] || 0) + 1));
    const cnt = (t) => (t[2] ? t[2].reduce((s, k) => s + (counts[k] || 0), 0) : Object.entries(counts).filter(([k]) => PARTY_SUBS.includes(k)).reduce((s, [, v]) => s + v, 0));
    el.innerHTML = `
      <div class="ph"><div><h1>الحسابات</h1><div class="sub">كلّ حساب إله كشف جاري ومصاريفه وتفاصيله</div></div>
        <div class="row"><a class="btn ghost" href="#/chart">${ic('tree')} دليل الحسابات</a><button class="btn pri" data-new>${ic('plus')} حساب جديد</button></div></div>
      <div class="stack">
        <div class="chips">${SUB_TABS.map((t) => '<button class="chip' + (t[0] === tab[0] ? ' on' : '') + '" data-tab="' + t[0] + '">' + t[1] + '<span class="c">' + cnt(t) + '</span></button>').join('')}</div>
        <div class="row"><input class="in grow" data-q placeholder="ابحث باسم أو رقم أو تلفون…" value="${esc(listState.q)}" style="min-width:180px">
          <select class="in" data-sort style="width:auto"><option value="bal">الأكبر رصيدًا</option><option value="last">آخر حركة</option><option value="name">الاسم</option></select>
          <label class="chk hint"><input type="checkbox" data-arch ${listState.arch ? 'checked' : ''}> المؤرشفة</label></div>
        ${['expense', 'revenue', 'cash'].includes(tab[0]) ? '' : `<div class="grid2 keep"><div class="kpi"><div class="l">مجموع اللي عليهم</div><div class="v drc">${M(on)}</div></div><div class="kpi"><div class="l">مجموع اللي إلهم</div><div class="v crc">${M(off)}</div></div></div>`}
        <div class="card" style="padding:6px 14px">${rows.length ? '<div class="list">' + rows.map((x) => accRow(x) + '').join('') + '</div>' : '<div class="empty"><b>ماكو حسابات هنا</b>اضغط «حساب جديد» وضيف أوّل واحد.</div>'}</div>
      </div>`;
    $('[data-sort]', el).value = listState.sort;
    $$('[data-tab]', el).forEach((c) => (c.onclick = () => { listState.tab = c.dataset.tab; go('#/accounts/' + c.dataset.tab); }));
    const qi = $('[data-q]', el);
    qi.oninput = () => { listState.q = qi.value; const pos = qi.selectionStart; V.accounts(el, []); const n = $('[data-q]', el); n.focus(); n.setSelectionRange(pos, pos); };
    $('[data-sort]', el).onchange = (e) => { listState.sort = e.target.value; V.accounts(el, []); };
    $('[data-arch]', el).onchange = (e) => { listState.arch = e.target.checked; V.accounts(el, []); };
    $('[data-new]', el).onclick = async () => { const sub = tab[2] ? tab[2][0] : 'customer'; const a = await V.accountForm(null, { sub }); if (a) go('#/acc/' + a.id); };
    bindCommon(el);
  };

  // ———————————— نموذج الحساب ————————————
  /** a: حساب للتعديل أو null؛ o: {name, sub, subs} ⇒ Promise بالحساب */
  V.accountForm = function (a, o) {
    o = o || {};
    const b = B();
    const isNew = !a;
    const sub0 = a ? a.sub : (o.sub || 'customer');
    const subs = o.subs || Object.keys(E.SUBS);
    const groupsFor = (sub) => { const t = E.SUBS[sub] ? E.SUBS[sub].type : 'asset'; return b.accounts.filter((g) => g.group && g.type === t); };
    const curOpts = b.currencies.map((c) => '<option value="' + c.code + '">' + esc(c.name) + ' (' + c.code + ')</option>').join('');
    return new Promise((res) => {
      let out = null;
      U.modal({
        title: isNew ? 'حساب جديد' : 'تعديل الحساب',
        body: `<div class="form">
          <label class="f">الاسم<input class="in" id="fn" value="${esc(a ? a.name : o.name || '')}" placeholder="مثلًا: أحمد علي، مشروع العمارة، صندوق المحلّ"></label>
          <label class="f">نوع الحساب<div class="chips" id="fsub" style="flex-wrap:wrap">${subs.map((k) => '<button type="button" class="chip' + (k === sub0 ? ' on' : '') + '" data-s="' + k + '"' + (a && E.isUsed(b, a.id) && E.SUBS[k].type !== a.type ? ' disabled style="opacity:.4"' : '') + '>' + E.SUBS[k].name + '</button>').join('')}</div></label>
          <div class="grid2">
            <label class="f">تحت مجموعة<select class="in" id="fp"></select></label>
            <label class="f">العملة<select class="in" id="fc" ${a && E.isUsed(b, a.id) ? 'disabled' : ''}>${curOpts}</select></label>
          </div>
          <div class="grid2">
            <label class="f">التلفون<input class="in" id="fph" inputmode="tel" value="${esc(a ? a.phone : '')}" placeholder="اختياريّ"></label>
            <label class="f" id="fsharew">نسبة الشراكة ٪<input class="in amt" id="fshare" inputmode="decimal" value="${a && a.share ? a.share : ''}" placeholder="مثلًا 50"></label>
          </div>
          <label class="f" id="flimw">سقف الدين (تنبيه إذا عبره)<input class="in amt" id="flim" inputmode="decimal" value="${a && a.limit ? E.fmt(a.limit) : ''}" placeholder="اختياريّ"></label>
          <div id="ftripw" class="card flat" style="padding:12px"><b style="font-size:14px">تفاصيل الرحلة</b> <span class="hint">الحساب يصير محفظة الرحلة: حوّل إلها فلوس واصرف منها</span>
            <div class="grid2" style="margin-top:8px"><label class="f">الميزانيّة (بعملة الرحلة)<input class="in amt" id="fbud" inputmode="decimal" value="${a && a.budget ? E.fmt(a.budget) : ''}" placeholder="اختياريّ"></label>
              <label class="f">الوجهة<input class="in" id="fplace" value="${esc(a && a.place || '')}" placeholder="مثلًا: إسطنبول"></label>
              <label class="f">من تاريخ<input type="date" class="in" id="fst" value="${a && a.start || ''}"></label><label class="f">إلى تاريخ<input type="date" class="in" id="fen" value="${a && a.end || ''}"></label>
              <label class="f">عدد المسافرين<input class="in amt" id="fppl" inputmode="numeric" value="${a && a.people || 1}"></label></div></div>
          ${isNew ? `<div class="card flat" style="padding:12px" id="fobw"><b style="font-size:14px">رصيد سابق؟</b> <span class="hint">إذا الحساب إله أو عليه فلوس من قبل</span>
            <div class="grid3" style="margin-top:8px"><input class="in amt" id="fob" inputmode="decimal" placeholder="المبلغ">
            <select class="in" id="fos"><option value="dr">عليه / عندنا</option><option value="cr">إله / علينا</option></select>
            <input type="date" class="in" id="fod" value="${E.today()}"></div></div>` : ''}
          <label class="f">ملاحظات<textarea class="in" id="fnote" placeholder="عنوان، رقم حساب، أيّ تفاصيل">${esc(a ? a.note : '')}</textarea></label>
        </div>`,
        onClose: () => res(out),
        onMount: (ov) => {
          let sub = sub0;
          const fillGroups = () => {
            const gs = groupsFor(sub);
            const op = o.parent && E.acc(b, o.parent);
            const def = a && E.SUBS[sub].type === a.type ? a.parent : (op && op.type === E.SUBS[sub].type ? op.id : 'g' + E.SUBS[sub].parent);
            $('#fp', ov).innerHTML = gs.map((g) => '<option value="' + g.id + '"' + (g.id === def ? ' selected' : '') + '>' + '— '.repeat(Math.max(0, E.path(b, g.id).length - 1)) + esc(g.name) + ' (' + g.code + ')</option>').join('');
            $('#fsharew', ov).style.display = sub === 'partner' ? '' : 'none';
            $('#flimw', ov).style.display = ['customer', 'employee', 'person'].includes(sub) ? '' : 'none';
            $('#ftripw', ov).style.display = sub === 'trip' ? '' : 'none';
            const ob = $('#fobw', ov); if (ob) ob.style.display = sub === 'trip' ? 'none' : '';
            if (sub === 'trip' && isNew && $('#fc', ov).value === b.meta.base && b.currencies.some((c) => c.code === 'USD')) $('#fc', ov).value = 'USD';
            const os = $('#fos', ov); if (os) os.value = ['supplier', 'loan', 'partner', 'revenue'].includes(sub) ? 'cr' : 'dr';
          };
          $('#fc', ov).value = a ? a.cur : b.meta.base;
          fillGroups();
          $('#fsub', ov).onclick = (e) => { const c = e.target.closest('[data-s]'); if (!c || c.disabled) return; sub = c.dataset.s; $$('#fsub .chip', ov).forEach((x) => x.classList.toggle('on', x === c)); fillGroups(); };
          ['#flim', '#fob', '#fbud'].forEach((s) => U.bindAmount($(s, ov)));
          ov._sub = () => sub;
        },
        actions: [{ label: 'إلغاء', cls: 'ghost', onClick: () => null }, {
          label: isNew ? 'حفظ الحساب' : 'حفظ التعديل', cls: 'pri', onClick: (ov) => {
            const sub = ov._sub();
            const data = { name: $('#fn', ov).value, sub, parent: $('#fp', ov).value, cur: $('#fc', ov).value, phone: $('#fph', ov).value.trim(), note: $('#fnote', ov).value.trim(),
              share: U.parseAmt($('#fshare', ov).value), limit: U.parseAmt($('#flim', ov).value) };
            if (sub === 'trip') Object.assign(data, { budget: U.parseAmt($('#fbud', ov).value), place: $('#fplace', ov).value.trim(), start: $('#fst', ov).value, end: $('#fen', ov).value, people: Math.max(1, parseInt($('#fppl', ov).value, 10) || 1) });
            if (isNew) {
              out = E.addAccount(b, data);
              const ob = U.parseAmt(($('#fob', ov) || {}).value);
              if (ob > 0) {
                try { E.voucher(b, { kind: 'opening', account: out.id, amount: ob, side: $('#fos', ov).value, date: $('#fod', ov).value || E.today(), cur: out.cur, memo: 'رصيد سابق — ' + out.name }); }
                catch (err) { U.toast('انحفظ الحساب بس الرصيد ما انسجّل: ' + err.message, true); }
              }
            } else {
              if (sub !== a.sub) a.sub = sub;
              out = E.updateAccount(b, a.id, data);
            }
            save(); U.toast(isNew ? 'انضاف «' + out.name + '»' : 'انحفظ');
          },
        }],
      });
    });
  };

  // ———————————— صفحة الحساب ————————————
  const accState = { tab: 'st', p: 'all', from: '', to: '' };
  let lastAcc = null;
  V.acc = function (el, p) {
    const b = B();
    const a = E.acc(b, p[0]);
    if (!a) { el.innerHTML = '<div class="empty"><b>الحساب غير موجود</b><a href="#/accounts">رجوع للحسابات</a></div>'; return; }
    if (a.sub === 'trip' && !p[1]) return V.trip(el, [a.id]);
    if (lastAcc !== a.id) { lastAcc = a.id; accState.tab = p[1] || (a.type === 'expense' || a.type === 'revenue' ? 'st' : 'st'); }
    if (p[1]) accState.tab = p[1];
    const bal = E.balance(b, a.id);
    const party = ['customer', 'supplier', 'partner', 'employee', 'loan', 'project', 'general', 'asset'].includes(a.sub);
    const box = ['cash', 'bank'].includes(a.sub);
    const sub = E.SUBS[a.sub] ? E.SUBS[a.sub].name : '';
    const crumbs = E.path(b, a.id).slice(0, -1).map((x) => esc(x.name)).join(' ‹ ');
    const limitWarn = a.limit && bal.own > a.limit ? '<span class="pill neg">' + ic('alert') + ' عبر سقف الدين ' + E.fmt(a.limit) + '</span>' : '';
    const tabs = [['st', 'الكشف الجاري'], ['exp', a.type === 'expense' ? 'حسب الحساب' : a.type === 'revenue' ? 'حسب الحساب' : 'مصاريفه وأرباحه'], ['sum', 'ملخّص'], ['info', 'معلومات']];
    el.innerHTML = `
      <div class="crumb noprint"><a href="#/accounts">الحسابات</a> ‹ ${crumbs}</div>
      <div class="card" style="margin-bottom:16px"><div class="acc-head">${av(a)}
        <div style="min-width:0"><h1 style="margin:0;font-size:22px">${esc(a.name)} ${a.archived ? '<span class="pill warn">مؤرشف</span>' : ''}</h1>
          <div class="hint">${esc(sub)} · رقم ${esc(a.code)} · ${a.cur}${a.phone ? ' · <a href="tel:' + esc(a.phone) + '" class="num">' + esc(a.phone) + '</a>' : ''} ${limitWarn}</div></div>
        <div class="balbox"><div class="l">الرصيد الحاليّ</div><div class="v ${E.side(a, bal.own).cls}c">${M(bal.own, a.cur, { abs: true })}</div><div class="l">${E.side(a, bal.own).word}${a.cur !== b.meta.base ? ' · ≈ ' + E.fmt(bal.base) + ' ' + U.symOf() : ''}</div></div></div>
        <div class="qa noprint" style="margin-top:14px">${accActions(a, party, box)}
          <span class="grow"></span>
          <button class="btn sm ghost" data-edit>${ic('edit')} تعديل</button>
          ${a.phone ? '<button class="btn sm ghost" data-wa>' + ic('wa') + ' واتساب</button>' : ''}
          <button class="btn sm ghost" data-arc>${ic('archive')} ${a.archived ? 'رجّعه' : 'أرشفة'}</button>
          ${!E.isUsed(b, a.id) && !a.system ? '<button class="btn sm ghost danger" data-del>' + ic('trash') + ' حذف</button>' : ''}</div></div>
      <div class="tabbar">${tabs.map((t) => '<button data-t="' + t[0] + '" class="' + (accState.tab === t[0] ? 'on' : '') + '">' + t[1] + '</button>').join('')}</div>
      <div id="atab"></div>`;
    $$('[data-t]', el).forEach((t) => (t.onclick = () => { accState.tab = t.dataset.t; $$('[data-t]', el).forEach((x) => x.classList.toggle('on', x === t)); drawTab(); }));
    $('[data-edit]', el).onclick = async () => { if (await V.accountForm(a)) V.acc(el, [a.id]); };
    $('[data-arc]', el).onclick = () => { E.updateAccount(b, a.id, { archived: !a.archived }); save(); U.toast(a.archived ? 'انأرشف' : 'رجع'); V.acc(el, [a.id]); };
    const del = $('[data-del]', el);
    if (del) del.onclick = async () => { if (await U.confirm('تحذف «' + esc(a.name) + '» نهائيًّا؟', 'احذف', true)) { E.deleteAccount(b, a.id); save(); go('#/accounts'); } };
    const wa = $('[data-wa]', el);
    if (wa) wa.onclick = () => {
      const st = E.statement(b, a.id);
      const last = st.rows.slice(-5).map((r) => r.date + '  ' + (r.memo || E.KINDS[r.kind]) + '  ' + (r.dr ? '+' + E.fmt(r.dr) : '-' + E.fmt(r.cr))).join('\n');
      const txt = 'مرحبا ' + a.name + '\nكشف حسابك لدى ' + b.meta.name + ' بتاريخ ' + E.today() + ':\n' + last + '\n— الرصيد: ' + E.fmt(Math.abs(st.close)) + ' ' + U.symOf(a.cur) + ' ' + E.side(a, st.close).word;
      const ph = a.phone.replace(/\D/g, '').replace(/^0/, '964');
      window.open('https://wa.me/' + ph + '?text=' + encodeURIComponent(txt), '_blank');
    };
    $$('[data-q]', el).forEach((x) => (x.onclick = () => { window.Views.prefill = JSON.parse(x.dataset.q); go('#/new/' + window.Views.prefill.kind); }));
    function drawTab() {
      const t = $('#atab', el);
      if (accState.tab === 'st') return drawStatement(t, a);
      if (accState.tab === 'exp') return drawCenter(t, a);
      if (accState.tab === 'sum') return drawSummary(t, a);
      return drawInfo(t, a);
    }
    drawTab();
  };

  function accActions(a, party, box) {
    const q = (kind, label, icon, extra) => "<button class='btn sm' data-q='" + JSON.stringify(Object.assign({ kind }, extra)).replace(/'/g, '&#39;') + "'>" + ic(icon) + label + '</button>';
    if (box) return q('receipt', 'قبض إليه', 'in', { to: a.id }) + q('payment', 'دفع منه', 'out', { from: a.id }) + q('expense', 'مصروف منه', 'tag', { from: a.id }) + q('transfer', 'تحويل', 'swap', { from: a.id });
    if (a.sub === 'trip') return q('expense', 'مصروف من الرحلة', 'tag', { from: a.id, cc: a.id }) + q('transfer', 'حوّل للمحفظة', 'swap', { to: a.id });
    if (a.type === 'expense') return q('expense', 'مصروف جديد', 'tag', { cat: a.id });
    if (a.type === 'revenue') return q('income', 'إيراد جديد', 'in', { cat: a.id });
    const out = [];
    if (a.sub === 'supplier' || a.sub === 'loan') out.push(q('payment', 'دفعنا له', 'out', { account: a.id }), q('purchase', 'شراء آجل منه', 'cart', { account: a.id }), q('receipt', 'استلمنا منه', 'in', { account: a.id }));
    else out.push(q('receipt', 'قبضنا منه', 'in', { account: a.id }), q('payment', 'دفعنا له', 'out', { account: a.id }));
    if (a.sub === 'customer') out.push(q('sale', 'بيع آجل', 'receipt', { account: a.id }));
    out.push(q('expense', 'مصروف عليه', 'tag', { cc: a.id }));
    if (a.sub === 'project') out.push(q('income', 'إيراد للمشروع', 'in', { cc: a.id }));
    if (party) void 0;
    return out.join('');
  }

  function colNames(a) {
    if (a.sub === 'cash' || a.sub === 'bank') return ['داخل', 'طالع'];
    if (a.type === 'expense' || a.type === 'revenue' || a.type === 'equity' && a.sub !== 'partner') return ['مدين', 'دائن'];
    return ['عليه', 'له'];
  }

  function drawStatement(t, a) {
    const b = B();
    const st = E.statement(b, a.id, accState);
    const [cd, cc] = colNames(a);
    const C = st.cur;
    const sd = (n) => { const s = E.side(a, n); return '<small class="' + s.cls + 'c">' + (Math.abs(n) < 0.005 ? '' : s.word) + '</small>'; };
    t.innerHTML = `
      ${U.printHead('كشف حساب: ' + a.name, U.periodLabel(accState))}
      <div class="row between noprint" style="margin-bottom:12px">${U.periodBar(accState)}
        <div class="row"><button class="btn sm" data-print>${ic('print')} طباعة / PDF</button><button class="btn sm" data-csv>${ic('dl')} Excel</button></div></div>
      <div class="tw"><table class="t">
        <thead><tr><th>التاريخ</th><th class="hide-m">رقم</th><th>البيان</th><th class="n">${cd}</th><th class="n">${cc}</th><th class="n">الرصيد</th></tr></thead>
        <tbody>
          ${accState.from ? `<tr class="open"><td>${accState.from}</td><td class="hide-m"></td><td>رصيد ما قبل الفترة</td><td></td><td></td><td class="n">${E.money(b, Math.abs(st.open), C)} ${sd(st.open)}</td></tr>` : ''}
          ${st.rows.map((r) => `<tr data-e="${r.e}"><td class="num" style="white-space:nowrap">${r.date}</td><td class="hide-m muted">#${r.no}</td>
            <td class="memo">${esc(r.memo || E.KINDS[r.kind])}<small>${esc([E.KINDS[r.kind], r.other && 'مقابل: ' + r.other, r.cat && 'نوع: ' + r.cat, r.cc && r.cc !== a.name && 'على: ' + r.cc, r.acc, r.ref && 'وصل ' + r.ref, r.orig && E.fmt(r.orig.amt, 2) + ' ' + r.orig.cur].filter(Boolean).join(' · '))}</small></td>
            <td class="n drc">${r.dr ? E.money(b, r.dr, C) : ''}</td><td class="n crc">${r.cr ? E.money(b, r.cr, C) : ''}</td><td class="n"><b>${E.money(b, Math.abs(r.bal), C)}</b> ${sd(r.bal)}</td></tr>`).join('') ||
            '<tr><td colspan="6"><div class="empty">ماكو حركات بهذي الفترة</div></td></tr>'}
        </tbody>
        <tfoot><tr><td colspan="2" class="hide-m">المجموع</td><td class="hide-d">المجموع</td><td class="hide-m"></td><td class="n">${E.money(b, st.dr, C)}</td><td class="n">${E.money(b, st.cr, C)}</td><td class="n">${E.money(b, Math.abs(st.close), C)} ${sd(st.close)}</td></tr></tfoot>
      </table></div>
      <div class="hint" style="margin-top:8px">${st.rows.length} حركة · الرصيد بعملة الحساب (${C}) · اضغط على أيّ حركة حتى تشوفها أو تعدّلها</div>`;
    U.bindPeriod(t, accState, () => drawStatement(t, a));
    $('[data-print]', t).onclick = () => window.print();
    $('[data-csv]', t).onclick = () => U.exportCSV('كشف-' + a.name, ['التاريخ', 'رقم القيد', 'النوع', 'البيان', 'مقابل', cd, cc, 'الرصيد'],
      (accState.from ? [[accState.from, '', '', 'رصيد ما قبل الفترة', '', '', '', st.open]] : []).concat(st.rows.map((r) => [r.date, r.no, E.KINDS[r.kind], r.memo, r.other, r.dr || '', r.cr || '', r.bal])));
    t.onclick = (e) => { const r = e.target.closest('[data-e]'); if (r) V.showEntry(r.dataset.e); };
  }

  function drawCenter(t, a) {
    const b = B();
    if (a.type === 'expense' || a.type === 'revenue') {
      const st = E.statement(b, a.id, accState);
      const m = {}; let tot = 0;
      b.entries.forEach((e) => { if ((accState.from && e.date < accState.from) || (accState.to && e.date > accState.to) || e.kind === 'closing') return; e.lines.forEach((l) => { if (l.a === a.id) { const k = l.cc || '—'; const v = (l.dr - l.cr) * l.rate * (a.type === 'revenue' ? -1 : 1); m[k] = (m[k] || 0) + v; tot += v; } }); });
      b.entries.forEach((e) => e.lines.forEach((l) => { if (l.cat === a.id && !((accState.from && e.date < accState.from) || (accState.to && e.date > accState.to))) { const v = (l.dr - l.cr) * l.rate; m[l.a] = (m[l.a] || 0) + v; tot += v; } }));
      const rows = Object.entries(m).map(([k, v]) => ({ id: k === '—' ? '' : k, name: k === '—' ? 'بدون حساب محدّد' : (E.acc(b, k) || {}).name, amt: E.r2(v) })).sort((x, y) => y.amt - x.amt);
      t.innerHTML = '<div class="row between noprint" style="margin-bottom:12px">' + U.periodBar(accState) + '</div><div class="card"><h3>«' + esc(a.name) + '» موزّع على الحسابات <small class="num">' + E.fmt(tot) + '</small></h3>' + U.hbars(rows, tot, a.type === 'revenue') + '</div>';
      void st;
      U.bindPeriod(t, accState, () => drawCenter(t, a));
      t.onclick = (e) => { const r = e.target.closest('[data-acc]'); if (r && r.dataset.acc) go('#/acc/' + r.dataset.acc); };
      return;
    }
    const cr = E.centerReport(b, a.id, accState);
    t.innerHTML = `
      <div class="row between noprint" style="margin-bottom:12px">${U.periodBar(accState)}<button class="btn sm pri" data-addexp>${ic('plus')} مصروف على هذا الحساب</button></div>
      <div class="kpis" style="grid-template-columns:repeat(3,1fr)">
        <div class="kpi"><div class="l">المصاريف عليه</div><div class="v neg">${M(cr.totalExp)}</div></div>
        <div class="kpi"><div class="l">الإيرادات منه</div><div class="v pos">${M(cr.totalRev)}</div></div>
        <div class="kpi"><div class="l">الصافي (ربح/خسارة)</div><div class="v ${cr.profit >= 0 ? 'pos' : 'neg'}">${M(cr.profit)}</div></div></div>
      <div class="cols" style="margin-top:16px">
        <div class="card"><h3>المصاريف حسب النوع</h3>${cr.expenses.length ? U.donut(cr.expenses, cr.totalExp) + '<div style="margin-top:12px">' + U.hbars(cr.expenses, cr.totalExp) + '</div>' : '<div class="empty"><b>ماكو مصاريف على هذا الحساب</b>بالسند اختار «على حساب» = ' + esc(a.name) + '</div>'}</div>
        <div class="card"><h3>الحركات</h3>${cr.rows.length ? '<div class="tw"><table class="t"><thead><tr><th>التاريخ</th><th>النوع</th><th>البيان</th><th class="n">المبلغ</th></tr></thead><tbody>' +
          cr.rows.map((r) => '<tr data-e="' + r.e + '"><td class="num">' + r.date + '</td><td>' + esc(r.cat) + (r.onParty ? ' <span class="pill dr">عليه</span>' : '') + '</td><td class="memo">' + esc(r.memo || '') + '</td><td class="n ' + (r.type === 'revenue' ? 'pos' : 'neg') + '">' + E.fmt(r.amt) + '</td></tr>').join('') + '</tbody></table></div>' : '<div class="empty">—</div>'}</div></div>
      ${cr.revenues.length ? '<div class="card" style="margin-top:16px"><h3>الإيرادات حسب النوع</h3>' + U.hbars(cr.revenues, cr.totalRev, true) + '</div>' : ''}`;
    U.bindPeriod(t, accState, () => drawCenter(t, a));
    $('[data-addexp]', t).onclick = () => { window.Views.prefill = { kind: 'expense', cc: a.id }; go('#/new/expense'); };
    t.onclick = (e) => { const r = e.target.closest('[data-e]'); if (r) V.showEntry(r.dataset.e); const h = e.target.closest('[data-acc]'); if (h) go('#/acc/' + h.dataset.acc); };
  }

  function drawSummary(t, a) {
    const b = B();
    const st = E.statement(b, a.id);
    const mo = {}; st.rows.forEach((r) => { const k = r.date.slice(0, 7); mo[k] = mo[k] || { k, rev: 0, exp: 0 }; mo[k].rev += r.dr; mo[k].exp += r.cr; });
    const months = U.period('year'); void months;
    const keys = []; const d = new Date(); for (let i = 11; i >= 0; i--) { const x = new Date(d.getFullYear(), d.getMonth() - i, 1); keys.push(x.getFullYear() + '-' + String(x.getMonth() + 1).padStart(2, '0')); }
    const data = keys.map((k) => ({ k, rev: E.r2((mo[k] || {}).rev || 0), exp: E.r2((mo[k] || {}).exp || 0), net: 0 }));
    let run = 0; const before = st.rows.filter((r) => r.date.slice(0, 7) < keys[0]).reduce((s, r) => s + r.dr - r.cr, st.open); run = before;
    data.forEach((x) => { run += x.rev - x.exp; x.net = E.r2(run); });
    const [cd, cc] = colNames(a);
    const first = st.rows[0], last = st.rows[st.rows.length - 1];
    const big = st.rows.slice().sort((x, y) => (y.dr + y.cr) - (x.dr + x.cr)).slice(0, 5);
    const ag = ['customer', 'employee', 'project'].includes(a.sub) ? E.aging(b, {}).find((x) => x.id === a.id) : ['supplier', 'loan'].includes(a.sub) ? E.aging(b, { side: 'pay' }).find((x) => x.id === a.id) : null;
    t.innerHTML = `
      <div class="kpis">
        <div class="kpi"><div class="l">مجموع ${cd}</div><div class="v drc">${M(st.dr, st.cur)}</div></div>
        <div class="kpi"><div class="l">مجموع ${cc}</div><div class="v crc">${M(st.cr, st.cur)}</div></div>
        <div class="kpi"><div class="l">عدد الحركات</div><div class="v">${st.rows.length}</div><div class="d">${first ? 'من ' + first.date + ' إلى ' + last.date : '—'}</div></div>
        <div class="kpi"><div class="l">الرصيد</div><div class="v ${E.side(a, st.close).cls}c">${M(st.close, st.cur, { abs: true })}</div><div class="d">${E.side(a, st.close).word}</div></div></div>
      <div class="cols" style="margin-top:16px">
        <div class="card"><h3>الحركة الشهريّة <small>أخضر ${cd} · أحمر ${cc} · الخطّ = الرصيد</small></h3>${U.barChart(data)}</div>
        <div class="stack">
          ${ag ? '<div class="card"><h3>عمر الدين</h3>' + ['أقلّ من ٣٠ يوم', '٣١–٦٠ يوم', '٦١–٩٠ يوم', 'أكثر من ٩٠ يوم'].map((n, i) => '<div class="sumrow"><span>' + n + '</span><b class="num">' + E.fmt(ag.b[i]) + '</b></div>').join('') + '</div>' : ''}
          <div class="card"><h3>أكبر الحركات</h3><div class="list">${big.map((r) => '<div class="li" data-e="' + r.e + '"><div class="grow" style="min-width:0"><div class="t">' + esc(r.memo || E.KINDS[r.kind]) + '</div><div class="s">' + r.date + '</div></div><b class="num ' + (r.dr ? 'drc' : 'crc') + '">' + E.fmt(r.dr || r.cr) + '</b></div>').join('') || '<div class="empty">—</div>'}</div></div>
        </div></div>`;
    t.onclick = (e) => { const r = e.target.closest('[data-e]'); if (r) V.showEntry(r.dataset.e); };
  }

  function drawInfo(t, a) {
    const b = B();
    const log = (b.log || []).filter((x) => x.what.includes(a.name)).slice(-12).reverse();
    t.innerHTML = `<div class="cols"><div class="card"><h3>معلومات</h3>
      ${[['الاسم', esc(a.name)], ['النوع', esc(E.SUBS[a.sub] ? E.SUBS[a.sub].name : '') + ' · ' + E.TYPES[a.type].name], ['رقم الحساب', esc(a.code)], ['المجموعة', E.path(b, a.id).slice(0, -1).map((x) => esc(x.name)).join(' ‹ ')],
        ['العملة', a.cur], ['التلفون', esc(a.phone || '—')], a.sub === 'partner' ? ['نسبة الشراكة', (a.share || 0) + '٪'] : null, a.limit ? ['سقف الدين', E.fmt(a.limit)] : null, ['أُنشئ', a.created || '—'],
        ['آخر حركة', E.lastMove(b, a.id) || '—'], ['الملاحظات', esc(a.note || '—').replace(/\n/g, '<br>')]].filter(Boolean).map(([k, v]) => '<div class="sumrow"><span class="hint">' + k + '</span><span>' + v + '</span></div>').join('')}</div>
      <div class="card"><h3>آخر التعديلات</h3>${log.length ? log.map((x) => '<div class="sumrow"><span>' + esc(x.what) + '</span><span class="hint num">' + new Date(x.t).toLocaleDateString('en-CA') + '</span></div>').join('') : '<div class="empty">—</div>'}</div></div>`;
  }

  // ———————————— دليل الحسابات (الشجرة) ————————————
  const openG = new Set(['g1', 'g2', 'g3', 'g4', 'g5']);
  V.chart = function (el) {
    const b = B();
    const tb = E.trialBalance(b);
    const bal = {}; tb.rows.forEach((r) => (bal[r.id] = r.close));
    const node = (a, d) => {
      const kids = E.children(b, a.id).sort((x, y) => (x.code < y.code ? -1 : 1));
      const open = openG.has(a.id);
      const v = bal[a.id] || 0, sign = E.TYPES[a.type].normal;
      return '<div class="li" data-id="' + a.id + '" style="padding-inline-start:' + (d * 18 + 4) + 'px' + (a.archived ? ';opacity:.5' : '') + '">' +
        (a.group ? '<span class="caret' + (open ? ' open' : '') + '">' + ic('chev') + '</span>' : '<span style="width:22px"></span>') + av(a) +
        '<span class="code num">' + esc(a.code) + '</span><div class="grow" style="min-width:0"><div class="t" style="' + (a.group ? '' : 'font-weight:500') + '">' + esc(a.name) + (a.system ? ' <span class="pill">نظام</span>' : '') + '</div></div>' +
        '<b class="num ' + (v * sign < 0 ? 'neg' : '') + '">' + (Math.abs(v) > 0.005 ? E.fmt(v * sign) : '') + '</b>' +
        (a.group ? '<button class="icon-btn" data-addin="' + a.id + '" title="إضافة تحته">' + ic('plus') + '</button>' : '') + '</div>' +
        (a.group && open ? kids.map((k) => node(k, d + 1)).join('') : '');
    };
    const roots = b.accounts.filter((a) => !a.parent).sort((x, y) => (x.code < y.code ? -1 : 1));
    el.innerHTML = `<div class="ph"><div><div class="crumb"><a href="#/accounts">الحسابات</a></div><h1>دليل الحسابات</h1><div class="sub">الشجرة الكاملة بالأرقام. المجموعات تجمع أرصدة اللي تحتها.</div></div>
      <div class="row"><button class="btn" data-expand>توسيع الكلّ</button><button class="btn" data-ngroup>${ic('tree')} مجموعة جديدة</button><button class="btn pri" data-nacc>${ic('plus')} حساب جديد</button></div></div>
      <div class="card tree" style="padding:6px 12px">${roots.map((r) => node(r, 0)).join('')}</div>
      <div class="hint" style="margin-top:8px">الأرصدة بالعملة الأساسيّة (${b.meta.base}) وبطبيعة كلّ نوع: الأصول والمصروفات موجبة بالمدين، والباقي موجب بالدائن.</div>`;
    el.querySelector('.tree').onclick = async (e) => {
      const add = e.target.closest('[data-addin]');
      if (add) { e.stopPropagation(); return addIn(add.dataset.addin, el); }
      const li = e.target.closest('.li'); if (!li) return;
      const a = E.acc(b, li.dataset.id);
      if (a.group) { openG.has(a.id) ? openG.delete(a.id) : openG.add(a.id); V.chart(el); } else go('#/acc/' + a.id);
    };
    $('[data-expand]', el).onclick = () => { b.accounts.filter((a) => a.group).forEach((a) => openG.add(a.id)); V.chart(el); };
    $('[data-ngroup]', el).onclick = () => groupForm(null, null, el);
    $('[data-nacc]', el).onclick = async () => { if (await V.accountForm()) V.chart(el); };
  };
  async function addIn(gid, el) {
    const b = B(); const g = E.acc(b, gid);
    U.modal({ title: 'إضافة تحت «' + g.name + '»', body: '<div class="stack"><button class="btn block" data-a>' + ic('plus') + ' حساب فرعيّ</button><button class="btn block" data-g>' + ic('tree') + ' مجموعة فرعيّة</button><button class="btn block ghost" data-e>' + ic('edit') + ' تعديل/حذف المجموعة</button></div>', foot: false,
      onMount: (ov, close) => {
        $('[data-a]', ov).onclick = async () => {
          close();
          const sub = Object.keys(E.SUBS).find((k) => E.SUBS[k].type === g.type && 'g' + E.SUBS[k].parent === g.id) || Object.keys(E.SUBS).find((k) => E.SUBS[k].type === g.type);
          const a = await V.accountForm(null, { sub, subs: Object.keys(E.SUBS).filter((k) => E.SUBS[k].type === g.type), parent: gid });
          if (a && a.parent !== gid) { try { E.updateAccount(b, a.id, { parent: gid }); save(); } catch (err) { U.toast(err.message, true); } }
          openG.add(gid); V.chart(el);
        };
        $('[data-g]', ov).onclick = () => { close(); groupForm(null, gid, el); };
        $('[data-e]', ov).onclick = () => { close(); groupForm(g, g.parent, el); };
      } });
  }
  function groupForm(g, parent, el) {
    const b = B();
    const groups = b.accounts.filter((x) => x.group && (!g || x.id !== g.id));
    U.modal({ title: g ? 'تعديل المجموعة' : 'مجموعة جديدة',
      body: '<div class="form"><label class="f">الاسم<input class="in" id="gn" value="' + esc(g ? g.name : '') + '"></label><label class="f">تحت<select class="in" id="gp">' +
        (g && !g.parent ? '<option value="">— رئيسيّة —</option>' : '') + groups.map((x) => '<option value="' + x.id + '"' + (x.id === parent ? ' selected' : '') + '>' + '— '.repeat(E.path(b, x.id).length - 1) + esc(x.name) + ' (' + x.code + ')</option>').join('') + '</select></label></div>',
      actions: [g && !E.isUsed(b, g.id) && g.parent ? { label: ic('trash') + ' حذف', cls: 'ghost danger', onClick: () => { E.deleteAccount(b, g.id); save(); V.chart(el); } } : null,
        { label: 'إلغاء', cls: 'ghost' }, { label: 'حفظ', cls: 'pri', onClick: (ov) => {
          const name = $('#gn', ov).value, p = $('#gp', ov).value;
          if (g) E.updateAccount(b, g.id, { name, parent: p || g.parent }); else { const ng = E.addAccount(b, { name, group: true, parent: p }); openG.add(p); openG.add(ng.id); }
          save(); V.chart(el);
        } }].filter(Boolean) });
  }
})();
