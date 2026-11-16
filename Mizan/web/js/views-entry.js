/* ميزان — السندات، القيد اليدويّ، دفتر اليوميّة، عرض القيد */
(function () {
  'use strict';
  const E = window.Engine, U = window.UI;
  const { $, $$, esc, ic } = U;
  const B = () => window.Store.book;
  const V = (window.Views = window.Views || {});
  const save = () => window.Store.save();
  const go = (h) => (location.hash = h);

  const F = {
    cash: (a) => a.sub === 'cash' || a.sub === 'bank',
    party: (a) => a.type !== 'expense' && a.type !== 'revenue' && !a.system,
    exp: (a) => a.type === 'expense',
    rev: (a) => a.type === 'revenue',
    buy: (a) => a.type === 'expense' || a.sub === 'asset',
    center: (a) => a.type !== 'expense' && a.type !== 'revenue' && a.sub !== 'cash' && a.sub !== 'bank' && !a.system,
    payfrom: (a) => a.type !== 'expense' && a.type !== 'revenue' && !a.system,
    any: (a) => !a.system || a.system === 'fx',
  };
  // تعريف كلّ سند: الحقول + الكلمات البسيطة
  const KF = {
    receipt: { icon: 'in', name: 'قبض', hint: 'فلوس دخلت لصندوقك من شخص أو جهة', f: [['account', 'قبضنا من', F.party, 'customer'], ['to', 'ودخلت إلى', F.cash, 'cash']], cc: true },
    payment: { icon: 'out', name: 'دفع', hint: 'دفعت فلوس لشخص أو جهة (تسديد، سلفة، دفعة)', f: [['account', 'دفعنا إلى', F.party, 'supplier'], ['from', 'وطلعت من', F.cash, 'cash']], cc: true },
    expense: { icon: 'tag', name: 'مصروف', hint: 'صرفيّة: إيجار، وقود، رواتب… وتكدر تحمّلها على حساب', f: [['cat', 'نوع المصروف', F.exp, 'expense'], ['from', 'انصرف من', F.payfrom, 'cash']], cc: true, onParty: true },
    income: { icon: 'in', name: 'إيراد', hint: 'دخل مباشر: مبيعات نقديّة، عمولة، إيجار مقبوض', f: [['cat', 'نوع الإيراد', F.rev, 'revenue'], ['to', 'دخل إلى', F.cash, 'cash']], cc: true },
    transfer: { icon: 'swap', name: 'تحويل', hint: 'بين صناديق ومصارف، أو صرف عملة (دولار ⇄ دينار)', f: [['from', 'من', F.payfrom, 'cash'], ['to', 'إلى', F.payfrom, 'cash']] },
    sale: { icon: 'receipt', name: 'بيع آجل', hint: 'بعت لزبون بالدين — ينضاف عليه', f: [['account', 'الزبون', F.party, 'customer'], ['cat', 'نوع الإيراد', F.rev, 'revenue']], cc: true },
    purchase: { icon: 'cart', name: 'شراء آجل', hint: 'اشتريت من مورد بالدين — ينضاف إله', f: [['account', 'المورد', F.party, 'supplier'], ['cat', 'شنو اشتريت (نوع المصروف/الأصل)', F.buy, 'expense']], cc: true },
    opening: { icon: 'flag', name: 'رصيد افتتاحيّ', hint: 'الموجود قبل ما تبدي بالبرنامج: صندوق، ديون إلك أو عليك', f: [['account', 'الحساب', F.any, 'cash']], side: true },
    journal: { icon: 'book', name: 'قيد يدويّ', hint: 'للمحاسب: قيد متعدّد الأسطر بالمدين والدائن' },
  };
  V.KF = KF;

  // ———————————— السند ————————————
  V.newEntry = function (el, p) {
    const b = B();
    let kind = p[0] && KF[p[0]] ? p[0] : 'expense';
    let v = Object.assign({ kind, date: E.today(), cur: b.meta.base }, V.prefill || {});
    let editing = null;
    if (p.edit) {
      editing = b.entries.find((e) => e.id === p.edit);
      if (!editing) { el.innerHTML = '<div class="empty"><b>القيد غير موجود</b></div>'; return; }
      const tv = E.toVoucher(b, editing);
      if (tv) { v = tv; kind = tv.kind; } else kind = 'journal';
    }
    if (V.prefill && V.prefill.kind) kind = V.prefill.kind;
    V.prefill = null;
    const from = V.returnTo || '';
    V.returnTo = '';
    v.kind = kind;
    draw();

    function draw() {
      const k = KF[kind];
      el.innerHTML = `
        <div class="ph"><div><div class="crumb"><a href="#/journal">القيود</a></div><h1>${editing ? 'تعديل القيد #' + editing.no : 'سند جديد'}</h1><div class="sub">${esc(k.hint)}</div></div></div>
        ${editing ? '' : `<div class="kinds">${Object.entries(KF).map(([key, x]) => '<button class="kind' + (key === kind ? ' on' : '') + '" data-k="' + key + '">' + ic(x.icon) + x.name + '</button>').join('')}</div>`}
        <div class="cols"><div class="card"><div class="form" id="vf"></div></div><div class="stack" id="vside"></div></div>`;
      $$('[data-k]', el).forEach((x) => (x.onclick = () => { kind = x.dataset.k; v = { kind, date: v.date, amount: v.amount, cur: v.cur, memo: v.memo }; draw(); }));
      if (kind === 'journal') return drawJournal();
      drawForm();
    }

    function curOf(id) { const a = E.acc(b, id); return a && a.cur ? a.cur : null; }

    function drawForm() {
      const k = KF[kind];
      const f = $('#vf', el);
      // الصرف من محفظة رحلة ⇒ يتحمّل على الرحلة تلقائيًّا
      const fromA = E.acc(b, v.from);
      if (kind === 'expense' && fromA && fromA.sub === 'trip' && !v.cc) v.cc = fromA.id;
      const dueOk = ['payment', 'receipt', 'sale', 'purchase', 'opening'].includes(kind);
      // عملة السند تتبع الصندوق
      const boxId = v.to && kind !== 'transfer' && kind !== 'sale' ? v.to : v.from && kind !== 'transfer' ? v.from : kind === 'opening' ? v.account : null;
      if (kind === 'transfer' && v.from) v.cur = curOf(v.from) || v.cur;
      else if (boxId && curOf(boxId)) v.cur = curOf(boxId);
      else if ((kind === 'sale' || kind === 'purchase') && v.account && curOf(v.account)) v.cur = curOf(v.account);
      const C = v.cur || b.meta.base;
      const foreign = C !== b.meta.base;
      const toCur = kind === 'transfer' && v.to ? curOf(v.to) : null;
      const fx = kind === 'transfer' && toCur && toCur !== C;
      if (foreign && !v.rate) v.rate = E.cur(b, C).rate;
      f.innerHTML = `
        <label class="f">المبلغ <div class="row" style="flex-wrap:nowrap"><input class="in big amt grow" id="vamt" inputmode="decimal" autocomplete="off" placeholder="0" value="${v.amount ? E.fmt(v.amount, 2).replace(/\.00$/, '') : ''}">
          <select class="in" id="vcur" style="width:auto;height:58px">${b.currencies.map((c) => '<option value="' + c.code + '"' + (c.code === C ? ' selected' : '') + '>' + esc(c.sym || c.code) + '</option>').join('')}</select></div>
          <span class="hint">تكدر تكتب 1.5م أو 250ا أو 1500*3</span></label>
        ${foreign ? `<label class="f">سعر الصرف (1 ${C} = ? ${b.meta.base})<input class="in amt" id="vrate" inputmode="decimal" value="${v.rate}"></label>` : ''}
        ${k.f.map(([key, label, , newSub]) => `<label class="f">${label}${U.pickBtn('p_' + key, E.acc(b, v[key]), 'اختار…')}</label>`).join('')}
        ${fx ? `<label class="f">المبلغ اللي وصل (${toCur})<input class="in amt" id="vto" inputmode="decimal" value="${v.toAmount ? E.fmt(v.toAmount, 2).replace(/\.00$/, '') : ''}" placeholder="${E.fmt((v.amount || 0) * (v.rate || E.cur(b, C).rate) / E.cur(b, toCur).rate, 2)}"></label>` : ''}
        ${k.side ? `<label class="f">الرصيد<div class="seg" id="vside2"><button type="button" data-s="dr" class="${v.side !== 'cr' ? 'on' : ''}">عليه / عندنا (مدين)</button><button type="button" data-s="cr" class="${v.side === 'cr' ? 'on' : ''}">إله / علينا (دائن)</button></div></label>` : ''}
        ${k.cc ? `<label class="f">على حساب <span class="hint">(اختياريّ — مشروع أو شخص يتحمّل هذي الحركة حتى تطلع بمصاريفه وأرباحه)</span>
          <div class="row" style="flex-wrap:nowrap"><span class="grow">${U.pickBtn('p_cc', E.acc(b, v.cc), 'بدون')}</span>${v.cc ? '<button class="icon-btn" id="ccx" title="شيل">' + ic('x') + '</button>' : ''}</div></label>` : ''}
        ${k.onParty && v.cc ? `<label class="chk"><input type="checkbox" id="vonp" ${v.onParty ? 'checked' : ''}> المصروف <b>يتحمّله «${esc((E.acc(b, v.cc) || {}).name)}»</b> (ينضاف دين عليه بدل ما يكون مصروف علينا)</label>` : ''}
        <div class="grid2"><label class="f">التاريخ<input type="date" class="in" id="vdate" value="${v.date}"></label>
          <label class="f">رقم الوصل / المستند<input class="in" id="vref" value="${esc(v.ref || '')}" placeholder="اختياريّ"></label></div>
        <label class="f">البيان<input class="in" id="vmemo" value="${esc(v.memo || '')}" placeholder="${esc(memoHint())}"></label>
        ${dueOk ? `<label class="f">موعد السداد <span class="hint">(اختياريّ — يطلع بـ«ديوني» وينبّهك إذا تأخّر)</span><input type="date" class="in" id="vdue" value="${v.due || ''}"></label>` : ''}
        <div class="err" id="verr"></div>
        <div class="row end">${editing ? `<button class="btn ghost danger" id="vdel">${ic('trash')} حذف</button><span class="grow"></span>` : ''}
          ${editing ? '' : '<button class="btn" id="vsave2">حفظ وسند جديد</button>'}<button class="btn pri" id="vsave">${ic('check')} ${editing ? 'حفظ التعديل' : 'حفظ'}</button></div>`;
      // ربط
      U.bindAmount($('#vamt', f), (n) => { v.amount = n; side(); });
      $('#vcur', f).onchange = (e) => { v.cur = e.target.value; v.rate = E.cur(b, v.cur).rate; drawForm(); };
      const vr = $('#vrate', f); if (vr) vr.oninput = () => { v.rate = U.parseAmt(vr.value); side(); };
      const vt = $('#vto', f); if (vt) U.bindAmount(vt, (n) => { v.toAmount = n; side(); });
      k.f.forEach(([key, label, filt, newSub]) => U.bindPick(f, 'p_' + key, { filter: filt, title: label, newSub, ph: 'اختار…' }, (a) => { v[key] = a.id; drawForm(); }));
      if (k.cc) U.bindPick(f, 'p_cc', { filter: F.center, title: 'على حساب', newSub: 'project', ph: 'بدون' }, (a) => { v.cc = a.id; drawForm(); });
      const ccx = $('#ccx', f); if (ccx) ccx.onclick = () => { v.cc = ''; v.onParty = false; drawForm(); };
      const op = $('#vonp', f); if (op) op.onchange = () => { v.onParty = op.checked; side(); };
      const sd = $('#vside2', f); if (sd) sd.onclick = (e) => { const x = e.target.closest('[data-s]'); if (x) { v.side = x.dataset.s; drawForm(); } };
      $('#vdate', f).onchange = (e) => (v.date = e.target.value);
      $('#vref', f).oninput = (e) => (v.ref = e.target.value);
      $('#vmemo', f).oninput = (e) => (v.memo = e.target.value);
      const vd = $('#vdue', f); if (vd) vd.onchange = (e) => (v.due = e.target.value);
      $('#vsave', f).onclick = () => submit(false);
      const s2 = $('#vsave2', f); if (s2) s2.onclick = () => submit(true);
      const dl = $('#vdel', f); if (dl) dl.onclick = () => delEntry(editing.id);
      f.onkeydown = (e) => { if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) submit(false); };
      if (!v.amount && matchMedia('(min-width:821px)').matches) setTimeout(() => $('#vamt', f) && $('#vamt', f).focus(), 20);
      side();
    }

    function memoHint() {
      const n = (id) => (E.acc(b, v[id]) || {}).name || '';
      switch (kind) {
        case 'receipt': return 'قبض من ' + (n('account') || '…');
        case 'payment': return 'دفع إلى ' + (n('account') || '…');
        case 'expense': return (n('cat') || 'مصروف') + (v.cc ? ' — ' + n('cc') : '');
        case 'income': return n('cat') || 'إيراد';
        case 'transfer': return 'تحويل من ' + (n('from') || '…') + ' إلى ' + (n('to') || '…');
        case 'sale': return 'بيع آجل إلى ' + (n('account') || '…');
        case 'purchase': return 'شراء آجل من ' + (n('account') || '…');
        case 'opening': return 'رصيد افتتاحيّ — ' + (n('account') || '…');
      }
      return '';
    }

    function side() {
      const s = $('#vside', el); if (!s) return;
      let lines = null, err = '';
      try { lines = E.voucherLines(b, Object.assign({}, v, { memo: v.memo || memoHint() })); } catch (e) { err = e.message; }
      const fx = lines && lines.some((l) => (E.acc(b, l.a) || {}).system === 'fx');
      const effects = lines ? lines.filter((l) => !(E.acc(b, l.a) || {}).system).map((l) => {
        const a = E.acc(b, l.a); const now = E.balance(b, a.id).own; const delta = l.cur === a.cur ? l.dr - l.cr : (l.dr - l.cr) * l.rate / E.cur(b, a.cur).rate;
        const old = editing ? editing.lines.filter((x) => x.a === a.id).reduce((t, x) => t + (x.cur === a.cur ? x.dr - x.cr : (x.dr - x.cr) * x.rate / E.cur(b, a.cur).rate), 0) : 0;
        const after = E.r2(now - old + delta);
        return '<div class="sumrow"><span>' + esc(a.name) + '</span><span class="num">' + E.fmt(Math.abs(after), 0) + ' <small class="' + E.side(a, after).cls + 'c">' + E.side(a, after).word + '</small></span></div>';
      }).join('') : '';
      s.innerHTML = `<div class="preview"><div class="ttl">${ic('book')} القيد اللي راح ينسجّل</div>
        ${lines ? '<div class="pl"><span class="hint">الحساب</span><span class="hint n">مدين</span><span class="hint n">دائن</span>' + lines.map((l) => { const a = E.acc(b, l.a); return '<span>' + esc(a.name) + (l.cc ? ' <small class="hint">← ' + esc((E.acc(b, l.cc) || {}).name) + '</small>' : '') + (l.cat ? ' <small class="hint">(' + esc((E.acc(b, l.cat) || {}).name) + ')</small>' : '') + '</span><span class="n drc">' + (l.dr ? E.fmt(l.dr, l.cur === b.meta.base ? 0 : 2) + (l.cur !== b.meta.base ? ' ' + l.cur : '') : '') + '</span><span class="n crc">' + (l.cr ? E.fmt(l.cr, l.cur === b.meta.base ? 0 : 2) + (l.cur !== b.meta.base ? ' ' + l.cur : '') : '') + '</span>'; }).join('') + '</div>' : '<div class="hint">' + esc(err || 'كمّل الحقول') + '</div>'}
        ${fx ? '<div class="hint" style="margin-top:6px">' + ic('alert') + ' فرق سعر الصرف راح يتسجّل بحساب «فروقات صرف»</div>' : ''}</div>
        ${effects ? '<div class="card flat"><h3>الأرصدة بعد الحفظ</h3>' + effects + '</div>' : ''}
        ${limitWarn(lines)}`;
    }
    function limitWarn(lines) {
      if (!lines) return '';
      const w = lines.map((l) => { const a = E.acc(b, l.a); if (!a.limit) return ''; const after = E.balance(b, a.id).own + l.dr - l.cr; return after > a.limit ? '<div class="pill neg" style="padding:8px 12px">' + ic('alert') + ' «' + esc(a.name) + '» راح يعبر سقف الدين (' + E.fmt(a.limit) + ')</div>' : ''; }).join('');
      return w;
    }

    function submit(again) {
      const errEl = $('#verr', el);
      try {
        const e = E.voucher(b, Object.assign({}, v, { memo: v.memo || memoHint(), id: editing ? editing.id : undefined }));
        save();
        U.toast((editing ? 'انحفظ التعديل' : 'انسجّل') + ' — قيد #' + e.no);
        if (again) { v = { kind, date: v.date, cur: v.cur, from: v.from, to: v.to, cc: (E.acc(b, v.from) || {}).sub === 'trip' ? v.cc : '', cat: kind === 'expense' ? '' : v.cat }; drawForm(); return; }
        go(from || '#/journal');
      } catch (err) { errEl.textContent = err.message; U.toast(err.message, true); }
    }

    // ——— القيد اليدويّ متعدّد الأسطر ———
    function drawJournal() {
      const f = $('#vf', el);
      let lines = editing ? editing.lines.filter((l) => !(E.acc(b, l.a) || {}).system || (E.acc(b, l.a) || {}).system !== 'fx').map((l) => Object.assign({}, l)) : [{ a: '', dr: 0, cr: 0 }, { a: '', dr: 0, cr: 0 }];
      if (V.prefillLines) { lines = V.prefillLines; V.prefillLines = null; }
      let meta = { date: editing ? editing.date : v.date, memo: editing ? editing.memo : v.memo || '', ref: editing ? editing.ref : '' };
      const render = () => {
        f.innerHTML = `<div class="lines"><div class="ln hd"><span>الحساب</span><span>مدين</span><span>دائن</span><span>على حساب</span><span></span></div>
          ${lines.map((l, i) => `<div class="ln" data-i="${i}">${U.pickBtn('jl' + i, E.acc(b, l.a), 'اختار حساب')}
            <input class="in amt" data-dr inputmode="decimal" placeholder="مدين" value="${l.dr ? E.fmt(l.dr, 2).replace(/\.00$/, '') : ''}">
            <input class="in amt" data-cr inputmode="decimal" placeholder="دائن" value="${l.cr ? E.fmt(l.cr, 2).replace(/\.00$/, '') : ''}">
            ${U.pickBtn('jc' + i, E.acc(b, l.cc), '—')}
            <button class="icon-btn" data-rm title="شيل السطر">${ic('x')}</button></div>`).join('')}</div>
          <div class="row"><button class="btn sm" id="jadd">${ic('plus')} سطر</button><button class="btn sm ghost" id="jbal">وازن تلقائيًّا</button><span class="grow"></span><span id="jdiff"></span></div>
          <div class="grid2"><label class="f">التاريخ<input type="date" class="in" id="jdate" value="${meta.date}"></label><label class="f">رقم المستند<input class="in" id="jref" value="${esc(meta.ref || '')}"></label></div>
          <label class="f">البيان<input class="in" id="jmemo" value="${esc(meta.memo || '')}" placeholder="شرح القيد"></label>
          <div class="err" id="verr"></div>
          <div class="row end">${editing ? `<button class="btn ghost danger" id="vdel">${ic('trash')} حذف</button><span class="grow"></span>` : ''}<button class="btn pri" id="jsave">${ic('check')} حفظ القيد</button></div>`;
        lines.forEach((l, i) => {
          U.bindPick(f, 'jl' + i, { filter: F.any, title: 'حساب السطر ' + (i + 1) }, (a) => { l.a = a.id; l.cur = a.cur; render(); });
          U.bindPick(f, 'jc' + i, { filter: F.center, title: 'على حساب', newSub: 'project' }, (a) => { l.cc = a.id; render(); });
        });
        $$('.ln[data-i]', f).forEach((row) => {
          const l = lines[+row.dataset.i];
          U.bindAmount($('[data-dr]', row), (n) => { l.dr = n; if (n) { l.cr = 0; $('[data-cr]', row).value = ''; } diff(); });
          U.bindAmount($('[data-cr]', row), (n) => { l.cr = n; if (n) { l.dr = 0; $('[data-dr]', row).value = ''; } diff(); });
          $('[data-rm]', row).onclick = () => { if (lines.length > 2) { lines.splice(+row.dataset.i, 1); render(); } else { l.a = ''; l.dr = l.cr = 0; render(); } };
        });
        $('#jadd', f).onclick = () => { lines.push({ a: '', dr: 0, cr: 0 }); render(); };
        $('#jbal', f).onclick = () => {
          const d = E.r2(lines.reduce((s, l) => s + (l.dr || 0) - (l.cr || 0), 0)); if (!d) return;
          let t = lines.find((l) => !l.dr && !l.cr) || (lines.push({ a: '', dr: 0, cr: 0 }), lines[lines.length - 1]);
          if (d > 0) t.cr = d; else t.dr = -d; render();
        };
        $('#jdate', f).onchange = (e) => (meta.date = e.target.value);
        $('#jref', f).oninput = (e) => (meta.ref = e.target.value);
        $('#jmemo', f).oninput = (e) => (meta.memo = e.target.value);
        const dl = $('#vdel', f); if (dl) dl.onclick = () => delEntry(editing.id);
        $('#jsave', f).onclick = () => {
          try {
            const e = E.post(b, { id: editing ? editing.id : undefined, kind: editing ? editing.kind === 'journal' || !KF[editing.kind] ? editing.kind : 'journal' : 'journal', date: meta.date, memo: meta.memo, ref: meta.ref, lines: lines.map((l) => Object.assign({}, l, { rate: l.cur && l.cur !== b.meta.base ? l.rate || E.cur(b, l.cur).rate : 1 })) });
            save(); U.toast('انسجّل القيد #' + e.no); go(from || '#/journal');
          } catch (err) { $('#verr', f).textContent = (err.all || [err.message]).join(' · '); }
        };
        diff();
      };
      const diff = () => {
        const dr = lines.reduce((s, l) => s + (+l.dr || 0) * (l.cur && l.cur !== b.meta.base ? E.cur(b, l.cur).rate : 1), 0);
        const cr = lines.reduce((s, l) => s + (+l.cr || 0) * (l.cur && l.cur !== b.meta.base ? E.cur(b, l.cur).rate : 1), 0);
        const d = E.r2(dr - cr);
        $('#jdiff', f).innerHTML = '<span class="diff ' + (Math.abs(d) < 0.01 && dr > 0 ? 'ok' : 'bad') + '">' + (Math.abs(d) < 0.01 && dr > 0 ? ic('check').replace('<svg', '<svg style="display:inline;width:15px;vertical-align:-3px"') + ' متوازن ' + E.fmt(dr) : 'الفرق ' + E.fmt(Math.abs(d), 2)) + '</span>';
        const sd = $('#vside', el);
        sd.innerHTML = '<div class="card flat"><h3>شلون يشتغل القيد؟</h3><div class="hint" style="line-height:1.9">• <b>مدين</b> = الحساب اللي استلم (الصندوق إذا دخلت فلوس، المصروف إذا صرفت، الزبون إذا صار عليه).<br>• <b>دائن</b> = الحساب اللي أعطى (الصندوق إذا طلعت فلوس، الإيراد، المورد إذا صار إله).<br>• مجموع المدين لازم = مجموع الدائن.</div></div>';
      };
      render();
    }

    async function delEntry(id) {
      if (!(await U.confirm('تحذف هذا القيد؟ الأرصدة كلّها ترجع مثل قبله.', 'احذف', true))) return;
      try { E.remove(b, id); save(); U.toast('انحذف'); go(from || '#/journal'); } catch (err) { U.toast(err.message, true); }
    }
  };

  // ———————————— عرض قيد ————————————
  V.showEntry = function (id) {
    const b = B();
    const e = b.entries.find((x) => x.id === id);
    if (!e) return;
    const rows = e.lines.map((l) => { const a = E.acc(b, l.a) || { name: '؟' }; return '<tr><td>' + esc(a.name) + '<small class="hint" style="display:block">' + esc([a.code, l.cc && 'على: ' + (E.acc(b, l.cc) || {}).name, l.cat && 'نوع: ' + (E.acc(b, l.cat) || {}).name, l.m].filter(Boolean).join(' · ')) + '</small></td><td class="n drc">' + (l.dr ? E.fmt(l.dr, l.cur === b.meta.base ? 0 : 2) : '') + '</td><td class="n crc">' + (l.cr ? E.fmt(l.cr, l.cur === b.meta.base ? 0 : 2) : '') + '</td><td class="muted">' + (l.cur !== b.meta.base ? l.cur + ' × ' + l.rate : '') + '</td></tr>'; }).join('');
    const tot = E.amountOf(e);
    const locked = b.meta.lockDate && e.date <= b.meta.lockDate;
    const rev = e.reverses ? b.entries.find((x) => x.id === e.reverses) : b.entries.find((x) => x.reverses === e.id);
    U.modal({
      title: (E.KINDS[e.kind] || 'قيد') + ' #' + e.no, wide: true,
      body: `<div class="row" style="margin-bottom:10px">${V.kindAv(e.kind)}<div class="grow"><b style="font-size:16px">${esc(e.memo || E.KINDS[e.kind])}</b><div class="hint">${e.date}${e.ref ? ' · مستند ' + esc(e.ref) : ''} · انسجّل ${new Date(e.created).toLocaleString('en-GB')}${e.updated && e.updated - e.created > 2000 ? ' · عُدّل ' + new Date(e.updated).toLocaleString('en-GB') : ''}</div></div><b class="num" style="font-size:20px">${E.fmt(tot)}</b></div>
        ${locked ? '<div class="pill warn" style="margin-bottom:10px">' + ic('lock') + ' بفترة مقفلة — ما يتعدّل</div>' : ''}
        ${rev ? '<div class="pill" style="margin-bottom:10px">' + ic('undo') + (e.reverses ? ' يعكس القيد #' + rev.no : ' معكوس بالقيد #' + rev.no) + '</div>' : ''}
        <div class="tw"><table class="t"><thead><tr><th>الحساب</th><th class="n">مدين</th><th class="n">دائن</th><th></th></tr></thead><tbody>${rows}</tbody>
        <tfoot><tr><td>المجموع</td><td class="n">${E.fmt(tot)}</td><td class="n">${E.fmt(E.r2(e.lines.reduce((s, l) => s + l.cr * l.rate, 0)))}</td><td></td></tr></tfoot></table></div>`,
      actions: [
        { label: ic('print') + ' طباعة سند', cls: 'ghost', keep: true, onClick: () => printVoucher(e) },
        { label: ic('copy') + ' تكرار', cls: 'ghost', onClick: () => { const v = E.toVoucher(b, e); if (v) { delete v.id; v.date = E.today(); V.prefill = v; go('#/new/' + v.kind); } else { V.prefillLines = e.lines.map((l) => Object.assign({}, l)); go('#/new/journal'); } } },
        locked ? null : { label: ic('undo') + ' عكس', cls: 'ghost', onClick: async () => { if (await U.confirm('أسوّي قيد عكسيّ بتاريخ اليوم يلغي أثر هذا القيد ويبقى الاثنين بالسجلّ؟', 'اعكس')) { const r = E.reverse(b, e.id); save(); U.toast('انعكس بالقيد #' + r.no); window.App.render(); } } },
        locked || e.kind === 'closing' ? null : { label: ic('edit') + ' تعديل', cls: 'pri', onClick: () => { V.returnTo = location.hash; go('#/edit/' + e.id); } },
      ].filter(Boolean),
    });
  };

  function printVoucher(e) {
    const b = B();
    const d = e.lines.filter((l) => l.dr > 0), c = e.lines.filter((l) => l.cr > 0);
    const nm = (l) => esc((E.acc(b, l.a) || {}).name);
    const tot = E.amountOf(e);
    const w = document.createElement('div');
    w.id = 'printv';
    w.innerHTML = `<div style="border:2px solid #000;padding:18px;border-radius:8px;max-width:640px;margin:auto;font-size:14px">
      <div style="display:flex;justify-content:space-between;border-bottom:1px solid #000;padding-bottom:8px;margin-bottom:12px"><div><b style="font-size:18px">${esc(b.meta.name)}</b><div>${E.KINDS[e.kind]}</div></div><div style="text-align:left">رقم: <b>${e.no}</b><br>التاريخ: ${e.date}${e.ref ? '<br>مستند: ' + esc(e.ref) : ''}</div></div>
      <p style="font-size:16px">المبلغ: <b>${E.fmt(tot)} ${esc(U.symOf())}</b></p>
      <p>البيان: ${esc(e.memo || '')}</p>
      <table style="width:100%;border-collapse:collapse;margin:10px 0" border="1" cellpadding="6"><tr><th>من حساب (دائن)</th><th>إلى حساب (مدين)</th></tr><tr><td>${c.map(nm).join('<br>')}</td><td>${d.map(nm).join('<br>')}</td></tr></table>
      <div style="display:flex;justify-content:space-between;margin-top:46px"><span>توقيع المستلم: ............</span><span>توقيع المحاسب: ............</span></div></div>`;
    document.body.appendChild(w);
    document.body.classList.add('printing-v');
    const done = () => { document.body.classList.remove('printing-v'); w.remove(); window.removeEventListener('afterprint', done); };
    window.addEventListener('afterprint', done);
    window.print();
    setTimeout(() => { if (document.body.classList.contains('printing-v')) done(); }, 60000);
  }

  // ———————————— دفتر اليوميّة ————————————
  const jState = { p: 'all', from: '', to: '', kind: '', q: '', acc: '', n: 150 };
  V.journal = function (el) {
    const b = B();
    const list = E.journal(b, jState);
    const shown = list.slice(0, jState.n);
    const total = list.reduce((s, e) => s + E.amountOf(e), 0);
    const byDay = {};
    shown.forEach((e) => (byDay[e.date] = byDay[e.date] || []).push(e));
    el.innerHTML = `
      <div class="ph"><div><h1>القيود والسندات</h1><div class="sub">دفتر اليوميّة — كلّ حركة بالتسلسل</div></div>
        <div class="row"><button class="btn" data-csv>${ic('dl')} Excel</button><a class="btn pri" href="#/new">${ic('plus')} سند جديد</a></div></div>
      ${U.printHead('دفتر اليوميّة', U.periodLabel(jState))}
      <div class="stack">
        <div class="row noprint">${U.periodBar(jState)}
          <select class="in" data-kind style="width:auto"><option value="">كلّ الأنواع</option>${Object.entries(E.KINDS).map(([k, n]) => '<option value="' + k + '"' + (jState.kind === k ? ' selected' : '') + '>' + n + '</option>').join('')}</select>
          <input class="in grow" data-q placeholder="ابحث بالبيان أو المبلغ أو الحساب أو #رقم" value="${esc(jState.q)}" style="min-width:180px"></div>
        <div class="hint">${list.length} قيد · مجموع ${E.fmt(total)} ${esc(U.symOf())}</div>
        ${Object.keys(byDay).length ? Object.entries(byDay).map(([d, es]) => '<div class="card" style="padding:4px 14px"><div class="hint" style="padding:8px 0 2px;font-weight:600">' + d + ' · ' + new Date(d).toLocaleDateString('ar-IQ-u-nu-latn', { weekday: 'long' }) + '</div>' + V.entryList(es) + '</div>').join('') : '<div class="card"><div class="empty"><b>ماكو قيود</b>غيّر الفلتر أو سجّل سند جديد.</div></div>'}
        ${list.length > jState.n ? '<button class="btn block" data-more>عرض المزيد (' + (list.length - jState.n) + ')</button>' : ''}
      </div>`;
    U.bindPeriod(el, jState, () => V.journal(el));
    $('[data-kind]', el).onchange = (e) => { jState.kind = e.target.value; V.journal(el); };
    const q = $('[data-q]', el);
    let t; q.oninput = () => { clearTimeout(t); t = setTimeout(() => { jState.q = q.value; V.journal(el); const n = $('[data-q]', el); n.focus(); n.setSelectionRange(n.value.length, n.value.length); }, 250); };
    const more = $('[data-more]', el); if (more) more.onclick = () => { jState.n += 300; V.journal(el); };
    $('[data-csv]', el).onclick = () => {
      const rows = [];
      list.slice().reverse().forEach((e) => e.lines.forEach((l) => rows.push([e.no, e.date, E.KINDS[e.kind], e.memo, (E.acc(b, l.a) || {}).code, (E.acc(b, l.a) || {}).name, l.dr || '', l.cr || '', l.cur, l.rate, l.cc ? (E.acc(b, l.cc) || {}).name : '', e.ref])));
      U.exportCSV('دفتر-اليومية', ['رقم', 'التاريخ', 'النوع', 'البيان', 'رقم الحساب', 'الحساب', 'مدين', 'دائن', 'العملة', 'السعر', 'على حساب', 'المستند'], rows);
    };
    V.bindCommon(el);
  };
})();
