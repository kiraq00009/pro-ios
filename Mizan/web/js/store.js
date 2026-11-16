/* ميزان — الحفظ المحليّ، الدفاتر المتعدّدة، النسخ الاحتياطيّ، المزامنة المشفّرة */
(function () {
  'use strict';
  const E = window.Engine;
  const K = { index: 'mizan.books', book: (id) => 'mizan.book.' + id, cur: 'mizan.current', prefs: 'mizan.prefs' };
  const get = (k, d) => { try { const v = localStorage.getItem(k); return v ? JSON.parse(v) : d; } catch (e) { return d; } };
  const set = (k, v) => { try { localStorage.setItem(k, JSON.stringify(v)); return true; } catch (e) { return false; } };

  const Store = {
    book: null,
    listeners: [],
    dirty: false,
    prefs: Object.assign({ theme: 'auto', pin: '', sync: null }, get(K.prefs, {})),

    books() { return get(K.index, []); },
    savePrefs() { set(K.prefs, this.prefs); },

    open(id) {
      const raw = get(K.book(id), null);
      if (!raw) return false;
      try { this.book = E.migrate(raw); } catch (e) { return false; }
      set(K.cur, id);
      return true;
    },
    boot() {
      const cur = get(K.cur, null);
      if (cur && this.open(cur)) return true;
      const list = this.books();
      if (list.length && this.open(list[0].id)) return true;
      return false;
    },
    create(name, base) {
      const b = E.newBook(name, base);
      const list = this.books();
      list.push({ id: b.id, name: b.meta.name, base: b.meta.base, created: b.meta.created });
      set(K.index, list);
      this.book = b;
      this.save(true);
      set(K.cur, b.id);
      return b;
    },
    rename(name) {
      this.book.meta.name = name;
      const list = this.books().map((x) => (x.id === this.book.id ? Object.assign(x, { name }) : x));
      set(K.index, list); this.save();
    },
    removeBook(id) {
      set(K.index, this.books().filter((x) => x.id !== id));
      try { localStorage.removeItem(K.book(id)); } catch (e) {}
      if (this.book && this.book.id === id) { this.book = null; try { localStorage.removeItem(K.cur); } catch (e) {} }
    },
    /** يحفظ فورًا؛ يرجّع false إذا التخزين امتلى */
    save(silent) {
      if (!this.book) return false;
      this.book.meta.saved = Date.now();
      const ok = set(K.book(this.book.id), this.book);
      const list = this.books();
      const row = list.find((x) => x.id === this.book.id);
      if (row) { row.name = this.book.meta.name; row.saved = this.book.meta.saved; row.entries = this.book.entries.length; set(K.index, list); }
      this.dirty = true;
      if (!silent) this.listeners.forEach((f) => f());
      if (this.prefs.sync && this.prefs.sync.on) Sync.schedule();
      return ok;
    },
    importBook(obj, asNew) {
      const b = E.migrate(obj);
      if (asNew || !this.books().some((x) => x.id === b.id)) {
        if (asNew) b.id = E.uid();
        const list = this.books().filter((x) => x.id !== b.id);
        list.push({ id: b.id, name: b.meta.name, base: b.meta.base, created: b.meta.created });
        set(K.index, list);
      }
      this.book = b; this.save(); set(K.cur, b.id);
      return b;
    },
    usage() {
      let n = 0; try { for (let i = 0; i < localStorage.length; i++) { const k = localStorage.key(i); n += (localStorage.getItem(k) || '').length; } } catch (e) {}
      return n * 2;
    },
  };

  // ———————————— المزامنة المشفّرة (الخادم يشوف بس ملفّ مشفّر) ————————————
  const enc = new TextEncoder(), dec = new TextDecoder();
  const hex = (buf) => Array.from(new Uint8Array(buf)).map((x) => x.toString(16).padStart(2, '0')).join('');
  const b64 = (buf) => { let s = ''; const u = new Uint8Array(buf); for (let i = 0; i < u.length; i += 0x8000) s += String.fromCharCode.apply(null, u.subarray(i, i + 0x8000)); return btoa(s); };
  const unb64 = (s) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));

  async function derive(code) {
    const base = await crypto.subtle.importKey('raw', enc.encode(code), 'PBKDF2', false, ['deriveBits']);
    const bits = await crypto.subtle.deriveBits({ name: 'PBKDF2', salt: enc.encode('mizan-sync-v1'), iterations: 150000, hash: 'SHA-256' }, base, 512);
    const key = await crypto.subtle.importKey('raw', bits.slice(0, 32), 'AES-GCM', false, ['encrypt', 'decrypt']);
    const idh = await crypto.subtle.digest('SHA-256', bits.slice(32));
    return { key, id: hex(idh).slice(0, 32), auth: hex(bits.slice(32)) };
  }

  const Sync = {
    api: (location.pathname.replace(/[^/]*$/, '') + 'api/'),
    timer: null, busy: false, last: null, err: '',
    async keys() {
      const s = Store.prefs.sync; if (!s || !s.code) throw new Error('ماكو رمز مزامنة');
      if (!this._k || this._code !== s.code) { this._k = await derive(s.code); this._code = s.code; }
      return this._k;
    },
    schedule() { clearTimeout(this.timer); this.timer = setTimeout(() => this.push().catch(() => {}), 4000); },
    async push(force) {
      if (this.busy) return; this.busy = true;
      try {
        const k = await this.keys();
        const data = { books: Store.books().map((x) => ({ meta: x, book: get(K.book(x.id), null) })).filter((x) => x.book) };
        const iv = crypto.getRandomValues(new Uint8Array(12));
        const ct = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, k.key, enc.encode(JSON.stringify(data)));
        const s = Store.prefs.sync;
        const r = await fetch(this.api + 'box/' + k.id, { method: 'PUT', headers: { 'Content-Type': 'application/json', 'X-Auth': k.auth, 'X-Ver': force ? '' : String(s.ver || 0) },
          body: JSON.stringify({ iv: b64(iv), ct: b64(ct) }) });
        if (r.status === 409) { this.err = 'conflict'; throw new Error('الدفتر تغيّر من جهاز ثاني — اسحب أوّلًا'); }
        if (!r.ok) throw new Error('الخادم ردّ ' + r.status);
        const j = await r.json();
        s.ver = j.ver; s.at = Date.now(); Store.savePrefs(); Store.dirty = false; this.err = ''; this.last = Date.now();
        return j;
      } catch (e) { this.err = this.err || e.message; throw e; } finally { this.busy = false; }
    },
    /** يسحب النسخة؛ يرجّع null إذا ماكو جديد */
    async pull(always) {
      const k = await this.keys();
      const r = await fetch(this.api + 'box/' + k.id, { headers: { 'X-Auth': k.auth } });
      if (r.status === 404) return null;
      if (r.status === 403) throw new Error('الرمز غلط لهذا الصندوق');
      if (!r.ok) throw new Error('الخادم ردّ ' + r.status);
      const j = await r.json();
      const s = Store.prefs.sync;
      if (!always && j.ver <= (s.ver || 0)) return null;
      const pt = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: unb64(j.iv) }, k.key, unb64(j.ct));
      const data = JSON.parse(dec.decode(pt));
      return { ver: j.ver, data };
    },
    apply(res) {
      const idx = [];
      res.data.books.forEach((x) => { set(K.book(x.meta.id), x.book); idx.push(x.meta); });
      set(K.index, idx);
      Store.prefs.sync.ver = res.ver; Store.prefs.sync.at = Date.now(); Store.savePrefs();
      Store.dirty = false;
      const cur = get(K.cur, null);
      if (!(cur && Store.open(cur)) && idx[0]) Store.open(idx[0].id);
    },
  };

  // ———————————— تصدير ————————————
  function download(name, text, type) {
    const blob = new Blob([text], { type: type || 'application/octet-stream' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob); a.download = name;
    document.body.appendChild(a); a.click();
    setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1500);
  }
  function csv(rows) {
    const q = (v) => { const s = v == null ? '' : String(v); return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };
    return '﻿' + rows.map((r) => r.map(q).join(',')).join('\r\n');
  }
  function backup() {
    const b = Store.book;
    download('ميزان-' + b.meta.name + '-' + E.today() + '.json', JSON.stringify(b), 'application/json');
    b.meta.backupAt = Date.now(); Store.save(true);
  }

  window.Store = Store; window.Sync = Sync; window.Files = { download, csv, backup };
})();
