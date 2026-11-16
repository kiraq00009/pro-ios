/* ميزان — محرّك القيد المزدوج (نقيّ، بلا واجهة؛ يشتغل بالمتصفّح وبـ node) */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Engine = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  const TYPES = {
    asset:     { name: 'الأصول',        normal: 1,  code: '1' },
    liability: { name: 'الالتزامات',    normal: -1, code: '2' },
    equity:    { name: 'حقوق الملكيّة', normal: -1, code: '3' },
    revenue:   { name: 'الإيرادات',     normal: -1, code: '4' },
    expense:   { name: 'المصروفات',     normal: 1,  code: '5' },
  };
  // الصفة العمليّة للحساب (تحدّد شكله بالواجهة والسندات المناسبة)
  const SUBS = {
    cash:     { name: 'صندوق',   type: 'asset',     parent: '11' },
    bank:     { name: 'مصرف',    type: 'asset',     parent: '12' },
    customer: { name: 'زبون',    type: 'asset',     parent: '13' },
    employee: { name: 'موظّف',   type: 'asset',     parent: '14' },
    asset:    { name: 'أصل',     type: 'asset',     parent: '16' },
    supplier: { name: 'مورد',    type: 'liability', parent: '21' },
    loan:     { name: 'قرض',     type: 'liability', parent: '22' },
    partner:  { name: 'شريك',    type: 'equity',    parent: '32' },
    project:  { name: 'مشروع',   type: 'asset',     parent: '15' },
    revenue:  { name: 'إيراد',   type: 'revenue',   parent: '41' },
    expense:  { name: 'مصروف',   type: 'expense',   parent: '51' },
    trip:     { name: 'رحلة',    type: 'asset',     parent: '17' },
    person:   { name: 'شخص (ديون)', type: 'asset',  parent: '18' },
    general:  { name: 'عام',     type: 'asset',     parent: '1' },
  };
  const KINDS = {
    receipt:  'سند قبض', payment: 'سند دفع', expense: 'مصروف', income: 'إيراد',
    transfer: 'تحويل', sale: 'بيع آجل', purchase: 'شراء آجل', opening: 'رصيد افتتاحيّ',
    journal: 'قيد يوميّة', closing: 'إقفال سنويّ', profit: 'توزيع أرباح', reverse: 'قيد عكسيّ',
  };

  // ———————————— أدوات ————————————
  const EPS = 0.005;
  const r2 = (n) => Math.round((+n || 0) * 100) / 100;
  const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
  const today = () => new Date().toISOString().slice(0, 10);
  const inRange = (d, from, to) => (!from || d >= from) && (!to || d <= to);

  // ———————————— دفتر جديد بدليل حسابات جاهز ————————————
  function newBook(name, base) {
    base = base || 'IQD';
    const b = {
      v: 1, id: uid(),
      meta: { name: name || 'دفتري', base, created: today(), lockDate: '', yearStart: '01-01' },
      currencies: [
        { code: 'IQD', name: 'دينار عراقيّ', sym: 'د.ع', dec: 0, rate: 1 },
        { code: 'USD', name: 'دولار', sym: '$', dec: 2, rate: 1500 },
        { code: 'EUR', name: 'يورو', sym: '€', dec: 2, rate: 1620 },
      ],
      accounts: [], entries: [], log: [], seq: { entry: 0 },
    };
    if (base !== 'IQD') {
      const bc = b.currencies.find((c) => c.code === base);
      const per = bc ? bc.rate : 1;
      b.currencies.forEach((c) => (c.rate = +(c.rate / per).toPrecision(8)));
      if (!bc) b.currencies.unshift({ code: base, name: base, sym: base, dec: 2, rate: 1 });
      b.currencies.find((c) => c.code === base).rate = 1;
    }
    const G = (code, name, type, parent) => b.accounts.push({ id: 'g' + code, code, name, type, parent: parent ? 'g' + parent : '', group: true });
    const L = (code, name, type, parent, sub, extra) => b.accounts.push(Object.assign({ id: 'a' + code, code, name, type, parent: 'g' + parent, group: false, sub: sub || 'general', cur: base }, extra || {}));
    G('1', 'الأصول', 'asset'); G('11', 'النقديّة والصناديق', 'asset', '1'); G('12', 'المصارف', 'asset', '1');
    G('13', 'الزبائن (ذمم مدينة)', 'asset', '1'); G('14', 'سلف الموظّفين', 'asset', '1'); G('15', 'المشاريع', 'asset', '1');
    G('16', 'الأصول الثابتة', 'asset', '1');
    G('2', 'الالتزامات', 'liability'); G('21', 'الموردين (ذمم دائنة)', 'liability', '2'); G('22', 'القروض', 'liability', '2');
    G('3', 'حقوق الملكيّة', 'equity'); G('31', 'رأس المال', 'equity', '3'); G('32', 'جاري الشركاء', 'equity', '3');
    G('4', 'الإيرادات', 'revenue'); G('41', 'إيرادات النشاط', 'revenue', '4');
    G('5', 'المصروفات', 'expense'); G('51', 'مصروفات التشغيل', 'expense', '5');
    addTravel(b);
    L('1101', 'الصندوق الرئيسيّ', 'asset', '11', 'cash');
    L('3101', 'رأس المال', 'equity', '31', 'general');
    L('3301', 'الأرباح المدوّرة', 'equity', '3', 'general', { system: 'retained' });
    L('3302', 'أرصدة افتتاحيّة', 'equity', '3', 'general', { system: 'opening' });
    L('4101', 'المبيعات', 'revenue', '41', 'revenue');
    L('4102', 'إيرادات أخرى', 'revenue', '41', 'revenue');
    L('4901', 'فروقات صرف', 'revenue', '4', 'revenue', { system: 'fx' });
    [['5101', 'إيجار'], ['5102', 'رواتب وأجور'], ['5103', 'كهرباء وماء'], ['5104', 'وقود ونقل'], ['5105', 'اتّصالات وإنترنت'],
     ['5106', 'صيانة'], ['5107', 'ضيافة'], ['5108', 'قرطاسيّة ومطبوعات'], ['5109', 'تسويق وإعلان'], ['5110', 'رسوم وضرائب'],
     ['5111', 'عمولات مصرفيّة'], ['5199', 'مصاريف متنوّعة']].forEach(([c, n]) => L(c, n, 'expense', '51', 'expense'));
    return b;
  }

  /** مجموعات الرحلات والديون الشخصيّة وأنواع مصاريف السفر (تنضاف للدفاتر القديمة كذلك) */
  function addTravel(b) {
    const has = (id) => b.accounts.some((a) => a.id === id);
    const G = (code, name, type, parent) => { if (!has('g' + code)) b.accounts.push({ id: 'g' + code, code, name, type, parent: parent ? 'g' + parent : '', group: true }); };
    if (has('g1')) { G('17', 'الرحلات', 'asset', '1'); G('18', 'الديون الشخصيّة', 'asset', '1'); }
    if (!has('g5')) return;
    G('52', 'مصاريف السفر', 'expense', '5');
    [['5201', 'طيران وتذاكر'], ['5202', 'فنادق وسكن'], ['5203', 'أكل ومطاعم'], ['5204', 'مواصلات وتكاسي'], ['5205', 'تسوّق وهدايا'],
     ['5206', 'تأشيرات ورسوم'], ['5207', 'سياحة ونشاطات'], ['5208', 'إنترنت واتّصالات سفر'], ['5209', 'مصاريف سفر أخرى']].forEach(([c, n]) => {
      if (!has('a' + c)) b.accounts.push({ id: 'a' + c, code: c, name: n, type: 'expense', parent: 'g52', group: false, sub: 'expense', cur: b.meta.base, travel: true });
    });
  }

  // ———————————— الحسابات ————————————
  const acc = (b, id) => b.accounts.find((a) => a.id === id);
  const cur = (b, code) => b.currencies.find((c) => c.code === code) || { code, rate: 1, dec: 2, sym: code };
  const children = (b, id) => b.accounts.filter((a) => a.parent === id);

  function nextCode(b, parentId) {
    const p = acc(b, parentId);
    const pc = p ? p.code : '';
    const sibs = b.accounts.filter((a) => a.parent === parentId).map((a) => a.code).filter((c) => c.startsWith(pc));
    let n = 1;
    const width = pc.length >= 2 ? 2 : 1;
    while (sibs.includes(pc + String(n).padStart(width, '0'))) n++;
    return pc + String(n).padStart(width, '0');
  }

  /** يضيف حساب: {name, sub, parent?, cur?, phone?, note?, group?, share?} */
  function addAccount(b, o) {
    if (!o || !String(o.name || '').trim()) throw new Error('اكتب اسم الحساب');
    const name = String(o.name).trim();
    const sub = o.group ? null : (o.sub || 'general');
    let parent = o.parent || (sub && SUBS[sub] ? 'g' + SUBS[sub].parent : '');
    const p = acc(b, parent);
    if (parent && (!p || !p.group)) throw new Error('الحساب الأب لازم يكون مجموعة');
    const type = p ? p.type : (o.type || (SUBS[sub] && SUBS[sub].type) || 'asset');
    if (b.accounts.some((a) => !a.archived && a.parent === parent && a.name === name)) throw new Error('يوجد حساب بنفس الاسم بنفس المجموعة');
    const code = o.code || nextCode(b, parent);
    if (b.accounts.some((a) => a.code === code)) throw new Error('رقم الحساب مستعمل');
    const a = {
      id: (o.group ? 'g' : 'a') + uid(), code, name, type, parent, group: !!o.group,
      sub: sub || undefined, cur: o.group ? undefined : (o.cur || b.meta.base),
      phone: o.phone || '', note: o.note || '', limit: +o.limit || 0, share: +o.share || 0, created: today(),
    };
    if (sub === 'trip') Object.assign(a, { budget: +o.budget || 0, start: o.start || '', end: o.end || '', people: Math.max(1, +o.people || 1), place: o.place || '' });
    b.accounts.push(a);
    audit(b, 'add-acc', a.name);
    return a;
  }

  function updateAccount(b, id, patch) {
    const a = acc(b, id);
    if (!a) throw new Error('الحساب غير موجود');
    const used = isUsed(b, id);
    if (patch.cur && patch.cur !== a.cur && used) throw new Error('ما تكدر تغيّر عملة حساب بيه حركات');
    if (patch.parent && patch.parent !== a.parent) {
      const p = acc(b, patch.parent);
      if (!p || !p.group) throw new Error('الأب لازم مجموعة');
      if (p.type !== a.type && used) throw new Error('ما تكدر تنقله لنوع ثاني وبيه حركات');
      // منع الدوران
      let x = p; while (x) { if (x.id === id) throw new Error('ما يصير الحساب يصير تحت نفسه'); x = acc(b, x.parent); }
      a.type = p.type;
    }
    ['name', 'phone', 'note', 'parent', 'cur', 'archived', 'limit', 'share', 'code', 'budget', 'start', 'end', 'people', 'place'].forEach((k) => { if (k in patch) a[k] = patch[k]; });
    if ('name' in patch) a.name = String(a.name).trim();
    audit(b, 'edit-acc', a.name);
    return a;
  }

  const isUsed = (b, id) => b.entries.some((e) => e.lines.some((l) => l.a === id || l.cc === id)) || b.accounts.some((a) => a.parent === id);

  function deleteAccount(b, id) {
    const a = acc(b, id);
    if (!a) return;
    if (a.system) throw new Error('حساب نظام ما ينحذف');
    if (isUsed(b, id)) throw new Error('الحساب بيه حركات أو حسابات فرعيّة — أرشفه بدل الحذف');
    b.accounts = b.accounts.filter((x) => x.id !== id);
    audit(b, 'del-acc', a.name);
  }

  const sysAcc = (b, key) => b.accounts.find((a) => a.system === key);
  const path = (b, id) => { const out = []; let a = acc(b, id); while (a) { out.unshift(a); a = acc(b, a.parent); } return out; };
  const descendants = (b, id) => { const out = []; const walk = (pid) => children(b, pid).forEach((c) => { out.push(c); walk(c.id); }); walk(id); return out; };
  const leafIds = (b, id) => { const a = acc(b, id); if (!a) return []; return a.group ? descendants(b, id).filter((x) => !x.group).map((x) => x.id) : [id]; };

  // ———————————— القيود ————————————
  /** سطر: {a, dr, cr, cur, rate, m, cc, cat} ؛ القيمة بعملة السطر، والأساس = القيمة × السعر */
  function normLine(b, l) {
    const a = acc(b, l.a);
    const c = l.cur || (a && a.cur) || b.meta.base;
    const rate = c === b.meta.base ? 1 : (+l.rate || cur(b, c).rate || 1);
    const out = { a: l.a, dr: r2(l.dr), cr: r2(l.cr), cur: c, rate };
    if (l.m) out.m = String(l.m);
    if (l.cc) out.cc = l.cc;
    if (l.cat) out.cat = l.cat;
    return out;
  }
  const baseOf = (l) => r2((l.dr - l.cr) * l.rate);

  function validate(b, e) {
    const errs = [];
    if (!e.date || !/^\d{4}-\d{2}-\d{2}$/.test(e.date)) errs.push('التاريخ غير صحيح');
    if (b.meta.lockDate && e.date <= b.meta.lockDate) errs.push('الفترة مقفلة لحدّ ' + b.meta.lockDate);
    if (!e.lines || e.lines.length < 2) errs.push('القيد يحتاج طرفين على الأقل');
    let sum = 0, dr = 0;
    (e.lines || []).forEach((l, i) => {
      const a = acc(b, l.a);
      if (!a) errs.push('السطر ' + (i + 1) + ': اختار حساب');
      else if (a.group) errs.push('السطر ' + (i + 1) + ': «' + a.name + '» مجموعة، اختار حساب فرعيّ');
      else if (a.archived && e.kind !== 'closing') errs.push('السطر ' + (i + 1) + ': «' + a.name + '» مؤرشف');
      if (l.dr < 0 || l.cr < 0) errs.push('السطر ' + (i + 1) + ': مبلغ سالب');
      if (l.dr > 0 && l.cr > 0) errs.push('السطر ' + (i + 1) + ': يا مدين يا دائن مو الاثنين');
      if (!(l.dr > 0 || l.cr > 0)) errs.push('السطر ' + (i + 1) + ': بلا مبلغ');
      if (!(l.rate > 0)) errs.push('السطر ' + (i + 1) + ': سعر صرف غلط');
      if (l.cc && !acc(b, l.cc)) errs.push('السطر ' + (i + 1) + ': «على حساب» غير موجود');
      sum += (l.dr - l.cr) * l.rate; dr += l.dr * l.rate;
    });
    if (Math.abs(sum) > EPS + 0.01 * (e.lines || []).length) errs.push('القيد غير متوازن: الفرق ' + r2(sum));
    if (dr <= 0 && !errs.length) errs.push('مبلغ القيد صفر');
    return errs;
  }

  /** يضيف أو يعدّل قيد. fx=true يضيف فرق الصرف تلقائيًّا لحساب فروقات الصرف */
  function post(b, e, opts) {
    opts = opts || {};
    const old = e.id ? b.entries.find((x) => x.id === e.id) : null;
    if (old && b.meta.lockDate && old.date <= b.meta.lockDate) throw new Error('القيد بفترة مقفلة');
    const lines = (e.lines || []).filter((l) => l && l.a && (+l.dr || +l.cr)).map((l) => normLine(b, l));
    // فرق صرف بسيط بين عملات مختلفة
    const curs = new Set(lines.map((l) => l.cur));
    const diff = r2(lines.reduce((s, l) => s + (l.dr - l.cr) * l.rate, 0));
    if (Math.abs(diff) > EPS && (curs.size > 1 || opts.fx) && Math.abs(diff) <= Math.max(1, 0.05 * lines.reduce((s, l) => s + l.dr * l.rate, 0))) {
      const fx = sysAcc(b, 'fx');
      lines.push({ a: fx.id, dr: diff < 0 ? -diff : 0, cr: diff > 0 ? diff : 0, cur: b.meta.base, rate: 1, m: 'فرق صرف' });
    }
    const ent = {
      id: old ? old.id : uid(), no: old ? old.no : ++b.seq.entry, date: e.date || today(), kind: e.kind || 'journal',
      memo: String(e.memo || '').trim(), ref: e.ref || '', lines, created: old ? old.created : Date.now(), updated: Date.now(),
    };
    if (e.tag) ent.tag = e.tag;
    if (e.due) ent.due = e.due;
    if (e.reverses) ent.reverses = e.reverses;
    const errs = validate(b, ent);
    if (errs.length) { if (!old) b.seq.entry--; const err = new Error(errs[0]); err.all = errs; throw err; }
    if (old) Object.assign(old, ent); else b.entries.push(ent);
    audit(b, old ? 'edit' : 'post', '#' + ent.no + ' ' + (KINDS[ent.kind] || '') + ' ' + amountOf(ent));
    return old || ent;
  }

  function remove(b, id) {
    const e = b.entries.find((x) => x.id === id);
    if (!e) return;
    if (b.meta.lockDate && e.date <= b.meta.lockDate) throw new Error('القيد بفترة مقفلة');
    b.entries = b.entries.filter((x) => x.id !== id);
    audit(b, 'delete', '#' + e.no + ' ' + (e.memo || KINDS[e.kind] || ''));
  }

  function reverse(b, id, date) {
    const e = b.entries.find((x) => x.id === id);
    if (!e) throw new Error('القيد غير موجود');
    return post(b, {
      date: date || today(), kind: 'reverse', reverses: e.id, memo: 'عكس القيد #' + e.no + (e.memo ? ' — ' + e.memo : ''),
      lines: e.lines.map((l) => Object.assign({}, l, { dr: l.cr, cr: l.dr })),
    });
  }

  const amountOf = (e) => r2(e.lines.reduce((s, l) => s + l.dr * l.rate, 0));

  // ———————————— السندات الجاهزة (تتحوّل لقيد مزدوج) ————————————
  /**
   * v: {kind, date, amount, cur, rate, from, to, account, cat, cc, memo, ref, onParty, toAmount, toRate}
   *  receipt : قبض من account إلى صندوق to
   *  payment : دفع لـ account من صندوق from
   *  expense : مصروف cat مدفوع من from، على حساب cc؛ onParty=true ⇒ الحساب cc يتحمّله (دين عليه)
   *  income  : إيراد cat مقبوض في to، على حساب cc
   *  transfer: من from إلى to (عملات مختلفة: toAmount)
   *  sale    : بيع آجل لـ account بإيراد cat
   *  purchase: شراء آجل من account كمصروف/أصل cat
   *  opening : رصيد افتتاحيّ للحساب account (amount موجب = عليه/مدين، side='cr' = له)
   */
  function voucher(b, v) {
    const lines = voucherLines(b, v);
    return post(b, { id: v.id, date: v.date, kind: v.kind, memo: v.memo, ref: v.ref, lines, tag: v.tag, due: v.due });
  }
  /** يبني أسطر القيد من السند بدون حفظ (للمعاينة) */
  function voucherLines(b, v) {
    const amt = r2(v.amount);
    if (!(amt > 0)) throw new Error('اكتب المبلغ');
    const C = v.cur || b.meta.base;
    const R = C === b.meta.base ? 1 : (+v.rate || cur(b, C).rate);
    const line = (a, side, extra) => Object.assign({ a, dr: side === 'dr' ? amt : 0, cr: side === 'cr' ? amt : 0, cur: C, rate: R }, extra || {});
    const need = (id, what) => { if (!id || !acc(b, id)) throw new Error('اختار ' + what); return id; };
    const sameCur = (id) => { const a = acc(b, id); if (a && a.cur && a.cur !== C) throw new Error('عملة «' + a.name + '» ' + a.cur + ' — غيّر عملة السند أو استعمل التحويل'); };
    let lines;
    switch (v.kind) {
      case 'receipt':
        need(v.to, 'الصندوق المستلم'); need(v.account, 'الحساب'); sameCur(v.to);
        lines = [line(v.to, 'dr'), line(v.account, 'cr', { cc: v.cc })]; break;
      case 'payment':
        need(v.from, 'الصندوق'); need(v.account, 'الحساب'); sameCur(v.from);
        lines = [line(v.account, 'dr', { cc: v.cc }), line(v.from, 'cr')]; break;
      case 'expense':
        need(v.cat, 'نوع المصروف'); need(v.from, 'من وين انصرف');
        if (v.onParty) { need(v.cc, 'الحساب اللي يتحمّل المصروف'); lines = [line(v.cc, 'dr', { cat: v.cat }), line(v.from, 'cr')]; }
        else lines = [line(v.cat, 'dr', { cc: v.cc }), line(v.from, 'cr')];
        break;
      case 'income':
        need(v.cat, 'نوع الإيراد'); need(v.to, 'وين انقبض');
        lines = [line(v.to, 'dr'), line(v.cat, 'cr', { cc: v.cc })]; break;
      case 'transfer': {
        need(v.from, 'من حساب'); need(v.to, 'إلى حساب');
        if (v.from === v.to) throw new Error('نفس الحساب');
        const fa = acc(b, v.from), ta = acc(b, v.to);
        const fc = fa.cur || C, tc = ta.cur || C;
        const fr = fc === b.meta.base ? 1 : (+v.rate || cur(b, fc).rate);
        if (fc === tc) lines = [{ a: v.to, dr: amt, cr: 0, cur: fc, rate: fr }, { a: v.from, dr: 0, cr: amt, cur: fc, rate: fr }];
        else {
          const toAmt = r2(v.toAmount) || r2(amt * fr / cur(b, tc).rate);
          const tr = tc === b.meta.base ? 1 : r2(amt * fr / toAmt * 1e6) / 1e6; // السعر الفعليّ للصرفة
          lines = [{ a: v.to, dr: toAmt, cr: 0, cur: tc, rate: tr }, { a: v.from, dr: 0, cr: amt, cur: fc, rate: fr }];
          if (tc === b.meta.base) { lines[0].rate = 1; }
        }
        break;
      }
      case 'sale':
        need(v.account, 'الزبون'); need(v.cat, 'نوع الإيراد');
        lines = [line(v.account, 'dr'), line(v.cat, 'cr', { cc: v.cc || v.account })]; break;
      case 'purchase':
        need(v.account, 'المورد'); need(v.cat, 'نوع المصروف');
        lines = [line(v.cat, 'dr', { cc: v.cc }), line(v.account, 'cr')]; break;
      case 'opening': {
        need(v.account, 'الحساب');
        const op = sysAcc(b, 'opening').id;
        const side = v.side === 'cr' ? 'cr' : 'dr';
        lines = [line(v.account, side), Object.assign(line(op, side === 'dr' ? 'cr' : 'dr'), { cur: b.meta.base, rate: 1, dr: side === 'dr' ? 0 : r2(amt * R), cr: side === 'dr' ? r2(amt * R) : 0 })];
        break;
      }
      default: throw new Error('نوع سند غير معروف');
    }
    return lines.map((l) => normLine(b, l));
  }

  /** يرجّع السند من القيد (حتى نعدّله بنفس الشاشة) */
  function toVoucher(b, e) {
    const L = e.lines.filter((l) => !(acc(b, l.a) || {}).system || e.kind === 'opening');
    const d = e.lines.find((l) => l.dr > 0), c = e.lines.find((l) => l.cr > 0);
    const v = { id: e.id, kind: e.kind, date: e.date, memo: e.memo, ref: e.ref, due: e.due, amount: (d || {}).dr, cur: (d || {}).cur, rate: (d || {}).rate };
    switch (e.kind) {
      case 'receipt': v.to = d.a; v.account = c.a; v.cc = c.cc; break;
      case 'payment': v.account = d.a; v.cc = d.cc; v.from = c.a; break;
      case 'expense': if (d.cat) { v.onParty = true; v.cc = d.a; v.cat = d.cat; } else { v.cat = d.a; v.cc = d.cc; } v.from = c.a; break;
      case 'income': v.to = d.a; v.cat = c.a; v.cc = c.cc; break;
      case 'transfer': v.to = d.a; v.from = c.a; v.amount = c.cr; v.cur = c.cur; v.rate = c.rate; v.toAmount = d.dr; break;
      case 'sale': v.account = d.a; v.cat = c.a; v.cc = c.cc; break;
      case 'purchase': v.cat = d.a; v.cc = d.cc; v.account = c.a; break;
      case 'opening': { const op = sysAcc(b, 'opening').id; const x = e.lines.find((l) => l.a !== op); v.account = x.a; v.side = x.dr > 0 ? 'dr' : 'cr'; v.amount = x.dr || x.cr; v.cur = x.cur; v.rate = x.rate; break; }
      default: return null;
    }
    void L;
    return v;
  }

  // ———————————— الأرصدة ————————————
  /** رصيد حساب (فرعيّ أو مجموعة): base بالعملة الأساسيّة، own بعملة الحساب، dr/cr مجاميع */
  function balance(b, id, o) {
    o = o || {};
    const ids = new Set(leafIds(b, id));
    const a = acc(b, id);
    const own = a && !a.group ? a.cur : null;
    let base = 0, ownAmt = 0, dr = 0, cr = 0, n = 0;
    for (const e of b.entries) {
      if (!inRange(e.date, o.from, o.to)) continue;
      if (o.excludeClosing && e.kind === 'closing') continue;
      for (const l of e.lines) {
        if (!ids.has(l.a)) continue;
        if (o.cc && l.cc !== o.cc) continue;
        n++;
        base += (l.dr - l.cr) * l.rate; dr += l.dr * l.rate; cr += l.cr * l.rate;
        if (own) ownAmt += l.cur === own ? l.dr - l.cr : ((l.dr - l.cr) * l.rate) / cur(b, own).rate;
      }
    }
    return { base: r2(base), own: r2(ownAmt), dr: r2(dr), cr: r2(cr), n, cur: own || b.meta.base };
  }

  /** كشف حساب جاري: الرصيد الافتتاحيّ + كلّ حركة مع الرصيد بعدها (بعملة الحساب) */
  function statement(b, id, o) {
    o = o || {};
    const a = acc(b, id);
    if (!a) throw new Error('الحساب غير موجود');
    const ids = new Set(leafIds(b, id));
    const C = a.group ? b.meta.base : a.cur;
    const conv = (l) => (l.cur === C ? 1 : l.rate / cur(b, C).rate);
    let open = 0;
    const rows = [];
    const sorted = b.entries.slice().sort(byDate);
    for (const e of sorted) {
      for (const l of e.lines) {
        if (!ids.has(l.a)) continue;
        const k = conv(l), d = r2(l.dr * k), c = r2(l.cr * k);
        if (o.from && e.date < o.from) { open += d - c; continue; }
        if (o.to && e.date > o.to) continue;
        const other = e.lines.filter((x) => x !== l && (l.dr > 0 ? x.cr > 0 : x.dr > 0)).map((x) => acc(b, x.a)).filter(Boolean);
        rows.push({ e: e.id, no: e.no, date: e.date, kind: e.kind, memo: l.m || e.memo, ref: e.ref, dr: d, cr: c, orig: l.cur !== C ? { amt: l.dr || l.cr, cur: l.cur } : null,
          other: other.map((x) => x.name).join('، '), cat: l.cat ? (acc(b, l.cat) || {}).name : '', cc: l.cc ? (acc(b, l.cc) || {}).name : '', acc: a.group ? (acc(b, l.a) || {}).name : '' });
      }
    }
    let run = r2(open);
    rows.forEach((r) => { run = r2(run + r.dr - r.cr); r.bal = run; });
    const tDr = r2(rows.reduce((s, r) => s + r.dr, 0)), tCr = r2(rows.reduce((s, r) => s + r.cr, 0));
    return { acc: a, cur: C, open: r2(open), rows, dr: tDr, cr: tCr, close: r2(open + tDr - tCr) };
  }
  function byDate(x, y) { return x.date < y.date ? -1 : x.date > y.date ? 1 : x.no - y.no; }

  /** المصاريف (والإيرادات) المحمّلة على حساب كمركز كلفة + اللي تحمّلها هو */
  function centerReport(b, id, o) {
    o = o || {};
    const exp = {}, rev = {}; const rows = [];
    let te = 0, tr = 0;
    const ids = new Set(leafIds(b, id));
    for (const e of b.entries) {
      if (!inRange(e.date, o.from, o.to) || e.kind === 'closing') continue;
      for (const l of e.lines) {
        const a = acc(b, l.a); if (!a) continue;
        let catId = null, sign = 0;
        if (l.cc && ids.has(l.cc) && (a.type === 'expense' || a.type === 'revenue')) { catId = l.a; }
        else if (l.cat && ids.has(l.a)) { catId = l.cat; }
        if (!catId) continue;
        const ca = acc(b, catId) || a;
        const v = r2((l.dr - l.cr) * l.rate);
        if (ca.type === 'revenue') { sign = -v; rev[catId] = r2((rev[catId] || 0) + sign); tr += sign; }
        else { sign = v; exp[catId] = r2((exp[catId] || 0) + sign); te += sign; }
        rows.push({ e: e.id, no: e.no, date: e.date, memo: l.m || e.memo, cat: ca.name, catId, type: ca.type, amt: sign, onParty: !!l.cat });
      }
    }
    const list = (m) => Object.entries(m).map(([k, v]) => ({ id: k, name: (acc(b, k) || {}).name || '؟', amt: v })).sort((x, y) => y.amt - x.amt);
    rows.sort(byDate);
    return { expenses: list(exp), revenues: list(rev), totalExp: r2(te), totalRev: r2(tr), profit: r2(tr - te), rows };
  }

  // ———————————— التقارير ————————————
  /** ميزان المراجعة: لكلّ حساب افتتاحيّ/حركة/ختاميّ، مع تجميع المجموعات */
  function trialBalance(b, o) {
    o = o || {};
    const m = {};
    b.accounts.forEach((a) => (m[a.id] = { odr: 0, ocr: 0, dr: 0, cr: 0 }));
    for (const e of b.entries) {
      if (o.to && e.date > o.to) continue;
      const before = o.from && e.date < o.from;
      for (const l of e.lines) {
        const x = m[l.a]; if (!x) continue;
        const d = l.dr * l.rate, c = l.cr * l.rate;
        if (before) { x.odr += d; x.ocr += c; } else { x.dr += d; x.cr += c; }
      }
    }
    // تجميع للآباء
    const order = b.accounts.slice().sort((x, y) => (x.code < y.code ? -1 : 1));
    const depth = (a) => path(b, a.id).length - 1;
    order.filter((a) => !a.group).forEach((a) => {
      let p = acc(b, a.parent);
      while (p) { ['odr', 'ocr', 'dr', 'cr'].forEach((k) => (m[p.id][k] += m[a.id][k])); p = acc(b, p.parent); }
    });
    const rows = order.map((a) => {
      const x = m[a.id];
      const open = x.odr - x.ocr, close = open + x.dr - x.cr;
      return { id: a.id, code: a.code, name: a.name, type: a.type, group: a.group, depth: depth(a), archived: a.archived,
        open: r2(open), dr: r2(x.dr), cr: r2(x.cr), close: r2(close), cdr: close > 0 ? r2(close) : 0, ccr: close < 0 ? r2(-close) : 0 };
    }).filter((r) => !o.hideZero || r.open || r.dr || r.cr);
    const leaves = rows.filter((r) => !r.group);
    const tot = { dr: r2(leaves.reduce((s, r) => s + r.dr, 0)), cr: r2(leaves.reduce((s, r) => s + r.cr, 0)),
      cdr: r2(leaves.reduce((s, r) => s + r.cdr, 0)), ccr: r2(leaves.reduce((s, r) => s + r.ccr, 0)) };
    tot.balanced = Math.abs(tot.dr - tot.cr) < 0.05 && Math.abs(tot.cdr - tot.ccr) < 0.05;
    return { rows, tot };
  }

  /** قائمة الدخل لفترة (اختياريّ: على حساب/مركز كلفة) */
  function incomeStatement(b, o) {
    o = o || {};
    const tb = {};
    for (const e of b.entries) {
      if (!inRange(e.date, o.from, o.to) || e.kind === 'closing') continue;
      for (const l of e.lines) {
        const a = acc(b, l.a); if (!a) continue;
        if (a.type !== 'revenue' && a.type !== 'expense') continue;
        if (o.cc && l.cc !== o.cc) continue;
        tb[l.a] = (tb[l.a] || 0) + (l.dr - l.cr) * l.rate;
      }
    }
    const pick = (type) => b.accounts.filter((a) => !a.group && a.type === type && tb[a.id]).map((a) => ({ id: a.id, code: a.code, name: a.name,
      parent: (acc(b, a.parent) || {}).name, amt: r2(type === 'revenue' ? -tb[a.id] : tb[a.id]) })).sort((x, y) => y.amt - x.amt);
    const revenues = pick('revenue'), expenses = pick('expense');
    const tr = r2(revenues.reduce((s, x) => s + x.amt, 0)), te = r2(expenses.reduce((s, x) => s + x.amt, 0));
    return { revenues, expenses, totalRev: tr, totalExp: te, net: r2(tr - te), margin: tr ? r2((tr - te) / tr * 100) : 0 };
  }

  /** الميزانيّة العموميّة بتاريخ */
  function balanceSheet(b, o) {
    o = o || {};
    const tb = trialBalance(b, { to: o.to });
    const sec = (type) => {
      const sign = TYPES[type].normal;
      const live = new Set();
      tb.rows.filter((r) => r.type === type && !r.group && Math.abs(r.close) > EPS).forEach((r) => path(b, r.id).forEach((p) => live.add(p.id)));
      const rows = tb.rows.filter((r) => r.type === type && live.has(r.id)).map((r) => Object.assign({}, r, { amt: r2(r.close * sign) }));
      const total = r2(tb.rows.filter((r) => r.type === type && !r.group).reduce((s, r) => s + r.close * sign, 0));
      return { rows, total };
    };
    const assets = sec('asset'), liab = sec('liability'), equity = sec('equity');
    const pl = incomeStatement(b, { to: o.to });
    // أرباح غير مقفلة = الإيرادات − المصروفات (بما فيها قيود الإقفال تنعكس داخل الحقوق)
    const unclosed = r2(-tb.rows.filter((r) => !r.group && (r.type === 'revenue' || r.type === 'expense')).reduce((s, r) => s + r.close, 0));
    const right = r2(liab.total + equity.total + unclosed);
    return { assets, liab, equity, profit: unclosed, periodNet: pl.net, totalAssets: assets.total, totalRight: right, balanced: Math.abs(assets.total - right) < 0.05 };
  }

  /** دفتر اليوميّة */
  function journal(b, o) {
    o = o || {};
    const q = (o.q || '').trim();
    return b.entries.filter((e) => inRange(e.date, o.from, o.to) && (!o.kind || e.kind === o.kind) && (!o.acc || e.lines.some((l) => l.a === o.acc || l.cc === o.acc)) &&
      (!q || (e.memo + ' ' + e.ref + ' #' + e.no + ' ' + e.lines.map((l) => ((acc(b, l.a) || {}).name || '') + ' ' + (l.m || '') + ' ' + l.dr + ' ' + l.cr).join(' ')).includes(q)))
      .slice().sort((x, y) => -byDate(x, y));
  }

  /** التدفّق النقديّ: حركة الصناديق والمصارف مصنّفة حسب الطرف المقابل */
  function cashFlow(b, o) {
    o = o || {};
    const cashIds = new Set(b.accounts.filter((a) => !a.group && (a.sub === 'cash' || a.sub === 'bank')).map((a) => a.id));
    const groups = {};
    let opening = 0, inflow = 0, outflow = 0;
    for (const e of b.entries) {
      if (o.to && e.date > o.to) continue;
      const cl = e.lines.filter((l) => cashIds.has(l.a));
      if (!cl.length) continue;
      const net = cl.reduce((s, l) => s + (l.dr - l.cr) * l.rate, 0);
      if (o.from && e.date < o.from) { opening += net; continue; }
      if (Math.abs(net) < EPS) continue; // تحويل داخليّ
      const others = e.lines.filter((l) => !cashIds.has(l.a));
      const big = others.slice().sort((x, y) => Math.abs((y.dr - y.cr) * y.rate) - Math.abs((x.dr - x.cr) * x.rate))[0];
      const a = big ? acc(b, big.a) : null;
      const label = a ? (a.type === 'expense' ? 'مصروفات' : a.type === 'revenue' ? 'إيرادات' : a.sub === 'customer' ? 'الزبائن' : a.sub === 'supplier' ? 'الموردين'
        : a.type === 'equity' ? 'الشركاء ورأس المال' : a.sub === 'loan' ? 'القروض' : a.sub === 'asset' ? 'أصول ثابتة' : 'أخرى') : 'أخرى';
      const g = (groups[label] = groups[label] || { label, inn: 0, out: 0 });
      if (net > 0) { g.inn += net; inflow += net; } else { g.out -= net; outflow -= net; }
    }
    const list = Object.values(groups).map((g) => ({ label: g.label, inn: r2(g.inn), out: r2(g.out), net: r2(g.inn - g.out) })).sort((x, y) => Math.abs(y.net) - Math.abs(x.net));
    return { opening: r2(opening), inflow: r2(inflow), outflow: r2(outflow), closing: r2(opening + inflow - outflow), groups: list };
  }

  /** أعمار الديون (FIFO): الحركات المدينة غير المسدّدة حسب عمرها */
  function aging(b, o) {
    o = o || {};
    const asOf = o.to || today();
    const subs = o.side === 'pay' ? ['supplier', 'loan'] : ['customer', 'employee', 'project'];
    const dayDiff = (d) => Math.floor((Date.parse(asOf) - Date.parse(d)) / 864e5);
    const out = [];
    b.accounts.filter((a) => !a.group && subs.includes(a.sub) && !a.archived).forEach((a) => {
      const st = statement(b, a.id, { to: asOf });
      const sign = o.side === 'pay' ? -1 : 1;
      let paid = st.rows.reduce((s, r) => s + (sign > 0 ? r.cr : r.dr), 0);
      const items = st.rows.map((r) => ({ date: r.date, amt: sign > 0 ? r.dr : r.cr })).filter((x) => x.amt > 0);
      if (st.open * sign > 0) items.unshift({ date: '0000-01-01', amt: st.open * sign });
      else paid += -st.open * sign;
      const buckets = [0, 0, 0, 0];
      items.forEach((it) => {
        const use = Math.min(paid, it.amt); paid -= use; const left = it.amt - use;
        if (left <= 0) return;
        const d = it.date === '0000-01-01' ? 999 : dayDiff(it.date);
        buckets[d <= 30 ? 0 : d <= 60 ? 1 : d <= 90 ? 2 : 3] += left;
      });
      const total = r2(buckets.reduce((s, x) => s + x, 0));
      if (total > 0.005) out.push({ id: a.id, name: a.name, cur: a.cur, b: buckets.map(r2), total, phone: a.phone });
    });
    return out.sort((x, y) => y.total - x.total);
  }

  /** اتّجاه شهريّ: إيراد/مصروف/صافي لكلّ شهر */
  function monthly(b, o) {
    o = o || {};
    const n = o.months || 12;
    const end = o.to ? new Date(o.to) : new Date();
    const keys = [];
    for (let i = n - 1; i >= 0; i--) { const d = new Date(end.getFullYear(), end.getMonth() - i, 1); keys.push(d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0')); }
    const m = {}; keys.forEach((k) => (m[k] = { k, rev: 0, exp: 0 }));
    for (const e of b.entries) {
      if (e.kind === 'closing') continue;
      const k = e.date.slice(0, 7); if (!m[k]) continue;
      for (const l of e.lines) {
        const a = acc(b, l.a); if (!a) continue;
        if (o.cc && l.cc !== o.cc && !(l.cat && l.a === o.cc)) continue;
        if (a.type === 'revenue') m[k].rev += (l.cr - l.dr) * l.rate;
        else if (a.type === 'expense') m[k].exp += (l.dr - l.cr) * l.rate;
        else if (l.cat && o.cc) m[k].exp += (l.dr - l.cr) * l.rate;
      }
    }
    return keys.map((k) => ({ k, rev: r2(m[k].rev), exp: r2(m[k].exp), net: r2(m[k].rev - m[k].exp) }));
  }

  /** المصاريف حسب النوع أو حسب «على حساب» */
  function expensesBy(b, o) {
    o = o || {};
    const m = {};
    let total = 0;
    for (const e of b.entries) {
      if (!inRange(e.date, o.from, o.to) || e.kind === 'closing') continue;
      for (const l of e.lines) {
        const a = acc(b, l.a); if (!a) continue;
        let key = null, v = 0;
        if (a.type === 'expense') { key = o.by === 'cc' ? (l.cc || '—') : l.a; v = (l.dr - l.cr) * l.rate; }
        else if (l.cat) { key = o.by === 'cc' ? l.a : l.cat; v = (l.dr - l.cr) * l.rate; }
        if (!key) continue;
        m[key] = (m[key] || 0) + v; total += v;
      }
    }
    return { total: r2(total), rows: Object.entries(m).map(([k, v]) => ({ id: k, name: k === '—' ? 'بدون حساب' : ((acc(b, k) || {}).name || '؟'), amt: r2(v), pct: total ? r2(v / total * 100) : 0 })).sort((x, y) => y.amt - x.amt) };
  }

  /** أرصدة الحسابات حسب الصفة (للّوحة والقوائم) */
  function partyList(b, o) {
    o = o || {};
    return b.accounts.filter((a) => !a.group && (!o.sub || (Array.isArray(o.sub) ? o.sub.includes(a.sub) : a.sub === o.sub)) && (o.archived || !a.archived))
      .map((a) => { const x = balance(b, a.id); const last = lastMove(b, a.id); return { a, bal: x.own, base: x.base, n: x.n, last }; });
  }
  function lastMove(b, id) { let d = ''; for (const e of b.entries) if (e.date > d && e.lines.some((l) => l.a === id || l.cc === id)) d = e.date; return d; }

  function dashboard(b, o) {
    o = o || {};
    const t = today(); const mStart = t.slice(0, 8) + '01';
    const sumSub = (subs) => r2(b.accounts.filter((a) => !a.group && subs.includes(a.sub)).reduce((s, a) => s + balance(b, a.id).base, 0));
    const recv = r2(b.accounts.filter((a) => !a.group && ['customer', 'employee', 'project'].includes(a.sub)).reduce((s, a) => { const x = balance(b, a.id).base; return s + (x > 0 ? x : 0); }, 0));
    const pay = r2(b.accounts.filter((a) => !a.group && ['supplier', 'loan', 'customer'].includes(a.sub)).reduce((s, a) => { const x = balance(b, a.id).base; return s + (x < 0 ? -x : 0); }, 0));
    const month = incomeStatement(b, { from: mStart, to: t });
    const year = incomeStatement(b, { from: t.slice(0, 4) + '-01-01', to: t });
    return { cash: sumSub(['cash', 'bank']), recv, pay, month, year, trend: monthly(b, { months: o.months || 12 }),
      boxes: partyList(b, { sub: ['cash', 'bank'] }), topExp: expensesBy(b, { from: mStart, to: t }).rows.slice(0, 6), recent: journal(b).slice(0, 8), entries: b.entries.length };
  }

  /** إقفال السنة: يصفّر الإيرادات والمصروفات للأرباح المدوّرة ويقفل الفترة */
  function closeYear(b, toDate, lock) {
    const tb = trialBalance(b, { to: toDate });
    const ret = sysAcc(b, 'retained');
    const lines = [];
    let net = 0;
    tb.rows.filter((r) => !r.group && (r.type === 'revenue' || r.type === 'expense') && Math.abs(r.close) > EPS).forEach((r) => {
      lines.push({ a: r.id, dr: r.close < 0 ? -r.close : 0, cr: r.close > 0 ? r.close : 0, cur: b.meta.base, rate: 1 });
      net += r.close;
    });
    if (!lines.length) throw new Error('ماكو إيرادات أو مصروفات للإقفال');
    lines.push({ a: ret.id, dr: net > 0 ? r2(net) : 0, cr: net < 0 ? r2(-net) : 0, cur: b.meta.base, rate: 1 });
    // سطور الأساس تتطلّب نفس العملة؛ الحسابات الأجنبيّة نادرة بالمصاريف، فنسجّل بالأساس
    const e = post(b, { date: toDate, kind: 'closing', memo: 'إقفال السنة الماليّة حتّى ' + toDate, lines: lines.map((l) => Object.assign(l, { cur: b.meta.base })) });
    if (lock) b.meta.lockDate = toDate;
    return e;
  }

  /** توزيع ربح فترة على الشركاء حسب نسبهم (من الأرباح المدوّرة إلى جاري كلّ شريك) */
  function distributeProfit(b, o) {
    const partners = b.accounts.filter((a) => !a.group && a.sub === 'partner' && !a.archived && a.share > 0);
    if (!partners.length) throw new Error('ضيف شركاء ونسبهم أوّلًا');
    const totalShare = partners.reduce((s, p) => s + p.share, 0);
    const amt = r2(o.amount);
    if (!(amt > 0)) throw new Error('ماكو ربح للتوزيع');
    const ret = sysAcc(b, 'retained');
    const lines = [{ a: ret.id, dr: amt, cr: 0 }];
    let left = amt;
    partners.forEach((p, i) => {
      const v = i === partners.length - 1 ? r2(left) : r2(amt * p.share / totalShare);
      left = r2(left - v);
      lines.push({ a: p.id, dr: 0, cr: v, cur: b.meta.base, rate: 1, m: 'حصّة ' + p.share + '٪' });
    });
    return post(b, { date: o.date || today(), kind: 'profit', memo: o.memo || 'توزيع أرباح', lines });
  }

  // ———————————— ديوني ————————————
  /** كلّ الأشخاص والجهات اللي بيناتنا فلوس: mine (لي عندهم) و theirs (عليّ إلهم)، مع أقرب استحقاق غير مسدّد */
  function debts(b, o) {
    o = o || {};
    const asOf = o.to || today();
    const subs = ['person', 'customer', 'supplier', 'employee', 'loan', 'partner'];
    const out = { mine: [], theirs: [], totalMine: 0, totalTheirs: 0, overdue: 0 };
    b.accounts.filter((a) => !a.group && subs.includes(a.sub) && !a.archived).forEach((a) => {
      const st = statement(b, a.id, { to: asOf });
      if (Math.abs(st.close) < 0.005) return;
      const sign = st.close > 0 ? 1 : -1;
      let paid = st.rows.reduce((s, r) => s + (sign > 0 ? r.cr : r.dr), 0);
      const items = st.rows.map((r) => { const e = b.entries.find((x) => x.id === r.e); return { date: r.date, amt: sign > 0 ? r.dr : r.cr, due: e && e.due, memo: r.memo, e: r.e }; }).filter((x) => x.amt > 0);
      if (st.open * sign > 0) items.unshift({ date: '', amt: st.open * sign }); else paid += -st.open * sign;
      const open = [];
      items.forEach((it) => { const use = Math.min(paid, it.amt); paid -= use; const left = r2(it.amt - use); if (left > 0.005) open.push(Object.assign({}, it, { left })); });
      const dues = open.filter((x) => x.due).map((x) => x.due).sort();
      const due = dues[0] || '';
      const late = !!due && due < asOf;
      const row = { id: a.id, name: a.name, sub: a.sub, phone: a.phone, cur: a.cur, amt: r2(Math.abs(st.close)), base: r2(Math.abs(balance(b, a.id).base)), due, late, since: (open[0] || {}).date || '', open, last: lastMove(b, a.id) };
      if (sign > 0) { out.mine.push(row); out.totalMine += row.base; if (late) out.overdue += row.base; } else { out.theirs.push(row); out.totalTheirs += row.base; }
    });
    const ord = (x, y) => (x.late !== y.late ? (x.late ? -1 : 1) : (x.due || '9') < (y.due || '9') ? -1 : (x.due || '9') > (y.due || '9') ? 1 : y.base - x.base);
    out.mine.sort(ord); out.theirs.sort(ord);
    out.totalMine = r2(out.totalMine); out.totalTheirs = r2(out.totalTheirs); out.overdue = r2(out.overdue);
    return out;
  }

  // ———————————— الرحلات ————————————
  /** تقرير رحلة: المحفظة + المصاريف المحمّلة عليها + الميزانيّة + كلّ يوم + حصّة الشخص (بعملة الرحلة) */
  function tripReport(b, id) {
    const a = acc(b, id);
    if (!a) throw new Error('الرحلة غير موجودة');
    const cr = centerReport(b, id);
    const tr = cur(b, a.cur).rate || 1;
    const toTrip = (v) => r2(v / tr);
    let funded = 0;
    b.entries.forEach((e) => e.lines.forEach((l) => { if (l.a === id && l.dr > 0) funded += l.cur === a.cur ? l.dr : l.dr * l.rate / tr; }));
    const spent = toTrip(cr.totalExp);
    const days = {};
    cr.rows.filter((r) => r.type === 'expense').forEach((r) => (days[r.date] = r2((days[r.date] || 0) + r.amt / tr)));
    const nDays = a.start && a.end ? Math.max(1, Math.round((Date.parse(a.end) - Date.parse(a.start)) / 864e5) + 1) : Math.max(1, Object.keys(days).length);
    return {
      acc: a, cur: a.cur, budget: a.budget || 0, funded: r2(funded), spent, wallet: balance(b, id).own, left: a.budget ? r2(a.budget - spent) : null,
      pct: a.budget ? r2(spent / a.budget * 100) : null, perDay: r2(spent / nDays), perPerson: r2(spent / Math.max(1, a.people || 1)), days: nDays, people: a.people || 1,
      byCat: cr.expenses.map((x) => Object.assign({}, x, { amt: toTrip(x.amt) })), byDay: Object.entries(days).sort().map(([d, v]) => ({ d, amt: v })),
      rows: cr.rows.map((r) => Object.assign({}, r, { amt: toTrip(r.amt) })),
    };
  }

  // ———————————— سجلّ التعديلات ————————————
  function audit(b, act, what) {
    b.log = b.log || [];
    b.log.push({ t: Date.now(), act, what: String(what || '').slice(0, 140) });
    if (b.log.length > 3000) b.log.splice(0, b.log.length - 3000);
  }

  // ———————————— فحص سلامة الدفتر ————————————
  function check(b) {
    const issues = [];
    b.entries.forEach((e) => {
      const errs = validate(b, Object.assign({}, e, { date: e.date })).filter((x) => !x.startsWith('الفترة مقفلة') && !x.includes('مؤرشف'));
      if (errs.length) issues.push('القيد #' + e.no + ': ' + errs.join('، '));
    });
    const tb = trialBalance(b);
    if (!tb.tot.balanced) issues.push('ميزان المراجعة غير متوازن');
    const nos = new Set(); b.entries.forEach((e) => { if (nos.has(e.no)) issues.push('رقم مكرّر #' + e.no); nos.add(e.no); });
    return issues;
  }

  /** يرقّي ويصلّح دفتر محمّل من ملفّ */
  function migrate(b) {
    if (!b || !Array.isArray(b.accounts) || !Array.isArray(b.entries)) throw new Error('ملفّ غير صالح');
    b.meta = b.meta || {}; b.meta.base = b.meta.base || 'IQD'; b.log = b.log || []; b.seq = b.seq || { entry: 0 };
    b.currencies = b.currencies || [{ code: b.meta.base, name: b.meta.base, sym: b.meta.base, dec: 0, rate: 1 }];
    b.seq.entry = Math.max(b.seq.entry || 0, ...b.entries.map((e) => e.no || 0), 0);
    const fresh = newBook('x', b.meta.base);
    addTravel(b);
    ['retained', 'opening', 'fx'].forEach((k) => { if (!sysAcc(b, k)) { const src = sysAcc(fresh, k); const p = src.parent && acc(b, src.parent) ? src.parent : (b.accounts.find((a) => a.group && a.type === src.type) || {}).id; b.accounts.push(Object.assign({}, src, { id: 'a' + uid(), parent: p || '', code: src.code + 'x' })); } });
    return b;
  }

  // ———————————— تنسيق ————————————
  function fmt(n, dec) {
    const d = dec == null ? 0 : dec;
    const v = Math.abs(n) < 0.005 ? 0 : n;
    return Number(v).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });
  }
  function money(b, n, code) {
    const c = cur(b, code || b.meta.base);
    const dec = c.dec != null ? c.dec : 2;
    const hasFrac = Math.abs(n - Math.round(n)) > 0.004;
    return fmt(n, hasFrac ? Math.max(dec, 2) : dec === 0 ? 0 : (Math.abs(n) >= 1000 && !hasFrac ? 0 : dec));
  }
  /** وصف الرصيد للبشر: عليه/له/صفر حسب نوع الحساب */
  function side(a, bal) {
    if (Math.abs(bal) < 0.005) return { word: 'مصفّى', cls: 'zero' };
    if (a.type === 'asset' && (a.sub === 'cash' || a.sub === 'bank')) return bal > 0 ? { word: 'رصيد', cls: 'pos' } : { word: 'سحب على المكشوف', cls: 'neg' };
    if (a.type === 'expense') return { word: 'مصروف', cls: 'neg' };
    if (a.type === 'revenue') return { word: 'إيراد', cls: 'pos' };
    return bal > 0 ? { word: 'عليه', cls: 'dr' } : { word: 'له', cls: 'cr' };
  }

  return {
    TYPES, SUBS, KINDS, r2, uid, today, newBook, acc, cur, children, path, descendants, leafIds, nextCode,
    addAccount, updateAccount, deleteAccount, isUsed, sysAcc, post, validate, remove, reverse, amountOf, voucher, voucherLines, toVoucher,
    balance, statement, centerReport, trialBalance, incomeStatement, balanceSheet, journal, cashFlow, aging, monthly, expensesBy,
    partyList, lastMove, dashboard, debts, tripReport, closeYear, distributeProfit, check, migrate, fmt, money, side, audit,
  };
});
