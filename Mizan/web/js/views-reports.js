/* ميزان — ديوني، الرحلات، والتقارير الماليّة */
(function () {
  'use strict';
  const E = window.Engine, U = window.UI;
  const { $, $$, esc, ic, av, M } = U;
  const B = () => window.Store.book;
  const V = (window.Views = window.Views || {});
  const go = (h) => (location.hash = h);
  const daysTo = (d) => Math.round((Date.parse(d) - Date.parse(E.today())) / 864e5);

  // ———————————— ديوني ————————————
  V.debts = function (el, p) {
    const b = B();
    const side = p[0] === 'theirs' ? 'theirs' : 'mine';
    const d = E.debts(b);
    const list = d[side];
    const dueTxt = (x) => {
      if (!x.due) return x.since ? 'من ' + x.since : '';
      const n = daysTo(x.due);
      return n < 0 ? '<span class="pill neg">متأخّر ' + -n + ' يوم</span>' : n === 0 ? '<span class="pill warn">يستحقّ اليوم</span>' : n <= 7 ? '<span class="pill warn">باقي ' + n + ' أيّام</span>' : '<span class="hint">يستحقّ ' + x.due + '</span>';
    };
    el.innerHTML = `
      <div class="ph"><div><h1>ديوني</h1><div class="sub">منو عليه فلوس إلي، ومنو إله فلوس عليّ — مع مواعيد السداد</div></div>
        <div class="row"><button class="btn" data-lend>${ic('out')} سلّفت شخص</button><button class="btn" data-borrow>${ic('in')} استلفت من شخص</button></div></div>
      <div class="stack">
        <div class="kpis" style="grid-template-columns:repeat(3,1fr)">
          <div class="kpi" data-side="mine" style="cursor:pointer;${side === 'mine' ? 'border-color:var(--dr)' : ''}"><div class="l">لي عند الناس</div><div class="v drc">${M(d.totalMine)}</div><div class="d">${d.mine.length} شخص</div></div>
          <div class="kpi" data-side="theirs" style="cursor:pointer;${side === 'theirs' ? 'border-color:var(--cr)' : ''}"><div class="l">عليّ للناس</div><div class="v crc">${M(d.totalTheirs)}</div><div class="d">${d.theirs.length} شخص</div></div>
          <div class="kpi"><div class="l">متأخّر عن موعده</div><div class="v ${d.overdue ? 'neg' : 'zero'}">${M(d.overdue)}</div><div class="d">الصافي ${E.fmt(d.totalMine - d.totalTheirs)}</div></div></div>
        <div class="seg"><button data-side="mine" class="${side === 'mine' ? 'on' : ''}">لي عندهم</button><button data-side="theirs" class="${side === 'theirs' ? 'on' : ''}">عليّ إلهم</button></div>
        <div class="card" style="padding:6px 14px">${list.length ? '<div class="list">' + list.map((x) => {
          const a = E.acc(b, x.id);
          return '<div class="li" data-acc="' + x.id + '">' + av(a) + '<div class="grow" style="min-width:0"><div class="t">' + esc(x.name) + '</div><div class="s">' + dueTxt(x) + (x.open.length > 1 ? ' · ' + x.open.length + ' دفعات مفتوحة' : '') + '</div></div>' +
            '<div class="amt"><b class="' + (side === 'mine' ? 'drc' : 'crc') + '">' + M(x.amt, x.cur) + '</b><div class="row" style="gap:2px;justify-content:flex-end">' +
            '<button class="icon-btn" data-pay="' + x.id + '" title="' + (side === 'mine' ? 'سدّد لي' : 'سدّدته') + '">' + ic('check') + '</button>' + (x.phone ? '<button class="icon-btn" data-wa="' + x.id + '" title="تذكير واتساب">' + ic('wa') + '</button>' : '') + '</div></div></div>';
        }).join('') + '</div>' : '<div class="empty"><b>' + (side === 'mine' ? 'ماكو أحد عليه فلوس إلك' : 'ما عليك فلوس لأحد') + '</b>سجّل سلفة أو دين من الأزرار فوق.</div>'}</div>
        <div class="hint">التسديد يُحسب على الأقدم أوّلًا. أيّ حساب (زبون، مورد، موظّف، شخص) رصيده مو صفر يطلع هنا.</div>
      </div>`;
    $$('[data-side]', el).forEach((x) => (x.onclick = () => go('#/debts/' + x.dataset.side)));
    $('[data-lend]', el).onclick = () => quickDebt('lend');
    $('[data-borrow]', el).onclick = () => quickDebt('borrow');
    el.onclick = (e) => {
      const pay = e.target.closest('[data-pay]');
      if (pay) { e.stopPropagation(); const x = list.find((r) => r.id === pay.dataset.pay); V.prefill = { kind: side === 'mine' ? 'receipt' : 'payment', account: x.id, amount: x.amt, cur: x.cur, memo: (side === 'mine' ? 'تسديد من ' : 'تسديد إلى ') + x.name }; V.returnTo = location.hash; return go('#/new/' + V.prefill.kind); }
      const wa = e.target.closest('[data-wa]');
      if (wa) {
        e.stopPropagation(); const x = list.find((r) => r.id === wa.dataset.wa);
        const txt = side === 'mine' ? 'هلا ' + x.name + '، تذكير لطيف: باقي بذمّتك ' + E.fmt(x.amt) + ' ' + U.symOf(x.cur) + (x.due ? ' (موعدها ' + x.due + ')' : '') + '. شكرًا 🌷'
          : 'هلا ' + x.name + '، بخصوص المبلغ ' + E.fmt(x.amt) + ' ' + U.symOf(x.cur) + ' اللي إلك عندي' + (x.due ? '، موعده ' + x.due : '') + '. راح أرتّبه إن شاء الله.';
        return window.open('https://wa.me/' + x.phone.replace(/\D/g, '').replace(/^0/, '964') + '?text=' + encodeURIComponent(txt), '_blank');
      }
      const a = e.target.closest('[data-acc]'); if (a) go('#/acc/' + a.dataset.acc);
    };
  };

  /** سلّفت / استلفت بخطوة وحدة: اختار شخص (أو سوّي جديد) ثمّ السند جاهز */
  async function quickDebt(kind) {
    const a = await U.pickAccount({ title: kind === 'lend' ? 'سلّفت منو؟' : 'استلفت من منو؟', filter: (x) => ['person', 'customer', 'supplier', 'employee', 'partner', 'loan'].includes(x.sub), newSub: 'person', newSubs: ['person', 'customer', 'supplier', 'employee', 'loan'] });
    if (!a) return;
    const due = new Date(); due.setMonth(due.getMonth() + 1);
    V.prefill = { kind: kind === 'lend' ? 'payment' : 'receipt', account: a.id, memo: (kind === 'lend' ? 'سلفة إلى ' : 'دين من ') + a.name, due: U.iso(due) };
    V.returnTo = '#/debts/' + (kind === 'lend' ? 'mine' : 'theirs');
    go('#/new/' + V.prefill.kind);
  }

  // ———————————— الرحلات ————————————
  V.trips = function (el) {
    const b = B();
    const trips = b.accounts.filter((a) => !a.group && a.sub === 'trip' && !a.archived).map((a) => E.tripReport(b, a.id)).sort((x, y) => (y.acc.start || y.acc.created || '').localeCompare(x.acc.start || x.acc.created || ''));
    el.innerHTML = `
      <div class="ph"><div><h1>مصاريف السفر</h1><div class="sub">كلّ رحلة إلها محفظة وميزانيّة، وتشوف وين راحت كلّ فلس</div></div><button class="btn pri" data-new>${ic('plus')} رحلة جديدة</button></div>
      ${trips.length ? '<div class="rep-grid" style="grid-template-columns:repeat(auto-fill,minmax(280px,1fr))">' + trips.map((t) => {
        const pct = t.pct == null ? null : Math.min(100, t.pct);
        return `<div class="card rep" data-trip="${t.acc.id}" style="flex-direction:column;align-items:stretch;gap:10px">
          <div class="row" style="flex-wrap:nowrap">${av(t.acc)}<div class="grow" style="min-width:0"><b>${esc(t.acc.name)}</b><span>${esc([t.acc.place, t.acc.start && t.acc.start + (t.acc.end ? ' ← ' + t.acc.end : ''), t.people > 1 ? t.people + ' أشخاص' : ''].filter(Boolean).join(' · ') || '—')}</span></div></div>
          <div class="row between"><span class="hint">المصروف</span><b>${M(t.spent, t.cur)}</b></div>
          ${pct != null ? `<div class="hbar" style="grid-template-columns:1fr auto;padding:0"><span class="bar"><i class="${t.pct > 100 ? '' : 'g'}" style="width:${pct}%"></i></span><span class="num hint">${Math.round(t.pct)}٪ من ${E.fmt(t.budget)}</span></div>` : ''}
          <div class="row between"><span class="hint">باقي بالمحفظة</span><span>${M(t.wallet, t.cur)}</span></div></div>`;
      }).join('') + '</div>' : `<div class="card"><div class="empty"><b>ماكو رحلات بعد</b>سوّي رحلة، حوّل إلها فلوس (دولار مثلًا)، وكلّ ما تصرف سجّل المصروف منها — تطلعلك الخلاصة لحالها.</div></div>`}`;
    $('[data-new]', el).onclick = async () => { const a = await V.accountForm(null, { sub: 'trip', subs: ['trip'] }); if (a) go('#/trip/' + a.id); };
    el.onclick = (e) => { const t = e.target.closest('[data-trip]'); if (t) go('#/trip/' + t.dataset.trip); };
  };

  V.trip = function (el, p) {
    const b = B();
    const a = E.acc(b, p[0]);
    if (!a) { el.innerHTML = '<div class="empty"><b>الرحلة غير موجودة</b></div>'; return; }
    const t = E.tripReport(b, a.id);
    const C = t.cur;
    const over = t.left != null && t.left < 0;
    const maxDay = Math.max(1, ...t.byDay.map((x) => x.amt));
    el.innerHTML = `
      <div class="crumb noprint"><a href="#/trips">مصاريف السفر</a></div>
      ${U.printHead('تقرير رحلة: ' + a.name)}
      <div class="card" style="margin-bottom:16px"><div class="acc-head">${av(a)}<div><h1 style="margin:0;font-size:22px">${esc(a.name)}</h1><div class="hint">${esc([a.place, a.start && a.start + (a.end ? ' ← ' + a.end : ''), t.days + ' يوم', t.people + ' مسافر', C].filter(Boolean).join(' · '))}</div></div>
        <div class="balbox"><div class="l">صرفنا</div><div class="v">${M(t.spent, C)}</div>${t.budget ? '<div class="l ' + (over ? 'neg' : '') + '">' + (over ? 'عبرنا الميزانيّة بـ ' + E.fmt(-t.left) : 'باقي من الميزانيّة ' + E.fmt(t.left)) + '</div>' : ''}</div></div>
        ${t.budget ? `<div class="hbar" style="grid-template-columns:1fr auto;margin-top:12px"><span class="bar" style="height:12px"><i class="${over ? '' : 'g'}" style="width:${Math.min(100, t.pct)}%"></i></span><span class="num">${Math.round(t.pct)}٪</span></div>` : ''}
        <div class="qa noprint" style="margin-top:14px">
          <button class="btn sm pri" data-q="exp">${ic('tag')} مصروف من الرحلة</button><button class="btn sm" data-q="fund">${ic('swap')} حوّل للمحفظة</button>
          <button class="btn sm" data-q="other">${ic('cash')} مصروف للرحلة من صندوق ثاني</button><span class="grow"></span>
          <button class="btn sm ghost" data-print>${ic('print')} طباعة</button><a class="btn sm ghost" href="#/acc/${a.id}/st">${ic('list')} كشف المحفظة</a><button class="btn sm ghost" data-edit>${ic('edit')} تعديل</button></div></div>
      <div class="kpis">
        <div class="kpi"><div class="l">حطّينا بالمحفظة</div><div class="v">${M(t.funded, C)}</div></div>
        <div class="kpi"><div class="l">باقي بالمحفظة</div><div class="v ${t.wallet < 0 ? 'neg' : ''}">${M(t.wallet, C)}</div></div>
        <div class="kpi"><div class="l">معدّل اليوم</div><div class="v">${M(t.perDay, C)}</div></div>
        <div class="kpi"><div class="l">حصّة كلّ مسافر</div><div class="v">${M(t.perPerson, C)}</div><div class="d">${t.people} مسافر</div></div></div>
      <div class="cols" style="margin-top:16px">
        <div class="stack">
          <div class="card"><h3>وين راحت الفلوس</h3>${t.byCat.length ? U.donut(t.byCat, t.spent) + '<div style="margin-top:12px">' + U.hbars(t.byCat, t.spent) + '</div>' : '<div class="empty"><b>ماكو مصاريف بعد</b>اضغط «مصروف من الرحلة».</div>'}</div>
          <div class="card"><h3>كلّ المصاريف</h3>${t.rows.length ? '<div class="tw"><table class="t"><thead><tr><th>اليوم</th><th>النوع</th><th>البيان</th><th class="n">' + esc(U.symOf(C)) + '</th></tr></thead><tbody>' +
            t.rows.slice().reverse().map((r) => '<tr data-e="' + r.e + '"><td class="num">' + r.date + '</td><td>' + esc(r.cat) + '</td><td class="memo">' + esc(r.memo || '') + '</td><td class="n">' + E.fmt(r.amt, 2).replace(/\.00$/, '') + '</td></tr>').join('') + '</tbody></table></div>' : '<div class="empty">—</div>'}</div>
        </div>
        <div class="card"><h3>كلّ يوم</h3>${t.byDay.length ? t.byDay.map((x) => '<div class="hbar"><span class="nm num">' + x.d.slice(5) + ' · ' + new Date(x.d).toLocaleDateString('ar-IQ-u-nu-latn', { weekday: 'short' }) + '</span><span class="bar"><i style="width:' + (x.amt / maxDay * 100) + '%"></i></span><span class="num">' + E.fmt(x.amt, 0) + '</span></div>').join('') : '<div class="empty">—</div>'}</div>
      </div>`;
    const travelFirst = (x) => x.type === 'expense';
    void travelFirst;
    $$('[data-q]', el).forEach((x) => (x.onclick = () => {
      const k = x.dataset.q;
      V.returnTo = '#/trip/' + a.id;
      if (k === 'exp') { V.prefill = { kind: 'expense', from: a.id, cc: a.id, cur: a.cur }; go('#/new/expense'); }
      else if (k === 'fund') { V.prefill = { kind: 'transfer', to: a.id, memo: 'تمويل ' + a.name }; go('#/new/transfer'); }
      else { V.prefill = { kind: 'expense', cc: a.id, cat: 'a5201' }; go('#/new/expense'); }
    }));
    $('[data-print]', el).onclick = () => window.print();
    $('[data-edit]', el).onclick = async () => { if (await V.accountForm(a)) V.trip(el, [a.id]); };
    V.bindCommon(el);
  };

  // ———————————— التقارير ————————————
  const R = {
    trial: ['scale', 'ميزان المراجعة', 'كلّ الحسابات بالمدين والدائن — يتأكّد إنّ الدفاتر مضبوطة'],
    income: ['chart', 'قائمة الدخل (الأرباح والخسائر)', 'الإيرادات ناقص المصروفات لأيّ فترة أو أيّ حساب'],
    balance: ['book', 'الميزانيّة العموميّة', 'شنو عندك وشنو عليك بتاريخ معيّن'],
    cash: ['cash', 'التدفّق النقديّ', 'الفلوس اللي دخلت وطلعت من الصناديق ومنين'],
    aging: ['cal', 'أعمار الديون', 'ديون الزبائن حسب قدمها (٣٠/٦٠/٩٠ يوم)'],
    expenses: ['tag', 'تحليل المصاريف', 'حسب النوع أو حسب الحساب، مع النسب'],
    centers: ['brief', 'ربحيّة الحسابات والمشاريع', 'كلّ حساب: شكد صرف عليه وشكد جاب وصافيه'],
    monthly: ['bolt', 'الأداء الشهريّ', 'كلّ شهر: إيراد ومصروف وصافي ونسبة الربح'],
    balances: ['users', 'أرصدة الحسابات', 'قائمة كلّ الحسابات وأرصدتها بتاريخ'],
  };
  V.reports = function (el) {
    el.innerHTML = '<div class="ph"><div><h1>التقارير</h1><div class="sub">كلّ تقرير يطبع PDF ويتصدّر Excel</div></div></div><div class="rep-grid">' +
      Object.entries(R).map(([k, [i, n, d]]) => '<div class="card rep" data-go="#/report/' + k + '"><span class="av">' + ic(i) + '</span><div><b>' + n + '</b><span>' + d + '</span></div></div>').join('') +
      '<div class="card rep" data-go="#/debts"><span class="av">' + ic('coins') + '</span><div><b>ديوني</b><span>لي وعليّ مع مواعيد السداد</span></div></div>' +
      '<div class="card rep" data-go="#/trips"><span class="av">' + ic('plane') + '</span><div><b>مصاريف السفر</b><span>كلّ رحلة وميزانيّتها</span></div></div>' +
      '<div class="card rep" data-go="#/journal"><span class="av">' + ic('list') + '</span><div><b>دفتر اليوميّة</b><span>كلّ القيود بالتسلسل</span></div></div></div>';
    V.bindCommon(el);
  };

  const st = { p: 'year', from: '', to: '', cc: '', by: 'cat', hideZero: true, side: 'recv', months: 12 };
  Object.assign(st, U.period('year'));
  V.report = function (el, p) {
    const b = B();
    const k = p[0];
    if (k === 'aging' && p[1] === 'pay') st.side = 'pay';
    const meta = R[k];
    if (!meta) return go('#/reports');
    const asOf = k === 'balance' || k === 'balances' || k === 'aging';
    const base = b.meta.base;
    let body = '', csv = null, extra = '';
    if (k === 'trial') {
      const tb = E.trialBalance(b, { from: st.from, to: st.to, hideZero: st.hideZero });
      extra = '<label class="chk hint"><input type="checkbox" data-hz ' + (st.hideZero ? 'checked' : '') + '> أخفي الأصفار</label>';
      body = `<div class="tw"><table class="t"><thead><tr><th>رقم</th><th>الحساب</th><th class="n">رصيد سابق</th><th class="n">مدين الفترة</th><th class="n">دائن الفترة</th><th class="n">رصيد مدين</th><th class="n">رصيد دائن</th></tr></thead><tbody>
        ${tb.rows.map((r) => `<tr class="${r.group ? 'grp' : ''}" ${r.group ? '' : 'data-go="#/acc/' + r.id + '"'}><td class="num muted">${r.code}</td><td><span style="padding-inline-start:${r.depth * 14}px" class="ind">${esc(r.name)}</span></td><td class="n">${r.open ? E.fmt(r.open) : ''}</td><td class="n">${r.dr ? E.fmt(r.dr) : ''}</td><td class="n">${r.cr ? E.fmt(r.cr) : ''}</td><td class="n">${r.cdr ? E.fmt(r.cdr) : ''}</td><td class="n">${r.ccr ? E.fmt(r.ccr) : ''}</td></tr>`).join('')}</tbody>
        <tfoot><tr><td></td><td>المجموع ${tb.tot.balanced ? '<span class="pill pos">' + ic('check').replace('<svg', '<svg style="width:13px;display:inline"') + ' متوازن</span>' : '<span class="pill neg">غير متوازن!</span>'}</td><td></td><td class="n">${E.fmt(tb.tot.dr)}</td><td class="n">${E.fmt(tb.tot.cr)}</td><td class="n">${E.fmt(tb.tot.cdr)}</td><td class="n">${E.fmt(tb.tot.ccr)}</td></tr></tfoot></table></div>`;
      csv = [['رقم', 'الحساب', 'مجموعة', 'رصيد سابق', 'مدين', 'دائن', 'رصيد مدين', 'رصيد دائن'], tb.rows.map((r) => [r.code, r.name, r.group ? 'نعم' : '', r.open, r.dr, r.cr, r.cdr, r.ccr])];
    } else if (k === 'income') {
      const is = E.incomeStatement(b, { from: st.from, to: st.to, cc: st.cc });
      extra = U.pickBtn('rcc', E.acc(b, st.cc), 'كلّ الحسابات') + (st.cc ? '<button class="icon-btn" data-ccx>' + ic('x') + '</button>' : '');
      const sec = (title, rows, tot, cls) => '<div class="card"><h3>' + title + '<small class="num ' + cls + '">' + E.fmt(tot) + '</small></h3>' + (rows.map((r) => '<div class="sumrow" data-go="#/acc/' + r.id + '" style="cursor:pointer"><span>' + esc(r.name) + ' <small class="hint">' + esc(r.parent || '') + '</small></span><span class="num">' + E.fmt(r.amt) + ' <small class="hint">' + (tot ? Math.round(r.amt / tot * 100) : 0) + '٪</small></span></div>').join('') || '<div class="empty">—</div>') + '</div>';
      body = `<div class="cols">${sec('الإيرادات', is.revenues, is.totalRev, 'pos')}${sec('المصروفات', is.expenses, is.totalExp, 'neg')}</div>
        <div class="card" style="margin-top:16px"><div class="sumrow"><span>إجمالي الإيرادات</span><b class="num pos">${E.fmt(is.totalRev)}</b></div><div class="sumrow"><span>إجمالي المصروفات</span><b class="num neg">(${E.fmt(is.totalExp)})</b></div>
        <div class="sumrow tot"><span>${is.net >= 0 ? 'صافي الربح' : 'صافي الخسارة'}</span><span class="num ${is.net >= 0 ? 'pos' : 'neg'}">${E.fmt(is.net)} ${esc(U.symOf())}</span></div><div class="hint" style="margin-top:6px">هامش الربح ${is.margin}٪</div></div>`;
      csv = [['البند', 'الحساب', 'المبلغ'], is.revenues.map((r) => ['إيراد', r.name, r.amt]).concat(is.expenses.map((r) => ['مصروف', r.name, r.amt]), [['صافي', '', is.net]])];
    } else if (k === 'balance') {
      const bs = E.balanceSheet(b, { to: st.to });
      const sec = (title, s, cls) => '<div class="card"><h3>' + title + '<small class="num">' + E.fmt(s.total) + '</small></h3>' + (s.rows.map((r) => '<div class="sumrow" style="' + (r.group ? 'font-weight:700' : 'cursor:pointer') + '" ' + (r.group ? '' : 'data-go="#/acc/' + r.id + '"') + '><span style="padding-inline-start:' + r.depth * 14 + 'px">' + esc(r.name) + '</span><span class="num ' + (r.amt < 0 ? 'neg' : '') + '">' + E.fmt(r.amt) + '</span></div>').join('') || '<div class="empty">—</div>') + '</div>';
      body = `<div class="cols"><div class="stack">${sec('الأصول (اللي عندك)', bs.assets)}</div><div class="stack">${sec('الالتزامات (اللي عليك)', bs.liab)}${sec('حقوق الملكيّة', bs.equity)}
        <div class="card"><div class="sumrow"><span>أرباح الفترة (غير مقفلة)</span><b class="num ${bs.profit >= 0 ? 'pos' : 'neg'}">${E.fmt(bs.profit)}</b></div></div></div></div>
        <div class="card" style="margin-top:16px"><div class="sumrow"><span>مجموع الأصول</span><b class="num">${E.fmt(bs.totalAssets)}</b></div><div class="sumrow"><span>الالتزامات + الحقوق + الأرباح</span><b class="num">${E.fmt(bs.totalRight)}</b></div>
        <div class="sumrow tot"><span>${bs.balanced ? 'الميزانيّة متوازنة ✓' : 'غير متوازنة!'}</span><span class="${bs.balanced ? 'pos' : 'neg'} num">${E.fmt(bs.totalAssets - bs.totalRight)}</span></div></div>`;
      csv = [['القسم', 'الحساب', 'المبلغ'], bs.assets.rows.map((r) => ['أصول', r.name, r.amt]).concat(bs.liab.rows.map((r) => ['التزامات', r.name, r.amt]), bs.equity.rows.map((r) => ['حقوق', r.name, r.amt]), [['أرباح الفترة', '', bs.profit]])];
    } else if (k === 'cash') {
      const cf = E.cashFlow(b, { from: st.from, to: st.to });
      body = `<div class="kpis"><div class="kpi"><div class="l">أوّل الفترة</div><div class="v">${M(cf.opening)}</div></div><div class="kpi"><div class="l">دخل</div><div class="v pos">${M(cf.inflow)}</div></div><div class="kpi"><div class="l">طلع</div><div class="v neg">${M(cf.outflow)}</div></div><div class="kpi hero"><div class="l">آخر الفترة</div><div class="v">${M(cf.closing)}</div></div></div>
        <div class="tw" style="margin-top:16px"><table class="t"><thead><tr><th>المصدر</th><th class="n">دخل</th><th class="n">طلع</th><th class="n">الصافي</th></tr></thead><tbody>${cf.groups.map((g) => '<tr><td>' + g.label + '</td><td class="n pos">' + (g.inn ? E.fmt(g.inn) : '') + '</td><td class="n neg">' + (g.out ? E.fmt(g.out) : '') + '</td><td class="n"><b>' + E.fmt(g.net) + '</b></td></tr>').join('') || '<tr><td colspan="4"><div class="empty">—</div></td></tr>'}</tbody>
        <tfoot><tr><td>الصافي</td><td class="n">${E.fmt(cf.inflow)}</td><td class="n">${E.fmt(cf.outflow)}</td><td class="n">${E.fmt(cf.inflow - cf.outflow)}</td></tr></tfoot></table></div>
        <div class="hint" style="margin-top:8px">التحويلات بين صناديقك ما تنحسب (فلوسك نفسها). الحساب: الصناديق والمصارف فقط.</div>`;
      csv = [['المصدر', 'دخل', 'طلع', 'صافي'], cf.groups.map((g) => [g.label, g.inn, g.out, g.net])];
    } else if (k === 'aging') {
      const ag = E.aging(b, { side: st.side, to: st.to });
      const tot = [0, 1, 2, 3].map((i) => ag.reduce((s, x) => s + x.b[i], 0));
      extra = '<div class="seg"><button data-side="recv" class="' + (st.side !== 'pay' ? 'on' : '') + '">لنا عندهم</button><button data-side="pay" class="' + (st.side === 'pay' ? 'on' : '') + '">علينا إلهم</button></div>';
      body = `<div class="tw"><table class="t"><thead><tr><th>الحساب</th><th class="n">≤ ٣٠ يوم</th><th class="n">٣١–٦٠</th><th class="n">٦١–٩٠</th><th class="n">> ٩٠</th><th class="n">المجموع</th></tr></thead><tbody>
        ${ag.map((x) => '<tr data-go="#/acc/' + x.id + '"><td>' + esc(x.name) + (x.cur !== base ? ' <small class="hint">' + x.cur + '</small>' : '') + '</td>' + x.b.map((v, i) => '<td class="n ' + (i === 3 && v ? 'neg' : '') + '">' + (v ? E.fmt(v) : '') + '</td>').join('') + '<td class="n"><b>' + E.fmt(x.total) + '</b></td></tr>').join('') || '<tr><td colspan="6"><div class="empty">ماكو ديون مفتوحة 👌</div></td></tr>'}</tbody>
        <tfoot><tr><td>المجموع</td>${tot.map((v) => '<td class="n">' + E.fmt(v) + '</td>').join('')}<td class="n">${E.fmt(tot.reduce((s, v) => s + v, 0))}</td></tr></tfoot></table></div>`;
      csv = [['الحساب', '0-30', '31-60', '61-90', '90+', 'المجموع'], ag.map((x) => [x.name].concat(x.b, [x.total]))];
    } else if (k === 'expenses') {
      const ex = E.expensesBy(b, { from: st.from, to: st.to, by: st.by });
      extra = '<div class="seg"><button data-by="cat" class="' + (st.by === 'cat' ? 'on' : '') + '">حسب النوع</button><button data-by="cc" class="' + (st.by === 'cc' ? 'on' : '') + '">حسب الحساب</button></div>';
      body = `<div class="cols"><div class="card"><h3>المجموع <small class="num">${E.fmt(ex.total)} ${esc(U.symOf())}</small></h3>${U.hbars(ex.rows.map((r) => Object.assign({}, r, { id: r.id === '—' ? '' : r.id })), ex.total)}</div><div class="card"><h3>التوزيع</h3>${ex.rows.length ? U.donut(ex.rows, ex.total) : '<div class="empty">—</div>'}</div></div>`;
      csv = [['البند', 'المبلغ', 'النسبة'], ex.rows.map((r) => [r.name, r.amt, r.pct])];
    } else if (k === 'centers') {
      const rows = b.accounts.filter((a) => !a.group && !a.archived && a.type !== 'expense' && a.type !== 'revenue' && !['cash', 'bank'].includes(a.sub)).map((a) => ({ a, r: E.centerReport(b, a.id, { from: st.from, to: st.to }) })).filter((x) => x.r.rows.length).sort((x, y) => y.r.profit - x.r.profit);
      body = `<div class="tw"><table class="t"><thead><tr><th>الحساب</th><th class="n">الإيرادات</th><th class="n">المصاريف</th><th class="n">الصافي</th><th class="hide-m">أكبر مصروف</th></tr></thead><tbody>
        ${rows.map((x) => '<tr data-go="#/acc/' + x.a.id + '/exp"><td>' + esc(x.a.name) + ' <small class="hint">' + esc((E.SUBS[x.a.sub] || {}).name || '') + '</small></td><td class="n pos">' + E.fmt(x.r.totalRev) + '</td><td class="n neg">' + E.fmt(x.r.totalExp) + '</td><td class="n"><b class="' + (x.r.profit >= 0 ? 'pos' : 'neg') + '">' + E.fmt(x.r.profit) + '</b></td><td class="hide-m muted">' + esc((x.r.expenses[0] || {}).name || '—') + '</td></tr>').join('') || '<tr><td colspan="5"><div class="empty"><b>ماكو حركات محمّلة على حسابات</b>بالسندات اختار «على حساب» حتى يطلع هنا.</div></td></tr>'}</tbody></table></div>`;
      csv = [['الحساب', 'إيرادات', 'مصاريف', 'صافي'], rows.map((x) => [x.a.name, x.r.totalRev, x.r.totalExp, x.r.profit])];
    } else if (k === 'monthly') {
      const mo = E.monthly(b, { months: st.months, to: st.to || undefined });
      const t = mo.reduce((s, m) => ({ rev: s.rev + m.rev, exp: s.exp + m.exp }), { rev: 0, exp: 0 });
      extra = '<select class="in" data-months style="width:auto">' + [6, 12, 24].map((n) => '<option value="' + n + '"' + (st.months === n ? ' selected' : '') + '>آخر ' + n + ' شهر</option>').join('') + '</select>';
      body = `<div class="card">${U.barChart(mo)}</div><div class="tw" style="margin-top:16px"><table class="t"><thead><tr><th>الشهر</th><th class="n">إيرادات</th><th class="n">مصروفات</th><th class="n">الصافي</th><th class="n">الهامش</th></tr></thead><tbody>
        ${mo.slice().reverse().map((m) => '<tr><td>' + U.monName(m.k) + ' ' + m.k.slice(0, 4) + '</td><td class="n pos">' + E.fmt(m.rev) + '</td><td class="n neg">' + E.fmt(m.exp) + '</td><td class="n"><b class="' + (m.net >= 0 ? 'pos' : 'neg') + '">' + E.fmt(m.net) + '</b></td><td class="n muted">' + (m.rev ? Math.round(m.net / m.rev * 100) + '٪' : '—') + '</td></tr>').join('')}</tbody>
        <tfoot><tr><td>المجموع</td><td class="n">${E.fmt(t.rev)}</td><td class="n">${E.fmt(t.exp)}</td><td class="n">${E.fmt(t.rev - t.exp)}</td><td class="n">${t.rev ? Math.round((t.rev - t.exp) / t.rev * 100) + '٪' : '—'}</td></tr></tfoot></table></div>`;
      csv = [['الشهر', 'إيرادات', 'مصروفات', 'صافي'], mo.map((m) => [m.k, m.rev, m.exp, m.net])];
    } else if (k === 'balances') {
      const rows = b.accounts.filter((a) => !a.group && !a.archived).map((a) => ({ a, x: E.balance(b, a.id, { to: st.to }) })).filter((r) => !st.hideZero || Math.abs(r.x.base) > 0.005).sort((x, y) => (x.a.code < y.a.code ? -1 : 1));
      extra = '<label class="chk hint"><input type="checkbox" data-hz ' + (st.hideZero ? 'checked' : '') + '> أخفي الأصفار</label>';
      body = `<div class="tw"><table class="t"><thead><tr><th>رقم</th><th>الحساب</th><th class="hide-m">النوع</th><th class="n">الرصيد</th><th></th><th class="n hide-m">بالعملة الأساسيّة</th></tr></thead><tbody>
        ${rows.map((r) => { const sd = E.side(r.a, r.x.own); return '<tr data-go="#/acc/' + r.a.id + '"><td class="num muted">' + r.a.code + '</td><td>' + esc(r.a.name) + '</td><td class="hide-m muted">' + esc((E.SUBS[r.a.sub] || {}).name || E.TYPES[r.a.type].name) + '</td><td class="n">' + E.money(b, Math.abs(r.x.own), r.a.cur) + ' <small class="hint">' + esc(U.symOf(r.a.cur)) + '</small></td><td class="' + sd.cls + 'c">' + sd.word + '</td><td class="n hide-m muted">' + E.fmt(r.x.base) + '</td></tr>'; }).join('')}</tbody></table></div>`;
      csv = [['رقم', 'الحساب', 'النوع', 'الرصيد', 'العملة', 'الوصف', 'بالأساس'], rows.map((r) => [r.a.code, r.a.name, (E.SUBS[r.a.sub] || {}).name, r.x.own, r.a.cur, E.side(r.a, r.x.own).word, r.x.base])];
    }
    el.innerHTML = `<div class="crumb noprint"><a href="#/reports">التقارير</a></div>
      <div class="ph"><div><h1>${meta[1]}</h1><div class="sub">${esc(asOf ? (st.to ? 'بتاريخ ' + st.to : 'لحدّ اليوم') : U.periodLabel(st))}</div></div>
        <div class="row noprint"><button class="btn" data-print>${ic('print')} طباعة / PDF</button>${csv ? '<button class="btn" data-csv>' + ic('dl') + ' Excel</button>' : ''}</div></div>
      ${U.printHead(meta[1], asOf ? (st.to ? 'بتاريخ ' + st.to : '') : U.periodLabel(st))}
      <div class="row noprint" style="margin-bottom:14px">${k === 'monthly' ? '' : U.periodBar(st, { asOf })}${extra}</div>
      <div id="rbody">${body}</div>`;
    const re = () => V.report(el, [k]);
    U.bindPeriod(el, st, re);
    $('[data-print]', el).onclick = () => window.print();
    const c = $('[data-csv]', el); if (c) c.onclick = () => U.exportCSV(meta[1], csv[0], csv[1]);
    const hz = $('[data-hz]', el); if (hz) hz.onchange = () => { st.hideZero = hz.checked; re(); };
    $$('[data-side]', el).forEach((x) => (x.onclick = () => { st.side = x.dataset.side; re(); }));
    $$('[data-by]', el).forEach((x) => (x.onclick = () => { st.by = x.dataset.by; re(); }));
    const mm = $('[data-months]', el); if (mm) mm.onchange = () => { st.months = +mm.value; re(); };
    if ($('#rcc', el)) U.bindPick(el, 'rcc', { filter: (a) => a.type !== 'expense' && a.type !== 'revenue', title: 'قائمة دخل حساب', allowNew: false, ph: 'كلّ الحسابات' }, (a) => { st.cc = a.id; re(); });
    const ccx = $('[data-ccx]', el); if (ccx) ccx.onclick = () => { st.cc = ''; re(); };
    V.bindCommon(el);
  };
})();
