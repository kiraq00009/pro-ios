/* ميزان — أدوات الواجهة: أيقونات، نوافذ، منتقي الحسابات، الفترات، الرسوم */
(function () {
  'use strict';
  const E = window.Engine;
  const $ = (s, r) => (r || document).querySelector(s);
  const $$ = (s, r) => Array.from((r || document).querySelectorAll(s));
  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  // أيقونات خطّيّة (مرسومة يدويًّا، 24×24)
  const P = {
    home: '<path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z"/>',
    users: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.6-3.4 3.2-5.5 6.5-5.5s5.9 2.1 6.5 5.5"/><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M18 14.8c2 .7 3.2 2.5 3.5 5.2"/>',
    list: '<path d="M8 6h13M8 12h13M8 18h13"/><circle cx="3.5" cy="6" r="1"/><circle cx="3.5" cy="12" r="1"/><circle cx="3.5" cy="18" r="1"/>',
    chart: '<path d="M3 3v18h18"/><path d="M7 15l4-4 3 3 6-7"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    tree: '<rect x="3" y="3" width="7" height="5" rx="1"/><rect x="14" y="10" width="7" height="5" rx="1"/><rect x="14" y="17" width="7" height="4" rx="1"/><path d="M6.5 8v10.5H14M6.5 12.5H14"/>',
    gear: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
    more: '<circle cx="5" cy="12" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="19" cy="12" r="1.4"/>',
    in: '<path d="M12 4v12M6 10l6 6 6-6"/><path d="M4 20h16"/>',
    out: '<path d="M12 20V8M6 14l6-6 6 6"/><path d="M4 4h16"/>',
    receipt: '<path d="M5 3h14v18l-3-2-2 2-2-2-2 2-2-2-3 2z"/><path d="M9 8h6M9 12h6"/>',
    swap: '<path d="M7 4 3 8l4 4M3 8h14M17 20l4-4-4-4M21 16H7"/>',
    tag: '<path d="M3 12V4a1 1 0 0 1 1-1h8l9 9-9 9z"/><circle cx="7.5" cy="7.5" r="1.3"/>',
    cart: '<circle cx="9" cy="20" r="1.4"/><circle cx="18" cy="20" r="1.4"/><path d="M2 3h3l2.6 12.2a1 1 0 0 0 1 .8h9.7a1 1 0 0 0 1-.8L21 7H6"/>',
    box: '<path d="M21 8 12 3 3 8v8l9 5 9-5z"/><path d="M3 8l9 5 9-5M12 13v8"/>',
    flag: '<path d="M5 21V4M5 4h12l-2 4 2 4H5"/>',
    book: '<path d="M4 4.5A1.5 1.5 0 0 1 5.5 3H20v15H5.5A1.5 1.5 0 0 0 4 19.5z"/><path d="M4 19.5A1.5 1.5 0 0 0 5.5 21H20"/>',
    cash: '<rect x="2.5" y="6" width="19" height="12" rx="2"/><circle cx="12" cy="12" r="2.6"/><path d="M6 9v.01M18 15v.01"/>',
    bank: '<path d="M3 10 12 4l9 6M5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 20h18"/>',
    person: '<circle cx="12" cy="8" r="4"/><path d="M4 21c.8-4 4-6.5 8-6.5s7.2 2.5 8 6.5"/>',
    truck: '<path d="M2 6h11v10H2zM13 9h4.5L21 12.5V16h-8z"/><circle cx="6" cy="17.5" r="1.8"/><circle cx="17" cy="17.5" r="1.8"/>',
    hand: '<path d="M7 11V5.5a1.5 1.5 0 0 1 3 0V10M10 9.5V4a1.5 1.5 0 0 1 3 0v6M13 9.5V5a1.5 1.5 0 0 1 3 0v6.5M16 8.5a1.5 1.5 0 0 1 3 0V14a7 7 0 0 1-7 7h-.6a6 6 0 0 1-4.6-2.2L3.4 14.5a1.6 1.6 0 0 1 2.4-2.1L7 13.5"/>',
    badge: '<rect x="4" y="3" width="16" height="18" rx="2"/><circle cx="12" cy="10" r="2.6"/><path d="M8 17c.7-1.6 2.2-2.5 4-2.5s3.3.9 4 2.5"/>',
    brief: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 13h18"/>',
    bolt: '<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>',
    pie: '<path d="M21 12A9 9 0 1 1 12 3v9z"/><path d="M15 3.5A9 9 0 0 1 20.5 9H15z"/>',
    scale: '<path d="M12 3v18M5 21h14M4 7h16M7 7l-3 7h6zM17 7l-3 7h6z"/>',
    edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13.5 6.5l4 4"/>',
    trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>',
    print: '<path d="M6 9V3h12v6"/><rect x="3" y="9" width="18" height="8" rx="2"/><path d="M6 14h12v7H6z"/>',
    dl: '<path d="M12 3v12M7 10l5 5 5-5M4 21h16"/>',
    up: '<path d="M12 21V9M7 14l5-5 5 5M4 3h16"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
    x: '<path d="M6 6l12 12M18 6 6 18"/>',
    back: '<path d="M9 5l7 7-7 7"/>',
    chev: '<path d="M15 6l-6 6 6 6"/>',
    lock: '<rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',
    cloud: '<path d="M7 18a4.5 4.5 0 0 1-.6-9 6 6 0 0 1 11.4 1.6A3.8 3.8 0 0 1 17.5 18z"/>',
    phone: '<path d="M5 3h4l2 5-2.5 1.5a11 11 0 0 0 6 6L16 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 5a2 2 0 0 1 2-2z"/>',
    wa: '<path d="M4 20l1.3-4A8 8 0 1 1 8.3 19z"/><path d="M9 9.5c0 3 2.5 5.5 5.5 5.5l1-1.5-2-1-1 .8a4 4 0 0 1-1.8-1.8l.8-1-1-2z"/>',
    undo: '<path d="M9 14 4 9l5-5"/><path d="M4 9h10a6 6 0 0 1 0 12h-3"/>',
    check: '<path d="M5 12.5 10 17l9-10"/>',
    alert: '<path d="M12 3 2 20h20z"/><path d="M12 10v4M12 17v.01"/>',
    archive: '<rect x="3" y="4" width="18" height="4" rx="1"/><path d="M5 8v11a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V8M10 12h4"/>',
    copy: '<rect x="8" y="8" width="13" height="13" rx="2"/><path d="M16 8V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h3"/>',
    plane: '<path d="M10.5 13.5 3 11l1.5-1.5 7.5 1L16.5 6a2.1 2.1 0 0 1 3 3L15 13.5l1 7.5-1.5 1.5-2.5-7.5L9 18v2.5L7.5 22l-1-3.5L3 17.5 4.5 16H7z"/>',
    coins: '<ellipse cx="9" cy="7" rx="6" ry="3"/><path d="M3 7v4c0 1.7 2.7 3 6 3s6-1.3 6-3V7"/><path d="M9 14v3c0 1.7 2.7 3 6 3s6-1.3 6-3v-4c0-1.6-2.4-2.9-5.5-3"/>',
    cal: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/>',
  };
  const ic = (n, cls) => '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"' + (cls ? ' class="' + cls + '"' : '') + '>' + (P[n] || '') + '</svg>';

  // لون وأيقونة كلّ صفة حساب
  const LOOK = {
    cash: ['cash', '#0e5e4f', '#e3efe9'], bank: ['bank', '#2a5a8a', '#e4edf6'], customer: ['person', '#a4481f', '#f8e8e2'], supplier: ['truck', '#6b4fa0', '#ede7f6'],
    partner: ['hand', '#9a6a12', '#f7efd9'], employee: ['badge', '#2b7a8c', '#e2f1f4'], project: ['brief', '#1d6c52', '#e2f1ea'], loan: ['scale', '#7a3b56', '#f4e4ec'],
    trip: ['plane', '#2a5a8a', '#e4edf6'], person: ['person', '#a4481f', '#f8e8e2'],
    asset: ['box', '#5a5f5c', '#ecece8'], revenue: ['in', '#1d7a4c', '#e5f2ea'], expense: ['tag', '#b2432a', '#f8e8e2'], general: ['book', '#5a5f5c', '#ecece8'], group: ['tree', '#5a5f5c', '#ecece8'],
  };
  function av(a, big) {
    const k = a ? (a.group ? 'group' : (a.sub || 'general')) : 'general';
    const [icn, fg, bg] = LOOK[k] || LOOK.general;
    const named = a && ['customer', 'supplier', 'partner', 'employee', 'person'].includes(a.sub);
    const inner = named ? esc((a.name || '؟').trim().charAt(0)) : ic(icn);
    return '<span class="av" style="color:' + fg + ';background:color-mix(in srgb,' + bg + ' 100%,transparent)" data-look="' + k + '">' + inner + '</span>';
  }

  const B = () => window.Store.book;
  const symOf = (code) => { const c = E.cur(B(), code || B().meta.base); return c.sym || c.code; };
  /** مبلغ مع رمز العملة */
  function M(n, code, opt) {
    opt = opt || {};
    const s = E.money(B(), opt.abs ? Math.abs(n) : n, code);
    return '<span class="num">' + s + '</span>' + (opt.nosym ? '' : ' <small>' + esc(symOf(code)) + '</small>');
  }
  /** رصيد مع كلمة عليه/له */
  function BAL(a, n, code) {
    const sd = E.side(a, n);
    return '<b class="' + sd.cls + 'c">' + M(n, code, { abs: true }) + '</b><div class="s">' + sd.word + '</div>';
  }

  // ——— نوافذ ———
  const layer = () => $('#layer');
  function modal(o) {
    const ov = document.createElement('div');
    ov.className = 'ov';
    ov.innerHTML = '<div class="dlg' + (o.wide ? ' wide' : '') + '" role="dialog" aria-modal="true"><div class="hd"><h2>' + esc(o.title || '') + '</h2><button class="icon-btn" data-x aria-label="إغلاق">' + ic('x') + '</button></div><div class="bd">' + (o.body || '') + '</div>' + (o.foot !== false ? '<div class="ft"></div>' : '') + '</div>';
    const close = (v) => { ov.remove(); document.removeEventListener('keydown', key); if (o.onClose) o.onClose(v); };
    const key = (e) => { if (e.key === 'Escape') close(); };
    document.addEventListener('keydown', key);
    ov.addEventListener('mousedown', (e) => { if (e.target === ov) close(); });
    $('[data-x]', ov).onclick = () => close();
    const ft = $('.ft', ov);
    (o.actions || []).forEach((a) => {
      const btn = document.createElement('button');
      btn.className = 'btn ' + (a.cls || ''); btn.innerHTML = a.label;
      btn.onclick = async () => { try { const r = a.onClick ? await a.onClick(ov, close) : undefined; if (r !== false && !a.keep) close(r); } catch (err) { toast(err.message, true); } };
      ft.appendChild(btn);
    });
    layer().appendChild(ov);
    if (o.onMount) o.onMount(ov, close);
    const f = $('input:not([type=hidden]),select,textarea', $('.bd', ov));
    if (f && o.focus !== false && matchMedia('(min-width:821px)').matches) setTimeout(() => f.focus(), 30);
    return { el: ov, close };
  }
  function confirm(text, okLabel, danger) {
    return new Promise((res) => modal({ title: 'تأكيد', body: '<p style="margin:4px 0 6px">' + text + '</p>', onClose: (v) => res(!!v),
      actions: [{ label: 'إلغاء', cls: 'ghost', onClick: () => false }, { label: okLabel || 'نعم', cls: danger ? 'pri danger-pri' : 'pri', onClick: () => true }] }));
  }
  function prompt(title, value, label) {
    return new Promise((res) => {
      let done = false;
      modal({ title, body: '<label class="f">' + esc(label || '') + '<input class="in" id="pv" value="' + esc(value || '') + '"></label>',
        onClose: (v) => { if (!done) res(v == null ? null : v); },
        onMount: (ov, close) => { $('#pv', ov).addEventListener('keydown', (e) => { if (e.key === 'Enter') { done = true; res($('#pv', ov).value.trim()); close(); } }); },
        actions: [{ label: 'إلغاء', cls: 'ghost', onClick: () => null }, { label: 'حفظ', cls: 'pri', onClick: (ov) => $('#pv', ov).value.trim() }] });
    });
  }
  function toast(msg, bad) {
    const t = document.createElement('div');
    t.className = 'toast' + (bad ? ' bad' : ''); t.textContent = msg;
    $('#toasts').appendChild(t);
    setTimeout(() => { t.style.transition = 'opacity .3s'; t.style.opacity = '0'; setTimeout(() => t.remove(), 320); }, bad ? 4200 : 2400);
  }

  // ——— منتقي الحسابات ———
  /** filter: (a)=>bool ؛ يرجّع Promise بالحساب */
  function pickAccount(o) {
    o = o || {};
    return new Promise((res) => {
      const b = B();
      let picked = null;
      const all = b.accounts.filter((a) => !a.group && !a.archived && (!o.filter || o.filter(a)));
      const groupOf = (a) => { const p = E.acc(b, a.parent); return p ? p.name : E.TYPES[a.type].name; };
      const draw = (q) => {
        q = (q || '').trim();
        const hits = all.filter((a) => !q || a.name.includes(q) || a.code.startsWith(q) || (a.phone || '').includes(q));
        const groups = {};
        hits.forEach((a) => (groups[groupOf(a)] = groups[groupOf(a)] || []).push(a));
        const order = Object.keys(groups);
        if (!hits.length) return '<div class="empty"><b>ماكو حساب بهذا الاسم</b>' + (o.allowNew !== false && q ? 'تكدر تسوّيه هسّه 👇' : '') + '</div>';
        return order.map((g) => '<div class="g">' + esc(g) + '</div>' + groups[g].map((a) => {
          const bl = E.balance(b, a.id);
          return '<div class="li" data-id="' + a.id + '">' + av(a) + '<div class="grow"><div class="t">' + esc(a.name) + '</div><div class="s">' + esc(a.code) + (a.cur !== b.meta.base ? ' · ' + a.cur : '') + '</div></div>' +
            (bl.n ? '<div class="amt s">' + M(bl.own, a.cur) + '</div>' : '') + '</div>';
        }).join('')).join('');
      };
      const m = modal({
        title: o.title || 'اختار حساب', foot: false,
        body: '<div class="row"><input class="in grow" id="pq" placeholder="ابحث بالاسم أو الرقم…" autocomplete="off"></div><div class="picklist" id="pl">' + draw('') + '</div>' +
          (o.allowNew !== false ? '<button class="btn block" id="pnew" style="margin-top:10px">' + ic('plus') + ' حساب جديد</button>' : ''),
        onClose: () => res(picked),
        onMount: (ov, close) => {
          const q = $('#pq', ov), pl = $('#pl', ov);
          q.oninput = () => (pl.innerHTML = draw(q.value));
          q.onkeydown = (e) => { if (e.key === 'Enter') { const f = $('.li', pl); if (f) { picked = E.acc(b, f.dataset.id); close(); } } };
          pl.onclick = (e) => { const li = e.target.closest('.li'); if (li) { picked = E.acc(b, li.dataset.id); close(); } };
          const nb = $('#pnew', ov);
          if (nb) nb.onclick = async () => {
            close();
            const a = await window.Views.accountForm(null, { name: q.value.trim(), sub: o.newSub, subs: o.newSubs });
            if (a) res(a);
          };
          setTimeout(() => q.focus(), 40);
        },
      });
      void m;
    });
  }
  /** زرّ منتقي داخل نموذج؛ يكتب القيمة بـ data-v */
  function pickBtn(id, a, ph) {
    return '<button type="button" class="pick" id="' + id + '" data-v="' + (a ? a.id : '') + '">' + (a ? av(a) + '<span class="grow"><b>' + esc(a.name) + '</b></span><span class="bal">' + M(E.balance(B(), a.id).own, a.cur) + '</span>'
      : '<span class="ph2">' + esc(ph || 'اختار…') + '</span>') + '</button>';
  }
  function bindPick(root, id, opts, onPick) {
    const el = $('#' + id, root); if (!el) return;
    el.onclick = async () => {
      const a = await pickAccount(opts);
      if (!a) return;
      el.outerHTML = pickBtn(id, a, opts.ph);
      bindPick(root, id, opts, onPick);
      if (onPick) onPick(a);
    };
  }
  const val = (root, id) => { const el = $('#' + id, root); return el ? el.dataset.v || '' : ''; };

  // ——— حقل المبلغ بفواصل الآلاف ———
  function parseAmt(s) {
    const t = String(s || '').replace(/[٠-٩]/g, (d) => '٠١٢٣٤٥٦٧٨٩'.indexOf(d)).replace(/[۰-۹]/g, (d) => '۰۱۲۳۴۵۶۷۸۹'.indexOf(d)).replace(/[٬,\s]/g, '').replace('٫', '.');
    if (!t) return 0;
    // يدعم 1.5م / 250ا (مليون/ألف) وعمليّات بسيطة 1500*3
    const m = t.match(/^([\d.]+)(م|مليون|ا|الف|ألف|k|m)?$/i);
    if (m) { let v = parseFloat(m[1]); const u = (m[2] || '').toLowerCase(); if (u === 'م' || u === 'مليون' || u === 'm') v *= 1e6; else if (u) v *= 1e3; return isFinite(v) ? v : 0; }
    if (/^[\d.+\-*/()]+$/.test(t)) { try { const v = Function('"use strict";return (' + t + ')')(); return isFinite(v) ? Math.max(0, v) : 0; } catch (e) { return 0; } }
    return 0;
  }
  function bindAmount(el, onChange) {
    if (!el) return;
    const fmtNow = () => { const v = parseAmt(el.value); if (v) el.value = v.toLocaleString('en-US', { maximumFractionDigits: 2 }); };
    el.addEventListener('blur', fmtNow);
    el.addEventListener('input', () => onChange && onChange(parseAmt(el.value)));
    el.addEventListener('keydown', (e) => { if (e.key === 'Enter') { fmtNow(); onChange && onChange(parseAmt(el.value)); } });
  }

  // ——— الفترات ———
  const pad = (n) => String(n).padStart(2, '0');
  const iso = (d) => d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate());
  function period(key) {
    const t = new Date(); const y = t.getFullYear(), m = t.getMonth();
    switch (key) {
      case 'today': return { from: iso(t), to: iso(t) };
      case 'month': return { from: iso(new Date(y, m, 1)), to: iso(new Date(y, m + 1, 0)) };
      case 'last': return { from: iso(new Date(y, m - 1, 1)), to: iso(new Date(y, m, 0)) };
      case 'q': { const q = Math.floor(m / 3); return { from: iso(new Date(y, q * 3, 1)), to: iso(new Date(y, q * 3 + 3, 0)) }; }
      case 'year': return { from: y + '-01-01', to: y + '-12-31' };
      case 'lastyear': return { from: (y - 1) + '-01-01', to: (y - 1) + '-12-31' };
      default: return { from: '', to: '' };
    }
  }
  const PERIODS = [['all', 'الكلّ'], ['month', 'هذا الشهر'], ['last', 'الشهر الماضي'], ['q', 'هذا الربع'], ['year', 'هذه السنة'], ['lastyear', 'السنة الماضية'], ['custom', 'مخصّص']];
  /** شريط الفترة: state={p,from,to}؛ onChange */
  function periodBar(state, opts) {
    opts = opts || {};
    const list = opts.asOf ? [['all', 'لحدّ اليوم'], ['month', 'نهاية الشهر'], ['last', 'نهاية الشهر الماضي'], ['year', 'نهاية السنة'], ['lastyear', 'نهاية السنة الماضية'], ['custom', 'بتاريخ']] : PERIODS;
    return '<div class="row noprint" data-period><select class="in" data-p style="width:auto;min-width:150px">' + list.map(([k, n]) => '<option value="' + k + '"' + (state.p === k ? ' selected' : '') + '>' + n + '</option>').join('') + '</select>' +
      '<span data-cust class="row" style="' + (state.p === 'custom' ? '' : 'display:none') + '">' + (opts.asOf ? '' : '<input type="date" class="in" data-from value="' + (state.from || '') + '" style="width:auto">') +
      (opts.asOf ? '' : '<span class="hint">إلى</span>') + '<input type="date" class="in" data-to value="' + (state.to || '') + '" style="width:auto"></span></div>';
  }
  function bindPeriod(root, state, onChange) {
    const w = $('[data-period]', root); if (!w) return;
    const sel = $('[data-p]', w), cust = $('[data-cust]', w), f = $('[data-from]', w), t = $('[data-to]', w);
    sel.onchange = () => {
      state.p = sel.value;
      if (state.p === 'custom') { cust.style.display = ''; if (!state.to) { const r = period('month'); state.from = r.from; state.to = r.to; if (f) f.value = state.from; t.value = state.to; } }
      else { cust.style.display = 'none'; Object.assign(state, period(state.p)); }
      onChange();
    };
    if (f) f.onchange = () => { state.from = f.value; onChange(); };
    t.onchange = () => { state.to = t.value; onChange(); };
  }
  const periodLabel = (s) => (s.from || s.to) ? ((s.from ? 'من ' + s.from + ' ' : '') + (s.to ? 'إلى ' + s.to : '')) : 'كلّ الفترات';

  // ——— الرسوم ———
  const MON = ['كانون٢', 'شباط', 'آذار', 'نيسان', 'أيّار', 'حزيران', 'تمّوز', 'آب', 'أيلول', 'تشرين١', 'تشرين٢', 'كانون١'];
  const monName = (k) => MON[+k.slice(5, 7) - 1];
  const short = (n) => { const a = Math.abs(n); return (n < 0 ? '-' : '') + (a >= 1e9 ? (a / 1e9).toFixed(1).replace(/\.0$/, '') + 'B' : a >= 1e6 ? (a / 1e6).toFixed(1).replace(/\.0$/, '') + 'M' : a >= 1e3 ? Math.round(a / 1e3) + 'K' : Math.round(a)); };
  /** أعمدة إيراد/مصروف شهريّة + خطّ الصافي */
  function barChart(data) {
    const W = 640, H = 220, pl = 6, pr = 44, pt = 10, pb = 26;
    const max = Math.max(1, ...data.map((d) => Math.max(d.rev, d.exp)));
    const minNet = Math.min(0, ...data.map((d) => d.net));
    const top = max, bot = minNet;
    const y = (v) => pt + (top - v) / (top - bot) * (H - pt - pb);
    const cw = (W - pl - pr) / data.length, bw = Math.min(16, cw * 0.3);
    let s = '<svg class="chart" viewBox="0 0 ' + W + ' ' + H + '" role="img" aria-label="الإيرادات والمصروفات الشهريّة">';
    [0, 0.5, 1].forEach((f) => { const v = bot + (top - bot) * f; s += '<line x1="' + pl + '" x2="' + (W - pr) + '" y1="' + y(v) + '" y2="' + y(v) + '" stroke="var(--line)" ' + (Math.abs(v) < 1e-9 ? '' : 'stroke-dasharray="3 4"') + '/><text x="' + (W - pr + 6) + '" y="' + (y(v) + 4) + '">' + short(v) + '</text>'; });
    if (bot < 0) s += '<line x1="' + pl + '" x2="' + (W - pr) + '" y1="' + y(0) + '" y2="' + y(0) + '" stroke="var(--line2)"/>';
    const pts = [];
    data.forEach((d, i) => {
      const cx = pl + cw * i + cw / 2;
      s += '<rect x="' + (cx - bw - 1.5) + '" y="' + y(d.rev) + '" width="' + bw + '" height="' + Math.max(0, y(0) - y(d.rev)) + '" rx="3" fill="var(--pos)" opacity=".85"><title>' + monName(d.k) + ' — إيراد ' + E.fmt(d.rev) + '</title></rect>';
      s += '<rect x="' + (cx + 1.5) + '" y="' + y(d.exp) + '" width="' + bw + '" height="' + Math.max(0, y(0) - y(d.exp)) + '" rx="3" fill="var(--neg)" opacity=".78"><title>' + monName(d.k) + ' — مصروف ' + E.fmt(d.exp) + '</title></rect>';
      s += '<text x="' + cx + '" y="' + (H - 7) + '" text-anchor="middle">' + monName(d.k) + '</text>';
      pts.push([cx, y(d.net)]);
    });
    s += '<polyline points="' + pts.map((p) => p.join(',')).join(' ') + '" fill="none" stroke="var(--ink)" stroke-width="1.8" stroke-linejoin="round"/>';
    pts.forEach((p, i) => (s += '<circle cx="' + p[0] + '" cy="' + p[1] + '" r="3" fill="var(--paper)" stroke="var(--ink)" stroke-width="1.6"><title>صافي ' + E.fmt(data[i].net) + '</title></circle>'));
    return s + '</svg><div class="legend" style="margin-top:6px"><span><i style="background:var(--pos)"></i>إيرادات</span><span><i style="background:var(--neg)"></i>مصروفات</span><span><i style="background:var(--ink);height:2px;border-radius:0"></i>الصافي</span></div>';
  }
  function hbars(rows, total, good) {
    if (!rows.length) return '<div class="empty" style="padding:18px">ماكو حركات بهذي الفترة</div>';
    const max = Math.max(...rows.map((r) => Math.abs(r.amt)), 1);
    return rows.map((r) => '<div class="hbar"' + (r.id ? ' data-acc="' + r.id + '" style="cursor:pointer"' : '') + '><span class="nm">' + esc(r.name) + '</span><span class="bar"><i class="' + (good ? 'g' : '') + '" style="width:' + Math.max(2, Math.abs(r.amt) / max * 100) + '%"></i></span><span class="num">' + E.fmt(r.amt) +
      (total ? ' <small class="hint">' + Math.round(r.amt / total * 100) + '٪</small>' : '') + '</span></div>').join('');
  }
  function donut(rows, total) {
    const C = ['#b2432a', '#d17a3a', '#c9a227', '#6b8f3a', '#2b7a8c', '#6b4fa0', '#a14f7d', '#7d837f'];
    const top = rows.slice(0, 7); const rest = rows.slice(7).reduce((s, r) => s + r.amt, 0);
    if (rest > 0) top.push({ name: 'غيرها', amt: rest });
    const R = 54, cx = 70, cy = 70, L = 2 * Math.PI * R;
    let off = 0, s = '<svg viewBox="0 0 140 140" width="140" height="140" role="img" aria-label="توزيع المصاريف"><circle cx="70" cy="70" r="' + R + '" fill="none" stroke="var(--sunk)" stroke-width="20"/>';
    top.forEach((r, i) => { const f = total ? r.amt / total : 0; s += '<circle cx="' + cx + '" cy="' + cy + '" r="' + R + '" fill="none" stroke="' + C[i % C.length] + '" stroke-width="20" stroke-dasharray="' + (f * L) + ' ' + L + '" stroke-dashoffset="' + (-off * L) + '" transform="rotate(-90 70 70)"><title>' + esc(r.name) + '</title></circle>'; off += f; });
    s += '</svg>';
    return '<div class="row" style="gap:18px;align-items:center">' + s + '<div class="legend" style="flex-direction:column;gap:6px">' + top.map((r, i) => '<span><i style="background:' + C[i % C.length] + '"></i>' + esc(r.name) + ' <b class="num">' + (total ? Math.round(r.amt / total * 100) : 0) + '٪</b></span>').join('') + '</div></div>';
  }
  function spark(vals) {
    const W = 120, H = 34; const mx = Math.max(...vals), mn = Math.min(...vals, 0);
    const pts = vals.map((v, i) => [i / Math.max(1, vals.length - 1) * W, H - 3 - (v - mn) / Math.max(1e-9, mx - mn) * (H - 6)]);
    return '<svg viewBox="0 0 ' + W + ' ' + H + '" width="' + W + '" height="' + H + '"><polyline points="' + pts.map((p) => p.join(',')).join(' ') + '" fill="none" stroke="currentColor" stroke-width="1.8"/></svg>';
  }

  function printHead(title, sub) {
    const b = B();
    return '<div class="printhead"><div><b style="font-size:16px">' + esc(b.meta.name) + '</b><div>' + esc(title) + (sub ? ' — ' + esc(sub) : '') + '</div></div><div style="text-align:left">طُبع ' + E.today() + '<br>ميزان</div></div>';
  }
  function exportCSV(name, header, rows) { window.Files.download(name + '-' + E.today() + '.csv', window.Files.csv([header].concat(rows)), 'text/csv;charset=utf-8'); }

  window.UI = { $, $$, esc, ic, av, M, BAL, LOOK, modal, confirm, prompt, toast, pickAccount, pickBtn, bindPick, val, parseAmt, bindAmount, period, periodBar, bindPeriod, periodLabel, barChart, hbars, donut, spark, monName, short, printHead, exportCSV, iso, symOf };
})();
