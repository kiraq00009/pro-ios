/* ميزان — الإعدادات: الدفاتر، العملات، الإقفال، النسخ، المزامنة، القفل، السجلّ */
(function () {
  'use strict';
  const E = window.Engine, U = window.UI, S = window.Store;
  const { $, $$, esc, ic } = U;
  const B = () => S.book;
  const V = (window.Views = window.Views || {});
  const save = () => S.save();
  const go = (h) => (location.hash = h);

  V.settings = function (el) {
    const b = B();
    const books = S.books();
    const sync = S.prefs.sync || {};
    const issues = E.check(b);
    const kb = Math.round(S.usage() / 1024);
    const lastBk = b.meta.backupAt ? new Date(b.meta.backupAt).toLocaleDateString('en-CA') : 'أبدًا';
    el.innerHTML = `
      <div class="ph"><div><h1>الإعدادات</h1><div class="sub">${esc(b.meta.name)} · ${b.entries.length} قيد · ${b.accounts.filter((a) => !a.group).length} حساب · ${kb} KB</div></div></div>
      <div class="cols"><div class="stack">
        <div class="card"><h3>الدفاتر <small>كلّ دفتر مستقلّ (شركة، بيت، مشروع)</small></h3><div class="list">
          ${books.map((x) => '<div class="li" data-book="' + x.id + '"><span class="av" style="background:var(--accbg);color:var(--acc2)">' + ic('book') + '</span><div class="grow"><div class="t">' + esc(x.name) + (x.id === b.id ? ' <span class="pill acc">مفتوح</span>' : '') + '</div><div class="s">' + (x.entries || 0) + ' قيد · ' + x.base + '</div></div>' + (x.id === b.id ? '' : '<button class="icon-btn" data-delbook="' + x.id + '" title="حذف">' + ic('trash') + '</button>') + '</div>').join('')}
        </div><div class="row" style="margin-top:10px"><button class="btn" data-newbook>${ic('plus')} دفتر جديد</button><button class="btn ghost" data-rename>${ic('edit')} تسمية هذا الدفتر</button></div></div>

        <div class="card"><h3>العملات وأسعار الصرف <small>العملة الأساسيّة: ${b.meta.base}</small></h3>
          <div class="tw"><table class="t"><thead><tr><th>العملة</th><th>الرمز</th><th class="n">السعر بـ${b.meta.base}</th><th></th></tr></thead><tbody>
          ${b.currencies.map((c, i) => '<tr><td>' + esc(c.name) + ' <small class="hint">' + c.code + '</small></td><td>' + esc(c.sym) + '</td><td class="n">' + (c.code === b.meta.base ? '1' : '<input class="in amt" data-rate="' + i + '" value="' + c.rate + '" style="width:120px;min-height:34px;padding:5px 8px">') + '</td><td>' + (c.code !== b.meta.base && !b.accounts.some((a) => a.cur === c.code) && !b.entries.some((e) => e.lines.some((l) => l.cur === c.code)) ? '<button class="icon-btn" data-delcur="' + i + '">' + ic('x') + '</button>' : '') + '</td></tr>').join('')}
          </tbody></table></div><div class="row" style="margin-top:10px"><button class="btn sm" data-addcur>${ic('plus')} عملة</button><span class="hint">السعر الجديد ينطبق على السندات الجديدة؛ القديمة تبقى بسعرها.</span></div></div>

        <div class="card"><h3>الإقفال ونهاية السنة</h3>
          <div class="sumrow"><span>الفترة مقفلة لحدّ</span><b>${b.meta.lockDate || 'مو مقفلة'}</b></div>
          <div class="row" style="margin-top:10px"><button class="btn" data-lock>${ic('lock')} تاريخ الإقفال</button><button class="btn" data-close>${ic('flag')} إقفال سنة ماليّة</button><button class="btn" data-dist>${ic('pie')} توزيع أرباح على الشركاء</button></div>
          <div class="hint" style="margin-top:8px">الإقفال يمنع التعديل والحذف على القيود القديمة حتى ما يتغيّر شي بعد ما تطلع التقارير.</div></div>
      </div><div class="stack">
        <div class="card"><h3>النسخ الاحتياطيّ <small>آخر نسخة: ${lastBk}</small></h3>
          <div class="hint" style="margin-bottom:10px">البيانات محفوظة بهذا الجهاز. سوّي نسخة دوريًّا أو شغّل المزامنة.</div>
          <div class="row"><button class="btn pri" data-backup>${ic('dl')} تنزيل نسخة</button><label class="btn">${ic('up')} استعادة نسخة<input type="file" accept=".json,application/json" data-restore hidden></label><button class="btn" data-xls>${ic('dl')} كلّ الحركات Excel</button></div></div>

        <div class="card"><h3>المزامنة بين الأجهزة <small>${sync.on ? '<span class="pill pos">شغّالة</span>' : 'مطفأة'}</small></h3>
          <div class="hint" style="margin-bottom:10px">نفس الرمز على الموبايل واللابتوب ⇒ نفس الدفاتر. البيانات تتشفّر بجهازك قبل ما تطلع، والخادم ما يكدر يقراها. لا تنسى الرمز: بدونه ما ترجع.</div>
          ${sync.on ? `<div class="sumrow"><span>آخر مزامنة</span><b>${sync.at ? new Date(sync.at).toLocaleString('en-GB') : '—'}</b></div>${window.Sync.err ? '<div class="err">' + esc(window.Sync.err) + '</div>' : ''}
            <div class="row" style="margin-top:10px"><button class="btn" data-spush>${ic('up')} ارفع هسّه</button><button class="btn" data-spull>${ic('dl')} اسحب</button><button class="btn ghost danger" data-soff>إيقاف</button></div>`
            : '<button class="btn pri" data-son>' + ic('cloud') + ' شغّل المزامنة</button>'}</div>

        <div class="card"><h3>الحماية والمظهر</h3>
          <div class="row between"><span>قفل برمز عند الفتح</span><button class="btn sm" data-pin>${S.prefs.pin ? 'غيّر / شيل الرمز' : 'حطّ رمز'}</button></div>
          <div class="row between" style="margin-top:10px"><span>المظهر</span><div class="seg">${[['auto', 'تلقائيّ'], ['light', 'فاتح'], ['dark', 'داكن']].map(([k, n]) => '<button data-theme="' + k + '" class="' + (S.prefs.theme === k ? 'on' : '') + '">' + n + '</button>').join('')}</div></div></div>

        <div class="card"><h3>فحص سلامة الدفتر</h3>${issues.length ? issues.slice(0, 8).map((x) => '<div class="err">• ' + esc(x) + '</div>').join('') : '<div class="pos">' + ic('check').replace('<svg', '<svg style="display:inline;width:16px;vertical-align:-3px"') + ' كلّ القيود متوازنة وميزان المراجعة مضبوط</div>'}</div>

        <div class="card"><h3>سجلّ التعديلات <small>آخر ٤٠</small></h3><div style="max-height:300px;overflow:auto">${(b.log || []).slice(-40).reverse().map((x) => '<div class="sumrow"><span>' + logName(x.act) + ' ' + esc(x.what) + '</span><span class="hint num" style="white-space:nowrap">' + new Date(x.t).toLocaleString('en-GB', { dateStyle: 'short', timeStyle: 'short' }) + '</span></div>').join('') || '<div class="empty">—</div>'}</div></div>

        <div class="card"><h3>منطقة الخطر</h3><button class="btn danger" data-wipe>${ic('trash')} مسح كلّ قيود هذا الدفتر</button></div>
      </div></div>`;

    el.onclick = async (e) => {
      const t = e.target.closest('button,[data-book]'); if (!t) return;
      const d = t.dataset;
      if (d.delbook) { e.stopPropagation(); const x = books.find((y) => y.id === d.delbook); if (await U.confirm('تحذف دفتر «' + esc(x.name) + '» بكلّ قيوده من هذا الجهاز؟ (إذا عندك نسخة تكدر ترجّعه)', 'احذف', true)) { S.removeBook(x.id); V.settings(el); } return; }
      if (d.book && d.book !== b.id) { S.open(d.book); window.App.boot(); U.toast('انفتح «' + S.book.meta.name + '»'); return; }
      if ('newbook' in d) return newBook();
      if ('rename' in d) { const n = await U.prompt('اسم الدفتر', b.meta.name); if (n) { S.rename(n); V.settings(el); window.App.chrome(); } return; }
      if ('addcur' in d) return addCur(el);
      if (d.delcur) { b.currencies.splice(+d.delcur, 1); save(); return V.settings(el); }
      if ('lock' in d) { const v = await U.prompt('اقفل كلّ القيود لحدّ تاريخ (yyyy-mm-dd) — فارغ = فتح', b.meta.lockDate || E.today()); if (v === null) return; if (v && !/^\d{4}-\d{2}-\d{2}$/.test(v)) return U.toast('اكتب التاريخ مثل 2026-12-31', true); b.meta.lockDate = v; E.audit(b, 'lock', v || 'فتح'); save(); return V.settings(el); }
      if ('close' in d) return closeYear(el);
      if ('dist' in d) return distribute(el);
      if ('backup' in d) { window.Files.backup(); U.toast('نزلت النسخة'); return V.settings(el); }
      if ('xls' in d) return exportAll();
      if ('son' in d) return syncOn(el);
      if ('spush' in d) { try { await window.Sync.push(); U.toast('ارتفعت'); } catch (err) { if (window.Sync.err === 'conflict' && (await U.confirm('النسخة بالخادم أحدث (من جهاز ثاني). تريد تكتب فوقها بنسخة هذا الجهاز؟', 'اكتب فوقها', true))) { await window.Sync.push(true); U.toast('ارتفعت'); } else U.toast(err.message, true); } return V.settings(el); }
      if ('spull' in d) { try { const r = await window.Sync.pull(true); if (!r) return U.toast('ماكو نسخة بالخادم'); if (await U.confirm('أبدّل الدفاتر اللي بهذا الجهاز بنسخة الخادم؟', 'بدّل', true)) { window.Sync.apply(r); window.App.boot(); U.toast('انسحبت'); } } catch (err) { U.toast(err.message, true); } return; }
      if ('soff' in d) { S.prefs.sync = null; S.savePrefs(); return V.settings(el); }
      if ('pin' in d) return setPin(el);
      if (d.theme) { S.prefs.theme = d.theme; S.savePrefs(); window.App.theme(); return V.settings(el); }
      if ('wipe' in d) { if (await U.confirm('تمسح كلّ القيود (' + b.entries.length + ') وتبقى الحسابات؟ ما ترجع إلّا من نسخة احتياطيّة.', 'امسح', true)) { b.entries = []; b.seq.entry = 0; b.meta.lockDate = ''; E.audit(b, 'wipe', 'مسح القيود'); save(); U.toast('انمسحت'); V.settings(el); } }
    };
    $$('[data-rate]', el).forEach((x) => (x.onchange = () => { const v = U.parseAmt(x.value); if (v > 0) { b.currencies[+x.dataset.rate].rate = v; E.audit(b, 'rate', b.currencies[+x.dataset.rate].code + ' = ' + v); save(); U.toast('انحفظ السعر'); } }));
    const rs = $('[data-restore]', el);
    rs.onchange = async () => {
      const f = rs.files[0]; if (!f) return;
      try {
        const obj = JSON.parse(await f.text());
        const exists = S.books().some((x) => x.id === obj.id);
        const asNew = exists ? !(await U.confirm('هذا الدفتر موجود. أكتب فوقه بالنسخة؟ (لا = أفتحه كدفتر جديد)', 'اكتب فوقه', true)) : false;
        S.importBook(obj, asNew); window.App.boot(); U.toast('رجعت النسخة: ' + S.book.meta.name);
      } catch (err) { U.toast('الملفّ مو نسخة ميزان: ' + err.message, true); }
    };
  };
  const logName = (a) => ({ post: '➕', edit: '✏️', delete: '🗑', 'add-acc': '👤', 'edit-acc': '✏️', 'del-acc': '🗑', lock: '🔒', rate: '💱', wipe: '⚠️' }[a] || '•');

  V.newBook = newBook;
  function newBook() {
    U.modal({ title: 'دفتر جديد', body: '<div class="form"><label class="f">الاسم<input class="in" id="nb" placeholder="مثلًا: شركتي، البيت، مشروع المحلّ"></label><label class="f">العملة الأساسيّة<select class="in" id="nc"><option value="IQD">دينار عراقيّ</option><option value="USD">دولار</option><option value="EUR">يورو</option></select></label></div>',
      actions: [{ label: 'إلغاء', cls: 'ghost' }, { label: 'سوّي الدفتر', cls: 'pri', onClick: (ov) => { const n = $('#nb', ov).value.trim(); if (!n) throw new Error('اكتب اسم'); S.create(n, $('#nc', ov).value); window.App.boot(); U.toast('انفتح «' + n + '»'); } }] });
  }
  function addCur(el) {
    const b = B();
    U.modal({ title: 'عملة جديدة', body: '<div class="grid2"><label class="f">الرمز الدوليّ<input class="in" id="cc" placeholder="TRY" maxlength="4" style="text-transform:uppercase"></label><label class="f">الاسم<input class="in" id="cn" placeholder="ليرة تركيّة"></label><label class="f">الرمز المختصر<input class="in" id="cs" placeholder="₺"></label><label class="f">السعر بـ' + b.meta.base + '<input class="in amt" id="cr" inputmode="decimal"></label></div>',
      actions: [{ label: 'إلغاء', cls: 'ghost' }, { label: 'إضافة', cls: 'pri', onClick: (ov) => {
        const code = $('#cc', ov).value.trim().toUpperCase(), rate = U.parseAmt($('#cr', ov).value);
        if (!/^[A-Z]{3,4}$/.test(code)) throw new Error('الرمز ٣ حروف إنكليزيّة'); if (b.currencies.some((c) => c.code === code)) throw new Error('موجودة'); if (!(rate > 0)) throw new Error('اكتب السعر');
        b.currencies.push({ code, name: $('#cn', ov).value.trim() || code, sym: $('#cs', ov).value.trim() || code, dec: 2, rate }); save(); V.settings(el);
      } }] });
  }
  function closeYear(el) {
    const b = B(); const y = new Date().getFullYear() - (new Date().getMonth() < 2 ? 1 : 0);
    U.modal({ title: 'إقفال سنة ماليّة', body: '<p class="hint">ينقل صافي ربح/خسارة السنة من حسابات الإيرادات والمصروفات إلى «الأرباح المدوّرة»، ويقفل الفترة. التقارير القديمة تبقى تطلع صحّ.</p><label class="f">نهاية السنة<input type="date" class="in" id="cy" value="' + y + '-12-31"></label><label class="chk" style="margin-top:10px"><input type="checkbox" id="cl" checked> اقفل الفترة بعد الإقفال</label>',
      actions: [{ label: 'إلغاء', cls: 'ghost' }, { label: 'إقفال', cls: 'pri', onClick: (ov) => { const net = E.incomeStatement(b, { to: $('#cy', ov).value }).net; const e = E.closeYear(b, $('#cy', ov).value, $('#cl', ov).checked); save(); U.toast('انقفلت السنة — ' + (net >= 0 ? 'ربح ' : 'خسارة ') + E.fmt(Math.abs(net)) + ' (قيد #' + e.no + ')'); V.settings(el); } }] });
  }
  function distribute(el) {
    const b = B();
    const ps = b.accounts.filter((a) => !a.group && a.sub === 'partner' && !a.archived);
    const ret = -E.balance(b, E.sysAcc(b, 'retained').id).base;
    U.modal({ title: 'توزيع أرباح على الشركاء', body: (ps.length ? '<div class="hint" style="margin-bottom:8px">' + ps.map((p) => esc(p.name) + ' ' + (p.share || 0) + '٪').join(' · ') + '</div>' : '<div class="err">ماكو شركاء — ضيف حسابات «شريك» بنسبهم</div>') +
      '<label class="f">المبلغ (الأرباح المدوّرة المتاحة ' + E.fmt(ret) + ')<input class="in amt big" id="dm" inputmode="decimal" value="' + (ret > 0 ? E.fmt(ret) : '') + '"></label><label class="f" style="margin-top:10px">التاريخ<input type="date" class="in" id="dd" value="' + E.today() + '"></label>',
      actions: [{ label: 'إلغاء', cls: 'ghost' }, { label: 'وزّع', cls: 'pri', onClick: (ov) => { const e = E.distributeProfit(b, { amount: U.parseAmt($('#dm', ov).value), date: $('#dd', ov).value }); save(); U.toast('انوزّعت — قيد #' + e.no); V.settings(el); } }] });
  }
  function exportAll() {
    const b = B(); const rows = [];
    b.entries.slice().sort((x, y) => (x.date < y.date ? -1 : x.date > y.date ? 1 : x.no - y.no)).forEach((e) => e.lines.forEach((l) => { const a = E.acc(b, l.a) || {}; rows.push([e.no, e.date, E.KINDS[e.kind], e.memo, a.code, a.name, l.dr || '', l.cr || '', l.cur, l.rate, E.r2((l.dr - l.cr) * l.rate), l.cc ? (E.acc(b, l.cc) || {}).name : '', l.cat ? (E.acc(b, l.cat) || {}).name : '', e.ref, e.due || '']); }));
    U.exportCSV('ميزان-كل-الحركات', ['رقم القيد', 'التاريخ', 'النوع', 'البيان', 'رقم الحساب', 'الحساب', 'مدين', 'دائن', 'العملة', 'السعر', 'بالأساس', 'على حساب', 'نوع المصروف', 'المستند', 'الاستحقاق'], rows);
  }
  function syncOn(el) {
    const gen = () => { const w = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; const r = crypto.getRandomValues(new Uint8Array(16)); return Array.from(r, (x) => w[x % w.length]).join('').replace(/(.{4})(?=.)/g, '$1-'); };
    U.modal({ title: 'تشغيل المزامنة', body: '<p class="hint">أوّل جهاز: خذ الرمز الجديد واحفظه بمكان آمن. الجهاز الثاني: اكتب نفس الرمز.</p><label class="f">رمز المزامنة<input class="in num" id="sc" value="' + gen() + '" style="letter-spacing:1px"></label><div class="row" style="margin-top:8px"><button class="btn sm" id="scopy">' + ic('copy') + ' نسخ</button><button class="btn sm ghost" id="sgen">رمز جديد</button></div>',
      onMount: (ov) => { $('#scopy', ov).onclick = () => { navigator.clipboard && navigator.clipboard.writeText($('#sc', ov).value); U.toast('انسخ'); }; $('#sgen', ov).onclick = () => ($('#sc', ov).value = gen()); },
      actions: [{ label: 'إلغاء', cls: 'ghost' }, { label: 'شغّل', cls: 'pri', onClick: async (ov) => {
        const code = $('#sc', ov).value.trim(); if (code.replace(/-/g, '').length < 10) throw new Error('الرمز قصير (١٠ حروف على الأقلّ)');
        S.prefs.sync = { on: true, code, ver: 0 }; S.savePrefs();
        const r = await window.Sync.pull(true);
        if (r && (await U.confirm('لكيت دفاتر محفوظة بهذا الرمز (' + r.data.books.length + ' دفتر). أسحبها لهذا الجهاز؟ (لا = أرفع دفاتر هذا الجهاز فوقها)', 'اسحبها'))) { window.Sync.apply(r); window.App.boot(); U.toast('انسحبت الدفاتر'); }
        else { if (r) S.prefs.sync.ver = r.ver; await window.Sync.push(); U.toast('المزامنة شغّالة'); V.settings(el); }
      } }] });
  }
  function setPin(el) {
    U.modal({ title: 'رمز القفل', body: '<label class="f">رمز من ٤ أرقام أو أكثر (فارغ = بدون قفل)<input class="in num" id="pn" inputmode="numeric" type="password" maxlength="8"></label><p class="hint">إذا نسيت الرمز تحتاج نسخة احتياطيّة. الرمز يحمي من الفتح العابر بس.</p>',
      actions: [{ label: 'إلغاء', cls: 'ghost' }, { label: 'حفظ', cls: 'pri', onClick: async (ov) => { const v = $('#pn', ov).value.trim(); if (v && !/^\d{4,8}$/.test(v)) throw new Error('٤–٨ أرقام'); S.prefs.pin = v ? await window.App.hash(v) : ''; S.savePrefs(); U.toast(v ? 'انحطّ القفل' : 'انشال القفل'); V.settings(el); } }] });
  }
})();
