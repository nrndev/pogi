// pogi console: the shell's behaviour. Pages are server-rendered with htmx; this file only adds
// what htmx cannot do: the ⌘K palette, the drawer, toasts, shortcuts, theme and sidebar state.
// Everything is delegated on document, so it survives hx-boost body swaps.
(() => {
  const $ = (s, el = document) => el.querySelector(s);
  const setCookie = (k, v) => { document.cookie = `${k}=${encodeURIComponent(v)}; path=/; max-age=31536000; samesite=lax`; };
  const getCookie = k => decodeURIComponent((document.cookie.split('; ').find(c => c.startsWith(k + '=')) || '=').split('=')[1] || '');
  const typing = () => /INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName) || document.activeElement.isContentEditable;

  // ---- behaviour the templates ask for with data attributes (the CSP forbids inline handlers) ----
  // data-nosubmit: a form that is never sent by Enter. Capture phase, so it runs first, as an inline onsubmit did.
  document.addEventListener('submit', e => { if (e.target.matches('[data-nosubmit]')) e.preventDefault(); }, true);
  // data-autosubmit: send the form when the field changes
  document.addEventListener('change', e => { if (e.target.matches('[data-autosubmit]')) e.target.form.requestSubmit(); });
  // data-filter: hide the service tiles, or the table rows, that do not match the typed text
  document.addEventListener('input', e => {
    const i = e.target, kind = i.dataset && i.dataset.filter; if (!kind) return;
    const q = i.value.toLowerCase().trim();
    if (kind === 'tiles') {
      document.querySelectorAll('.tile').forEach(t => { t.hidden = !!q && t.dataset.q.indexOf(q) < 0; });
      document.querySelectorAll('.cat').forEach(c => { c.hidden = !c.querySelector('.tile:not([hidden])'); });
    } else {
      i.closest('main').querySelectorAll('.dt tbody tr').forEach(r => { r.hidden = !!q && r.textContent.toLowerCase().indexOf(q) < 0; });
    }
  });

  // ---- theme ----
  const isDark = () => { const t = document.documentElement.dataset.theme; return t ? t === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches; };
  function themeIcon() { const u = $('#themeBtn use'); if (u) { u.setAttribute('href', isDark() ? '#i-sun' : '#i-moon'); $('#themeBtn').title = isDark() ? 'Switch to light' : 'Switch to dark'; } }
  function toggleTheme() { const t = isDark() ? 'light' : 'dark'; document.documentElement.dataset.theme = t; setCookie('pogi-theme', t); themeIcon(); }
  matchMedia('(prefers-color-scheme: dark)').addEventListener('change', themeIcon);

  // ---- sidebar: "mini" collapses a wide window, "wide" expands a narrow one ----
  function toggleSide() {
    const app = $('#app'), narrow = innerWidth <= 1100;
    app.classList.remove(narrow ? 'mini' : 'wide');
    const on = app.classList.toggle(narrow ? 'wide' : 'mini');
    setCookie('pogi-side', on ? (narrow ? 'wide' : 'mini') : '');
    sideTitle();
  }
  // the footer button reads "Expand sidebar" while the sidebar is a rail
  function sideTitle() {
    const app = $('#app'), b = $('.collapse'); if (!app || !b) return;
    const rail = innerWidth <= 1100 ? !app.classList.contains('wide') : app.classList.contains('mini');
    b.title = (rail ? 'Expand' : 'Collapse') + ' sidebar (⌘B)';
  }
  addEventListener('resize', () => sideTitle());
  document.addEventListener('htmx:afterSettle', () => sideTitle());
  document.addEventListener('DOMContentLoaded', () => sideTitle());

  // ---- toasts ----
  // Toasts queue (at most 3 waiting; the oldest is dropped) and show one at a time.
  // The hide timer stops while the toast is hovered or has focus.
  let tt, shown = false, held = false; const tq = [];
  function toast(msg, kind, href, label) {
    tq.push([msg, kind, href, label]); if (tq.length > 3) tq.shift();
    if (!shown) nextToast();
  }
  function hideLater(ms) {
    clearTimeout(tt);
    tt = setTimeout(() => {
      const t = $('#toast'); if (t) t.classList.remove('on');
      setTimeout(() => { shown = false; if (tq.length) nextToast(); else if (t && !t.classList.contains('on')) t.textContent = ''; }, 300);
    }, ms);
  }
  function nextToast() {
    const t = $('#toast'), [msg, kind, href, label] = tq.shift() || []; if (!t || msg == null) return;
    shown = true;
    t.innerHTML = '';
    if (kind) { const d = document.createElement('span'); d.className = 'dot'; d.style.background = `var(--${kind})`; t.append(d); }
    t.append(document.createTextNode(msg));
    if (href) {
      const a = document.createElement('a'); a.textContent = label || 'View'; a.href = href;
      if (href.includes('/_pogi/requests/')) a.dataset.drawer = '';
      if (href === '#bell') a.dataset.js = 'bell';
      t.append(a);
    }
    t.classList.add('on'); t.dataset.ms = kind === 'bad' ? 5000 : 2500;
    if (!held) hideLater(+t.dataset.ms);
  }
  const hold = (on, e) => { const t = $('#toast'); if (!t || !shown || !t.contains(e.target)) return; held = on; if (on) clearTimeout(tt); else hideLater(+t.dataset.ms); };
  document.addEventListener('mouseover', e => hold(true, e));
  document.addEventListener('mouseout', e => hold(false, e));
  document.addEventListener('focusin', e => hold(true, e));
  document.addEventListener('focusout', e => hold(false, e));

  // ---- overlays ----
  // Each overlay is a dialog or menu: opening moves focus into it, Tab stays inside a modal one (the page behind is inert),
  // and closing with Esc, the scrim or a close button hands focus back to whatever opened it.
  const overlays = ['drawer', 'palette', 'pop', 'menu', 'bell', 'keys'];
  const isOn = id => { const e = document.getElementById(id); return !!e && e.classList.contains('on'); };
  const inOverlay = el => !!el && overlays.some(id => { const e = document.getElementById(id); return e && e.contains(el); });
  const FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]):not([type=hidden]), select:not([disabled]), textarea:not([disabled]), summary, [tabindex]:not([tabindex="-1"])';
  const focusables = el => [...el.querySelectorAll(FOCUSABLE)].filter(x => x.tabIndex >= 0 && x.getClientRects().length && !x.closest('[hidden]'));
  let ret = null;   // what to refocus when the overlay closes
  function mark() { const a = document.activeElement; ret = inOverlay(a) ? ret : a; }
  function sync() {
    const app = $('#app'); if (app) app.inert = isOn('drawer') || isOn('palette') || isOn('keys');
    document.querySelectorAll('[data-js=scope], [data-js=bell], [data-js=keys]').forEach(b => b.setAttribute('aria-expanded', isOn(b.dataset.js === 'scope' ? 'pop' : b.dataset.js)));
    const m = $('#menu');
    document.querySelectorAll('[data-menu]').forEach(b => b.setAttribute('aria-expanded', !!m && m.classList.contains('on') && m.dataset.for === b.dataset.menu));
    const pq = $('#pq'); if (pq) pq.setAttribute('aria-expanded', isOn('palette'));
  }
  function focusIn(el) { const f = el.id === 'palette' ? $('#pq') : focusables(el)[0]; if (f) f.focus(); else { el.tabIndex = -1; el.focus(); } }
  function show(el) { el.classList.add('on'); sync(); focusIn(el); }
  function closeAll() { overlays.forEach(id => { const e = document.getElementById(id); if (e) e.classList.remove('on'); }); const s = $('#scrim'); if (s) s.classList.remove('on'); sync(); }
  function dismiss() {
    const was = overlays.some(isOn), r = ret; ret = null; closeAll();
    if (was && r && r.isConnected && r !== document.body) r.focus();
  }
  function scrim() { $('#scrim').classList.add('on'); }
  let marked = false;   // openDrawer already recorded the opener
  function openDrawer(url) { mark(); marked = true; closeAll(); htmx.ajax('GET', url, { target: '#drawer', swap: 'innerHTML' }); }
  function anchor(el, pop, width) { const b = el.getBoundingClientRect(); pop.style.top = b.bottom + 6 + 'px'; pop.style.left = Math.max(12, Math.min(innerWidth - width - 12, b.right - width)) + 'px'; }
  // a shown menu taller than the room below its button scrolls, and opens above the button when there is more room there
  function fit(el, menu) {
    const b = el.getBoundingClientRect(), below = innerHeight - b.bottom - 18, above = b.top - 18;
    menu.style.maxHeight = ''; const h = menu.offsetHeight; if (h <= below) return;
    if (above > below) { const m = Math.min(h, above); menu.style.maxHeight = m + 'px'; menu.style.top = b.top - 6 - m + 'px'; }
    else menu.style.maxHeight = below + 'px';
  }

  // ---- labels and errors ----
  let uid = 0;
  // a .field's <label> names its control; a placeholder-only input takes the placeholder as its name; required controls say so
  function a11y(root = document) {
    root.querySelectorAll('.field > label:not([for])').forEach(l => {
      const c = l.parentElement.querySelector('input:not([type=hidden]), select, textarea'); if (!c) return;
      c.id = c.id || 'f' + ++uid; l.htmlFor = c.id;
    });
    root.querySelectorAll('input[placeholder], textarea[placeholder]').forEach(c => {
      if (!(c.labels && c.labels.length) && !c.hasAttribute('aria-label') && !c.hasAttribute('aria-labelledby')) c.setAttribute('aria-label', c.getAttribute('placeholder'));
    });
    root.querySelectorAll('[required]:not([aria-required])').forEach(c => c.setAttribute('aria-required', 'true'));
  }
  // a form error that opens with a field's label ("Delay: “x” is not a whole number") is tied to that field
  function linkErrors(root) {
    const f = $('.flash', root); if (!f) return;
    f.id = f.id || 'derr';
    const msg = f.textContent.trim().toLowerCase();
    const l = [...root.querySelectorAll('.field > label')].find(x => { const t = ((x.firstChild || {}).textContent || '').trim().toLowerCase(); return t && msg.startsWith(t) && /^[:\s]/.test(msg.slice(t.length)); });
    const c = l && l.htmlFor && document.getElementById(l.htmlFor);
    if (c) { c.setAttribute('aria-describedby', f.id); c.setAttribute('aria-invalid', 'true'); }
  }
  document.addEventListener('DOMContentLoaded', () => a11y());
  document.addEventListener('htmx:afterSettle', () => a11y());

  // ---- palette ----
  let pi = 0, pt;
  function openPalette() { mark(); closeAll(); scrim(); const q = $('#pq'); q.value = ''; show($('#palette')); search(''); }
  function search(q) { fetch('/_pogi/search?q=' + encodeURIComponent(q)).then(r => r.text()).then(h => { $('#pres').innerHTML = h; pi = 0; hl(); }); }
  const items = () => [...document.querySelectorAll('#pres .it')];
  function hl() {
    document.querySelectorAll('#pres .grp').forEach(g => g.setAttribute('role', 'presentation'));
    items().forEach((e, i) => { e.id = 'po' + i; e.tabIndex = -1; e.setAttribute('role', 'option'); e.setAttribute('aria-selected', i === pi); e.classList.toggle('on', i === pi); });
    const e = items()[pi], q = $('#pq'); if (q) q.setAttribute('aria-activedescendant', e ? e.id : '');
    if (e) e.scrollIntoView({ block: 'nearest' });
  }
  function run(it) {
    dismiss();
    if (it.dataset.js) return js(it.dataset.js, it);
    if (it.hasAttribute('data-post')) return fetch(it.getAttribute('href'), { method: 'POST' }).then(r => { toast(r.ok ? 'Done' : 'Failed', r.ok ? '' : 'bad'); if (r.ok) location.reload(); });
    if (it.hasAttribute('data-drawer')) return openDrawer(it.getAttribute('href'));
    location.assign(it.getAttribute('href'));
  }
  // Fill the scope popover's lists with every value pogi holds (name, with how many resources use it).
  function scopeValues() {
    fetch('/_pogi/scope/values').then(r => r.ok ? r.json() : {}).then(v => {
      for (const k in v) {
        const dl = $('#dl-' + k);
        if (dl) dl.replaceChildren(...v[k].map(o => { const e = document.createElement('option'); e.value = o.Value; e.label = o.Label; e.textContent = o.Label; return e; }));
      }
    }).catch(() => {});
  }
  function js(name, el) {
    switch (name) {
      case 'palette': return openPalette();
      case 'theme': return toggleTheme();
      case 'side': return toggleSide();
      case 'keys': { const k = $('#keys'), on = k.classList.contains('on'); mark(); on ? dismiss() : (closeAll(), scrim(), show(k)); return; }
      case 'scope': { const p = $('#pop'), on = p.classList.contains('on'); mark(); if (on) return dismiss(); closeAll(); anchor($('#scopeBtn'), p, 340); show(p); scopeValues(); return; }
      case 'bell': {
        const p = $('#bell'), on = p.classList.contains('on'); mark(); if (on) return dismiss(); closeAll();
        anchor($('#bellBtn'), p, 390); show(p);
        fetch('/_pogi/notes').then(r => r.ok ? r.text() : '<div class="empty" style="padding:30px">No notifications.</div>').then(h => { p.innerHTML = h; htmx.process(p); if (p.classList.contains('on')) focusIn(p); });
        return;
      }
      case 'copy-endpoint': return copy(location.origin);
    }
  }
  function copy(text) { navigator.clipboard.writeText(text).then(() => toast('Copied'), () => toast('Copy failed', 'bad')); }

  // ---- pins ----
  function pin(name) {
    const pins = getCookie('pogi-pins').split(',').filter(Boolean), on = pins.includes(name);
    setCookie('pogi-pins', (on ? pins.filter(p => p !== name) : [...pins, name]).join(','));
    try { sessionStorage.setItem('pogi-refocus', name); } catch {}
    location.reload();
  }
  // after a pin's reload, give keyboard users their place back and say what changed
  try {
    const n = sessionStorage.getItem('pogi-refocus');
    if (n) {
      sessionStorage.removeItem('pogi-refocus');
      const el = document.querySelector('[data-pin="' + CSS.escape(n) + '"]');
      if (el) { el.focus(); toast((el.getAttribute('aria-pressed') === 'true' ? 'Pinned ' : 'Unpinned ') + (el.getAttribute('aria-label') || n).replace(/^(Unpin|Pin) /, '')); }
    }
  } catch {}

  // ---- events ----
  document.addEventListener('click', e => {
    const t = e.target;
    // a chosen menu item closes the menu (items that open the drawer have already done so)
    if (t.closest('#menu [role=menuitem]')) setTimeout(() => { if (isOn('menu')) dismiss(); });
    const close = t.closest('[data-close]'); if (close) { e.preventDefault(); return dismiss(); }
    if (t.closest('#scrim')) return dismiss();
    const it = t.closest('#pres .it'); if (it) { e.preventDefault(); return run(it); }
    const j = t.closest('[data-js]'); if (j) { e.preventDefault(); e.stopPropagation(); return js(j.dataset.js, j); }
    const c = t.closest('[data-copy]'); if (c) { e.preventDefault(); const v = c.dataset.copy; return copy(v.startsWith('#') ? ($(v) || {}).textContent || '' : v); }
    const p = t.closest('[data-pin]'); if (p) { e.preventDefault(); return pin(p.dataset.pin); }
    const m = t.closest('[data-menu]');
    if (m) {
      e.preventDefault(); e.stopPropagation();
      const menu = $('#menu'), on = menu.classList.contains('on') && menu.dataset.for === m.dataset.menu; mark();
      if (on) return dismiss();
      closeAll(); menu.innerHTML = (m.nextElementSibling || {}).innerHTML || ''; menu.dataset.for = m.dataset.menu;
      menu.querySelectorAll('a, button').forEach(x => { x.setAttribute('role', 'menuitem'); x.tabIndex = -1; });
      menu.querySelectorAll('hr').forEach(x => x.setAttribute('role', 'separator'));
      htmx.process(menu); anchor(m, menu, 210); show(menu); fit(m, menu); const f = menu.querySelector('[role=menuitem]'); if (f) f.focus(); return;
    }
    // [data-drawer] opens its href (or its own value) in the drawer, unless the click was on a control inside it
    const d = t.closest('[data-drawer]');
    if (d && !(t.closest('input, button, select, label, a') && t.closest('input, button, select, label, a') !== d)) {
      e.preventDefault(); return openDrawer(d.dataset.drawer || d.getAttribute('href'));
    }
    if (!t.closest('#pop, #bell, #menu')) ['pop', 'bell', 'menu'].forEach(id => { const el = document.getElementById(id); if (el) el.classList.remove('on'); });
  });
  document.addEventListener('input', e => { if (e.target.id === 'pq') { clearTimeout(pt); pt = setTimeout(() => search(e.target.value), 120); } });
  document.addEventListener('htmx:afterSwap', e => {
    if (e.detail.target.id !== 'drawer') return;
    const d = $('#drawer'); if (!d.innerHTML.trim()) return;
    if (!marked) mark(); marked = false;
    scrim(); d.classList.add('on'); sync(); a11y(d); linkErrors(d);
    // a form drawer starts in its first field, so typing right after `c` or a click fills it in
    const f = $('[autofocus]', d) || $('.dbody :is(input:not([type=hidden]):not([type=checkbox]), select, textarea)', d); if (f) f.focus(); else focusIn(d);
  });
  document.addEventListener('htmx:afterSettle', themeIcon);
  document.addEventListener('pogi-toast', e => toast(e.detail.msg, e.detail.kind, e.detail.href));
  // a finished form swaps the page in afterwards (HX-Location), which replaces #toast: show it once that settles
  let doneMsg = '';
  document.addEventListener('pogi-done', e => { dismiss(); doneMsg = e.detail.msg || 'Done'; setTimeout(() => { if (doneMsg) { toast(doneMsg); doneMsg = ''; } }, 1500); });
  document.addEventListener('htmx:afterSettle', () => { if (doneMsg) { toast(doneMsg); doneMsg = ''; } });
  document.addEventListener('DOMContentLoaded', themeIcon);

  // keyboard: Tab stays inside an open modal, arrows drive menus and tablists, Enter/Space press role=button and role=link elements
  document.addEventListener('keydown', e => {
    const t = e.target, k = e.key;
    if (k === 'Tab') {
      const m = ['keys', 'drawer', 'palette'].map(id => document.getElementById(id)).find(x => x && x.classList.contains('on'));
      if (!m) { if (isOn('menu')) dismiss(); return; }
      const f = focusables(m), i = f.indexOf(document.activeElement);
      if (f.length && (i < 0 || (e.shiftKey ? i === 0 : i === f.length - 1))) { f[e.shiftKey && i >= 0 ? f.length - 1 : 0].focus(); e.preventDefault(); }
      return;
    }
    const menu = t.closest && t.closest('#menu');
    if (menu && ['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(k)) {
      const it = [...menu.querySelectorAll('[role=menuitem]')], n = it.length, i = it.indexOf(t);
      if (n) it[k === 'Home' ? 0 : k === 'End' ? n - 1 : (i + (k === 'ArrowDown' ? 1 : -1) + n) % n].focus();
      return e.preventDefault();
    }
    if ((k === 'ArrowRight' || k === 'ArrowLeft') && t.getAttribute && t.getAttribute('role') === 'tab') {
      const tabs = [...t.closest('[role=tablist]').querySelectorAll('[role=tab]')], n = tabs[(tabs.indexOf(t) + (k === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length];
      n.focus(); if (n.dataset.tab !== undefined) n.click();
      return e.preventDefault();
    }
    if ((k === 'Enter' || k === ' ') && t.matches && t.matches('[role=button]:not(button):not([href]), [role=link]:not([href])')) { e.preventDefault(); t.click(); }
  });

  let gAt = 0;
  const goto = { h: '/_pogi/', a: '/_pogi/requests', f: '/_pogi/flows', s: '/_pogi/services', m: '/_pogi/map', i: '/_pogi/iam', c: '/_pogi/cost', x: '/_pogi/chaos' };
  document.addEventListener('keydown', e => {
    const mod = e.metaKey || e.ctrlKey;
    if (mod && e.key === 'k') { e.preventDefault(); return $('#palette').classList.contains('on') ? dismiss() : openPalette(); }
    if (mod && e.key === 'b') { e.preventDefault(); return toggleSide(); }
    if ($('#palette').classList.contains('on') && e.target.id === 'pq') {
      if (e.key === 'ArrowDown') { pi = Math.min(pi + 1, items().length - 1); hl(); e.preventDefault(); }
      else if (e.key === 'ArrowUp') { pi = Math.max(pi - 1, 0); hl(); e.preventDefault(); }
      else if (e.key === 'Enter') { const it = items()[pi]; if (it) run(it); e.preventDefault(); }
      else if (e.key === 'Escape') { e.preventDefault(); dismiss(); }
      return;
    }
    if (e.key === 'Escape') return document.querySelector('dialog[open]') ? undefined : dismiss(); // an open dialog (the confirm) closes alone: one Esc, one layer
    if (mod || e.altKey || typing()) return;
    if (Date.now() - gAt < 1200) { gAt = 0; if (goto[e.key]) { location.assign(goto[e.key]); return; } }
    switch (e.key) {
      case 'g': gAt = Date.now(); return;
      case '/': e.preventDefault(); return openPalette();
      case '?': return js('keys');
      case 't': return toggleTheme();
      case 'n': return js('bell');
      case 'c': { const c = $('main [data-create]'); if (c) { e.preventDefault(); c.click(); } return; }
      case 'f': { const f = $('main .filter input, main input[type=search]'); if (f) { e.preventDefault(); f.focus(); } return; }
    }
  });

  // ---- builder A: tabs and the notification bell ----
  // [data-tab] links switch the [data-pane] blocks of their drawer, [data-tabs] container or page; the .on tab shows first.
  function showTab(t) {
    const root = t.closest('[data-tabs], .drawer, main');
    root.querySelectorAll('[data-tab]').forEach(x => { x.classList.toggle('on', x === t); x.setAttribute('aria-selected', x === t); });
    root.querySelectorAll('[data-pane]').forEach(p => { p.hidden = p.dataset.pane !== t.dataset.tab; });
  }
  const initTabs = () => document.querySelectorAll('[data-tab].on').forEach(showTab);
  document.addEventListener('click', e => { const t = e.target.closest('[data-tab]'); if (t) { e.preventDefault(); showTab(t); } });
  document.addEventListener('DOMContentLoaded', initTabs);
  document.addEventListener('htmx:afterSettle', initTabs);

  // the bell badge and toasts: poll for failed calls, IAM denials and chaos faults (one toast per 8 s; several new ones make one summary)
  let noteSince = Date.now(), noteToast = 0;
  function pollNotes() {
    if (document.hidden) return;
    fetch('/_pogi/notes/poll?since=' + noteSince).then(r => r.ok ? r.json() : null).then(j => {
      if (!j) return;
      noteSince = j.now;
      newMail(j.mail);
      const b = $('#bellN'); if (b) b.textContent = j.unread > 99 ? '99+' : j.unread || '';
      if (j.new.length && Date.now() - noteToast > 8000) { noteToast = Date.now(); toast(j.new[0].msg, j.new[0].kind, j.new[0].href); }
    }).catch(() => {});
  }
  setInterval(pollNotes, 4000); pollNotes();

  // ---- live inbox: the poll carries the newest captured mail; a new one toasts, and refreshes the Inbox page in place ----
  let mailSeen;
  const loadedAt = Date.now();
  function newMail(m) {
    const id = m ? m.id : '';
    // the first poll only seeds, so mail from before this page loaded doesn't toast; mail that came after it
    // does, even if that first poll ran late (polls pause while the tab is hidden)
    if (mailSeen === undefined && !(m && m.at > loadedAt)) { mailSeen = id; return; }
    if (id === mailSeen) return;
    mailSeen = id;
    if (!id) return; // the inbox was cleared
    toast('New email to ' + (m.to || 'someone') + ' · ', '', '/_pogi/inbox', 'Open');
    if (!location.pathname.startsWith('/_pogi/inbox')) return;
    const list = $('.mail .list'), sel = list ? '.mail .list' : '#main';
    htmx.ajax('GET', location.pathname, { target: sel, select: sel, swap: 'outerHTML' }).then(() => { const a = $('.mail .list a'); if (a) a.classList.add('new'); });
  }

  // live tables pause while someone is working in them (focus inside, or a drawer open on top), so a refresh never swaps out the focused link
  const busy = sel => !!document.querySelector(sel + ':focus-within, #drawer.on');
  // data-poll="ms": send a pogi-poll event to the element every so often, for its hx-trigger (htmx's own
  // "every 2s [condition]" filters need eval, which the CSP forbids). It waits while the tab is hidden;
  // data-poll-live also waits for the Live switch and for typing in the element; data-poll-drawer waits for an open drawer.
  const polled = new WeakMap();
  setInterval(() => {
    if (document.hidden) return;
    const now = Date.now(), live = document.getElementById('live'), drawer = document.getElementById('drawer');
    document.querySelectorAll('[data-poll]').forEach(el => {
      if (!polled.has(el)) polled.set(el, now);
      if (now - polled.get(el) < +el.dataset.poll) return;
      if ('pollLive' in el.dataset && !(live && live.checked && !busy('#' + el.id))) return;
      if ('pollDrawer' in el.dataset && !(drawer && drawer.classList.contains('on'))) return;
      polled.set(el, now);
      htmx.trigger(el, 'pogi-poll');
    });
  }, 500);
  window.pogi = { toast, openDrawer, closeAll, copy, pin, busy };
})();

// ---------- builder D: chaos drawer, run shortcut, mail panes ----------
(() => {
  const field = k => document.querySelector('[data-cli] [data-k="' + k + '"]');
  const val = k => { const e = field(k); return e ? e.value.trim() : ''; };
  // the add-rule form's CLI band follows its fields
  function mirror() {
    const out = document.getElementById('cli'); if (!out || !field('p')) return;
    const p = val('p'), pv = document.getElementById('pv'); if (pv) pv.textContent = p + '%';
    out.textContent = 'pogi chaos add' + (val('svc') ? ' --service ' + val('svc') : '') + (val('op') ? " --op '" + val('op') + "'" : '') + ' --rate ' + (p / 100).toFixed(2) +
      (val('st') ? ' --status ' + val('st') : '') + (val('code') ? ' --code ' + val('code') : '') + (+val('lat') ? ' --latency ' + val('lat') + 'ms' : '');
  }
  document.addEventListener('input', e => { if (e.target.closest('[data-cli]')) mirror(); });
  document.addEventListener('change', e => { if (e.target.closest('[data-cli]')) mirror(); });
  document.addEventListener('click', e => {
    const b = e.target.closest('[data-preset]'); if (!b) return;
    b.parentNode.querySelectorAll('button').forEach(x => x.classList.toggle('on', x === b));
    ["st", "code", "p", "lat"].forEach((k, i) => { const f = field(k); if (f) f.value = b.dataset.preset.split(',')[i]; });
    mirror();
  });
  // ⌘↵ or Ctrl↵ runs the query of a tool page (the Run button says so in its tooltip)
  document.addEventListener('keydown', e => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') { const f = e.target.closest && e.target.closest('form[data-run]'); if (f) { e.preventDefault(); f.requestSubmit(); } }
  });
})();

// ---- builder B: bulk selection on service pages ----
(() => {
  // hx-boost would follow an <a data-drawer> before the shell's handler runs: open it in the drawer first
  document.addEventListener('click', e => {
    const a = e.target.closest && e.target.closest('a[data-drawer]');
    if (!a || e.defaultPrevented || e.button || e.metaKey || e.ctrlKey || e.shiftKey || a.closest('#drawer')) return;
    e.preventDefault(); e.stopPropagation();
    window.pogi.openDrawer(a.dataset.drawer || a.getAttribute('href'));
  }, true);
  const sync = () => {
    const rows = [...document.querySelectorAll('.dt tbody input[name=row]')], n = rows.filter(c => c.checked).length;
    rows.forEach(c => c.closest('tr').classList.toggle('sel', c.checked));
    const b = document.getElementById('bulk'), t = document.getElementById('bulkN');
    if (b) { t.textContent = n + ' selected'; b.classList.toggle('on', n > 0); }
  };
  document.addEventListener('change', e => {
    const c = e.target;
    if (!c.matches || !c.matches('.dt input[type=checkbox]')) return;
    if (c.closest('thead')) c.closest('table').querySelectorAll('tbody input[name=row]').forEach(x => { x.checked = c.checked; });
    sync();
  });
  document.addEventListener('click', e => {
    if (!e.target.closest('[data-bulk-clear]')) return;
    document.querySelectorAll('.dt input[type=checkbox]').forEach(x => { x.checked = false; });
    sync();
  });
})();

// Uploads: the server's limits come in meta tags (plain uploads, and function code, which is a zip).
// A file over the limit is refused here, before it is sent, with the same caution the server gives.
(() => {
  const meta = n => +(document.querySelector('meta[name=' + n + ']') || {}).content || 0;
  const sel = 'input[type=file][data-upload], input[type=file][data-code]';
  const limitOf = i => ('code' in i.dataset) ? meta('pogi-code-mb') : meta('pogi-upload-mb');
  const hint = i => 'Up to ' + limitOf(i) + ' MB' + (('code' in i.dataset) ? ' zipped' : '') + ': pogi is a local test emulator.';
  const noteFor = i => (i.closest('label') || i).nextElementSibling;
  const notes = () => {
    document.querySelectorAll(sel).forEach(i => {
      if (i.dataset.noted) return;
      const n = document.createElement('small');
      i.dataset.noted = '1';
      n.className = 'upload-note';
      n.setAttribute('role', 'status');
      n.textContent = hint(i);
      (i.closest('label') || i).after(n);
    });
  };
  document.addEventListener('DOMContentLoaded', notes);
  document.addEventListener('htmx:afterSettle', notes);
  // capture phase: this runs before the autosubmit handler sends the form
  document.addEventListener('change', e => {
    const i = e.target;
    if (!i.matches || !i.matches(sel)) return;
    const mb = limitOf(i), code = 'code' in i.dataset;
    if (!mb) return;
    const size = [...i.files].reduce((a, f) => a + f.size, 0), n = noteFor(i);
    if (size <= mb * 1048576) { if (n) { n.classList.remove('bad'); n.textContent = hint(i); } return; }
    e.stopPropagation();
    i.value = '';
    if (n) {
      const z = code ? ' zipped' : '', big = Math.ceil(size / 1048576);
      n.classList.add('bad');
      n.textContent = 'pogi is a local emulator for tests, so ' + (code ? 'Lambda code is' : 'uploads are') + ' limited to ' + mb + ' MB' + z +
        ' (this one is ' + big + ' MB' + z + '). Raise the limit with --max-upload-mb or server.maxUploadMB in pogi.yaml.';
    }
  }, true);
})();

// ---------- builder tf-web: the Terraform page (/_pogi/terraform) and the Cost page's Terraform tab ----------
// The browser posts the picked files once. pogi holds that stack, so every change after it (var file,
// size pick, module expanded, grouping) posts only the view state, which the server sends back with each
// fragment (data-state). The diagram is drawn by the server: this code only pans, zooms and highlights it.
(() => {
  const $ = (s, el = document) => el.querySelector(s);
  const root = () => document.getElementById('tf');
  const toast = (m, k) => window.pogi.toast(m, k);
  const tf = { el: null, st: null, files: new Map(), sel: '', k: 1, x: 0, y: 0, own: false, ctl: null };
  const view = () => root().dataset.view; // "diagram" on the Terraform page, "table" on the Cost page
  // the view state the server rendered: vars, sizes, expanded, group, layout
  function adopt() {
    const s = $('#tf-result [data-state]');
    try { tf.st = s ? JSON.parse(s.dataset.state) : null; } catch { tf.st = null; }
    if (tf.st) tf.st.sizes = tf.st.sizes || {};
  }
  // a new page (the console swaps pages without reloading) starts from what the server rendered
  const fresh = () => { const r = root(); if (r && tf.el !== r) { Object.assign(tf, { el: r, files: new Map(), sel: '', own: false }); adopt(); } return !!r; };
  const lim = () => ({ files: +root().dataset.maxFiles, bytes: +root().dataset.maxBytes });

  // ---- which files to send ----
  const KEEP = /\.(tf|tf\.json|tfvars|tfvars\.json)$/i;
  const isPlanName = n => /\.json$/i.test(n) && !/\.(tf|tfvars)\.json$/i.test(n);
  function keep(p) {
    const parts = p.split('/');
    if (parts.includes('node_modules')) return false;
    if (parts[0] === '.terraform') return parts[1] === 'modules' && (p === '.terraform/modules/modules.json' || /\.tf$/i.test(p));
    return !parts.some(s => s.startsWith('.')) && KEEP.test(p);
  }
  function dirOk(rel) { // rel ends with "/"
    const parts = rel.split('/').filter(Boolean);
    if (parts.includes('node_modules')) return false;
    if (parts[0] === '.terraform') return parts.length === 1 || parts[1] === 'modules';
    return !parts.some(s => s.startsWith('.'));
  }
  const fromInput = list => { // a picked folder: strip the folder's own name
    const out = new Map();
    for (const f of list) { const rel = (f.webkitRelativePath || f.name).split('/').slice(1).join('/'); if (rel && keep(rel)) out.set(rel, f); }
    return out;
  };
  const readAll = r => new Promise((ok, no) => r.readEntries(ok, no));
  async function walk(dir, prefix, out, max) {
    const rd = dir.createReader();
    for (;;) {
      const batch = await readAll(rd);
      if (!batch.length || out.size > max) return;
      for (const e of batch) {
        if (e.isFile) { const rel = prefix + e.name; if (keep(rel)) out.set(rel, await new Promise((ok, no) => e.file(ok, no))); }
        else if (dirOk(prefix + e.name + '/')) await walk(e, prefix + e.name + '/', out, max);
        if (out.size > max) return;
      }
    }
  }
  async function fromDrop(dt) {
    const es = [...dt.items].map(i => i.webkitGetAsEntry && i.webkitGetAsEntry()).filter(Boolean); // read now: entries die after the event
    const out = new Map();
    if (es.length === 1 && es[0].isFile && isPlanName(es[0].name)) { out.set(es[0].name, await new Promise((ok, no) => es[0].file(ok, no))); return out; }
    for (const e of es) {
      if (e.isDirectory) await walk(e, '', out, lim().files);
      else if (keep(e.name)) out.set(e.name, await new Promise((ok, no) => e.file(ok, no)));
    }
    return out;
  }

  // ---- sending ----
  const mb = n => (n / 1048576).toFixed(n < 1048576 ? 2 : 1);
  function fail(html, text) {
    const e = $('#tf-err'); if (!e) return;
    if (text) { const d = document.createElement('div'); d.className = 'flash'; d.setAttribute('role', 'alert'); d.textContent = text; e.replaceChildren(d); } else e.innerHTML = html;
    $('#tf-load').hidden = true;
  }
  async function load(map) {
    if (!fresh()) return;
    const l = lim();
    let bytes = 0; map.forEach(f => { bytes += f.size; });
    if (!map.size) return fail('', 'No Terraform files were found there. pogi looks for *.tf, *.tfvars and .terraform/modules. Pick the folder that holds your Terraform files, or a plan.json.');
    if (map.size > l.files) return fail('', `That folder has more than ${l.files} Terraform files, and pogi reads at most ${l.files}. Pick the folder that holds the Terraform files, not a parent folder.`);
    if (bytes > l.bytes) return fail('', `Those files are ${mb(bytes)} MB, and pogi reads at most ${mb(l.bytes)} MB.`);
    Object.assign(tf, { files: map, sel: '', own: false });
    send(post('', map));
  }
  // post sends files (a new stack: its vars, sizes and expanded start empty), or without files the view
  // state st, or only a format (an export of the held stack)
  function post(format, files, st) {
    const fd = new FormData(), s = st || tf.st;
    if (files) for (const [p, f] of files) fd.append(p, f, p);
    if (s && !files) {
      fd.append('state', '1');
      s.vars.forEach(v => fd.append('vars', v));
      s.expanded.forEach(m => fd.append('expanded', m));
      fd.append('sizes', JSON.stringify(s.sizes));
    }
    if (s) { fd.append('group', s.group); fd.append('layout', s.layout); }
    fd.append('view', view());
    if (format) fd.append('format', format);
    const ctl = new AbortController(), timer = setTimeout(() => ctl.abort(), 120000);
    return fetch('/_pogi/terraform', { method: 'POST', body: fd, signal: ctl.signal }).finally(() => clearTimeout(timer));
  }
  // change posts the held view state with one change
  const change = fn => { if (!tf.st) return; const st = structuredClone(tf.st); fn(st); return send(post('', null, st)); };
  async function send(req) {
    const busy = $('#tf-load'); busy.hidden = false; $('#tf-err').replaceChildren();
    const mine = tf.ctl = {};
    try {
      const r = await req, html = await r.text();
      if (tf.ctl !== mine) return;
      busy.hidden = true;
      if (!r.ok) return fail(html);
      const prev = tf.sel;
      $('#tf-empty').hidden = true; $('#tf-result').innerHTML = html; adopt();
      const t = $('#tf-result .bigcost, #tf-result .tftotal strong'); $('#tf-live').textContent = t ? 'Monthly cost: ' + t.textContent : '';
      tf.sel = ''; show(); if (prev) select(prev); // pan, zoom and the selected box stay
    } catch (err) {
      if (tf.ctl === mine) fail('', err.name === 'AbortError' ? 'That took too long, so pogi stopped. Try a smaller folder.' : 'Could not reach pogi: ' + err.message);
    }
  }
  const save = (blob, name) => { const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = name; document.body.append(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(a.href), 4000); };
  async function exportAs(kind) {
    try {
      const r = await post(kind === 'png' ? 'svg' : kind);
      if (!r.ok) return toast('Export failed', 'bad');
      if (kind !== 'png') return save(await r.blob(), 'pogi-terraform-' + (kind === 'markdown' ? 'cost.md' : kind === 'svg' ? 'diagram.svg' : 'cost.json'));
      const svg = await r.text(), m = svg.match(/viewBox="0 0 (\d+) (\d+)"/), w = +m[1], h = +m[2], s = Math.min(2, 8000 / Math.max(w, h));
      const img = new Image();
      img.onload = () => {
        const c = document.createElement('canvas'); c.width = Math.round(w * s); c.height = Math.round(h * s);
        const g = c.getContext('2d'); g.fillStyle = '#fff'; g.fillRect(0, 0, c.width, c.height); g.drawImage(img, 0, 0, c.width, c.height);
        c.toBlob(b => b ? save(b, 'pogi-terraform-diagram.png') : toast('Could not draw the PNG', 'bad'));
      };
      img.onerror = () => toast('Could not draw the PNG', 'bad');
      img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
    } catch (err) { toast('Export failed: ' + err.message, 'bad'); }
  }
  async function sample() {
    try {
      const r = await fetch('/_pogi/terraform/sample'); if (!r.ok) throw new Error('HTTP ' + r.status);
      const j = await r.json(); load(new Map(Object.entries(j).map(([p, t]) => [p, new File([t], p)])));
    } catch (err) { fail('', 'Could not load the sample: ' + err.message); }
  }

  // ---- the diagram: pan, zoom, highlight ----
  const vw = () => document.getElementById('tfview'), svg = () => $('#tfpan svg');
  // every pan and zoom is the user's own view, which pogi then keeps; only fit() sets own = false
  const apply = (own = true) => { tf.own = own; const p = document.getElementById('tfpan'); if (p) p.style.transform = `translate(${tf.x}px,${tf.y}px) scale(${tf.k})`; };
  const READ = .6; // below this scale the 11-12px box names shrink under 7px and can't be read
  function fit(first) {
    const v = vw(), s = svg(); if (!v || !s || !v.clientWidth) return; // hidden: the Diagram tab calls show() again
    const W = s.viewBox.baseVal.width, H = s.viewBox.baseVal.height, k = Math.min(1, (v.clientWidth - 24) / W, (v.clientHeight - 24) / H);
    if (first && k < READ) { tf.k = READ; tf.x = Math.max(12, (v.clientWidth - W * READ) / 2); tf.y = 12; } // too big to read when fitted: start readable, at the top
    else { tf.k = Math.max(.1, k); tf.x = (v.clientWidth - W * tf.k) / 2; tf.y = Math.max(12, (v.clientHeight - H * tf.k) / 2); }
    apply(false);
  }
  // Show the diagram: fitted until the user pans or zooms it, then where they left it. This runs
  // right away, not in requestAnimationFrame, which a page in a background tab may never call.
  const show = () => tf.own ? apply() : fit(true);
  function zoomAt(f, cx, cy) {
    const k = Math.min(3, Math.max(.1, tf.k * f)), r = k / tf.k;
    tf.x = cx - (cx - tf.x) * r; tf.y = cy - (cy - tf.y) * r; tf.k = k; apply();
  }
  const zoomMid = f => { const v = vw(); if (v) zoomAt(f, v.clientWidth / 2, v.clientHeight / 2); };
  document.addEventListener('wheel', e => {
    const v = e.target.closest && e.target.closest('#tfview'); if (!v) return;
    e.preventDefault();
    const b = v.getBoundingClientRect(); zoomAt(Math.exp(-Math.max(-100, Math.min(100, e.deltaY)) * .0015), e.clientX - b.left, e.clientY - b.top);
  }, { passive: false });
  let drag = null, moved = false;
  document.addEventListener('pointerdown', e => {
    const v = e.target.closest && e.target.closest('#tfview'); if (!v || e.button) return;
    drag = { id: e.pointerId, x: e.clientX, y: e.clientY, ox: tf.x, oy: tf.y, v }; moved = false;
  });
  document.addEventListener('pointermove', e => {
    if (!drag || e.pointerId !== drag.id) return;
    const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
    if (!moved && Math.hypot(dx, dy) < 5) return;
    if (!moved) { moved = true; drag.v.classList.add('drag'); try { drag.v.setPointerCapture(e.pointerId); } catch {} }
    tf.x = drag.ox + dx; tf.y = drag.oy + dy; apply();
  });
  const endDrag = () => { if (drag) drag.v.classList.remove('drag'); drag = null; setTimeout(() => { moved = false; }); };
  document.addEventListener('pointerup', endDrag); document.addEventListener('pointercancel', endDrag);
  document.addEventListener('focusin', e => { // a box focused with Tab is brought into view
    const n = e.target.closest && e.target.closest('#tfview .tfn, #tfview .tff'), v = vw(); if (!n) return;
    v.scrollLeft = v.scrollTop = 0;
    const r = n.getBoundingClientRect(), b = v.getBoundingClientRect();
    if (r.left < b.left || r.right > b.right || r.top < b.top || r.bottom > b.bottom) {
      tf.x += b.left + b.width / 2 - (r.left + r.width / 2); tf.y += b.top + b.height / 2 - (r.top + r.height / 2); apply();
    }
  });
  function clearSel() {
    const s = svg(); tf.sel = '';
    if (s) { s.classList.remove('has-sel'); s.querySelectorAll('.sel, .dep, .hot').forEach(x => x.classList.remove('sel', 'dep', 'hot')); }
    const bar = document.getElementById('tfsel'); if (bar) bar.replaceChildren();
    const side = document.getElementById('tfside'); if (side) { side.hidden = true; side.replaceChildren(); }
  }
  // select a box: it and everything that depends on it, directly or not, stays lit
  function select(id) {
    clearSel(); const s = svg(); if (!id || !s) return;
    if (id.startsWith('flow:')) return selectFlow(id, s);
    const nodes = [...s.querySelectorAll('.tfn')], by = new Map(nodes.map(n => [n.dataset.id, n])), users = new Map();
    if (!by.has(id)) return;
    nodes.forEach(n => (n.dataset.deps || '').split(' ').filter(Boolean).forEach(d => { if (!users.has(d)) users.set(d, []); users.get(d).push(n.dataset.id); }));
    const seen = new Set(), q = [id];
    while (q.length) for (const u of users.get(q.shift()) || []) if (!seen.has(u)) { seen.add(u); q.push(u); }
    tf.sel = id; s.classList.add('has-sel'); by.get(id).classList.add('sel');
    let count = 0; seen.forEach(u => { by.get(u).classList.add('dep'); count += +by.get(u).dataset.n; });
    s.querySelectorAll('.edge').forEach(e => { if ((e.dataset.f === id || seen.has(e.dataset.f)) && seen.has(e.dataset.t)) e.classList.add('hot'); });
    const bar = document.getElementById('tfsel'), name = document.createElement('b'), btn = (t, a) => { const b = document.createElement('button'); b.type = 'button'; b.className = 'btn sm'; b.dataset.tf = a; b.textContent = t; return b; };
    name.textContent = by.get(id).dataset.name;
    bar.replaceChildren(name, document.createTextNode(count ? `— ${count} ${count === 1 ? 'resource depends' : 'resources depend'} on this` : '— nothing depends on this'), btn('Clear', 'clear'));
    const n = by.get(id); openRows(n.dataset.rows.split(' '), n.dataset.name, $('.ty', n).textContent);
  }

  // select a data-flow line: it and the two boxes it joins stay lit, and its resource shows in the side panel
  function selectFlow(id, s) {
    const l = [...s.querySelectorAll('.tff')].find(x => x.dataset.id === id); if (!l) return;
    tf.sel = id; s.classList.add('has-sel'); l.classList.add('sel');
    s.querySelectorAll('.tfn').forEach(n => { if (n.dataset.id === l.dataset.f || n.dataset.id === l.dataset.t) n.classList.add('dep'); });
    const bar = document.getElementById('tfsel'), name = document.createElement('b'), b = document.createElement('button');
    b.type = 'button'; b.className = 'btn sm'; b.dataset.tf = 'clear'; b.textContent = 'Clear'; name.textContent = l.dataset.name;
    const end = i => { const n = [...s.querySelectorAll('.tfn')].find(x => x.dataset.id === i); return n ? n.dataset.name : i; };
    bar.replaceChildren(name, document.createTextNode(`— data flows from ${end(l.dataset.f)} to ${end(l.dataset.t)}`), b);
    openRows(l.dataset.rows.split(' ').filter(Boolean), l.dataset.name, 'Data flow');
  }
  // live traffic on the data-flow lines: ask pogi every few seconds, and move only the dots. The
  // diagram is not drawn again, so pan, zoom and the selection stay.
  let liveBusy = false;
  async function pollLive() {
    const s = svg(); if (document.hidden || liveBusy || !s || !s.querySelector('.flow')) return;
    liveBusy = true;
    try {
      const r = await fetch('/_pogi/terraform/live', { cache: 'no-store' }); if (!r.ok) return;
      const j = await r.json(), ns = 'http://www.w3.org/2000/svg';
      s.querySelectorAll('.flow').forEach(p => {
        const id = p.dataset.line, want = j[id] || '', cur = s.querySelector(`circle.pulse[data-line="${id}"]`);
        if ((cur ? (cur.classList.contains('bad') ? 'bad' : 'live') : '') === want) return;
        if (cur) cur.remove();
        if (!want) return;
        const c = document.createElementNS(ns, 'circle'), a = document.createElementNS(ns, 'animateMotion');
        c.setAttribute('class', 'pulse' + (want === 'bad' ? ' bad' : '')); c.setAttribute('data-line', id); c.setAttribute('r', '3.5');
        a.setAttribute('dur', (want === 'bad' ? 3.4 : 1.6 + (id % 4) * .35).toFixed(2) + 's'); a.setAttribute('repeatCount', 'indefinite'); a.setAttribute('path', p.getAttribute('d'));
        c.append(a); p.parentNode.append(c);
      });
    } catch { /* offline: keep the dots as they are */ } finally { liveBusy = false; }
  }
  setInterval(pollLive, 3000);

  // ---- the drawer: filled from the <template>s the server sent, so no second request ----
  function openRows(ids, title, eyebrow) {
    const side = document.getElementById('tfside');
    if (side) { // the Terraform page: the details sit beside the canvas
      const h = document.createElement('div'), b = document.createElement('b'), x = document.createElement('button');
      h.className = 'sidehead'; b.textContent = eyebrow + ' · ' + title; x.type = 'button'; x.className = 'btn sm'; x.dataset.tf = 'clear'; x.textContent = 'Close';
      h.append(b, x); side.replaceChildren(h);
      ids.forEach(i => { const t = document.getElementById('tfr-' + i); if (t) side.append(t.content.cloneNode(true)); });
      side.hidden = false; return;
    }
    const d = document.getElementById('drawer'), head = $('#tfr-head'); if (!d || !head) return;
    d.replaceChildren(head.content.cloneNode(true));
    $('.eyebrow', d).textContent = eyebrow; $('#dtitle', d).textContent = title;
    ids.forEach(i => { const t = document.getElementById('tfr-' + i); if (t) $('.dbody', d).append(t.content.cloneNode(true)); });
    document.dispatchEvent(new CustomEvent('htmx:afterSwap', { detail: { target: d } })); // the shell shows the drawer
  }
  function sizeFilter() {
    const d = document.getElementById('drawer'), v = k => $('[data-tf-f=' + k + ']', d); if (!v('c')) return;
    const c = +v('c').value || 0, m = +v('m').value || 0, q = v('q').value.toLowerCase().trim(), old = v('old').checked, rows = d.querySelectorAll('.tfsizes tbody tr');
    let n = 0;
    rows.forEach(r => { const ok = +r.dataset.c >= c && +r.dataset.m >= m && (!q || r.dataset.n.toLowerCase().includes(q)) && (old || r.dataset.old !== 'true' || r.classList.contains('sel')); r.hidden = !ok; if (ok) n++; });
    $('#tf-fcount', d).textContent = `${n} of ${rows.length} sizes`;
  }
  ['input', 'change'].forEach(ev => document.addEventListener(ev, e => { if (e.target.closest && e.target.closest('[data-tf-sizes]')) sizeFilter(); }));
  document.addEventListener('htmx:afterSwap', e => { if (e.detail.target.id === 'drawer') sizeFilter(); });

  // ---- events ----
  document.addEventListener('click', e => {
    const t = e.target; if (!t.closest) return;
    const pick = t.closest('[data-tf-pick]');
    if (pick && fresh()) { // a size from the picker: price it again, for this view only
      const c = $('#drawer [data-close]'); if (c) c.click();
      return change(st => { st.sizes[pick.dataset.tfPick] = pick.dataset.size; });
    }
    if (!root()) return;
    const rows = t.closest('[data-tfrows]');
    if (rows && !(t.closest('a[data-drawer], button, input, select') && !t.closest('a[data-tfrows]'))) {
      e.preventDefault(); const ids = rows.dataset.tfrows.split(' ');
      const tpl = document.getElementById('tfr-' + ids[0]), a = tpl && $('.tfaddr', tpl.content);
      return openRows(ids, a ? a.textContent : 'Resource', 'Resource');
    }
    const v = t.closest('#tfview');
    if (v && fresh()) {
      const n = t.closest('.tfn, .tff');
      if (moved) return;
      if (n && n.dataset.expand) return change(st => { st.expanded.push(n.dataset.expand); });
      if (n) return select(tf.sel === n.dataset.id ? '' : n.dataset.id);
      return clearSel();
    }
    const dp = t.closest('#tf-drop');
    if (dp && !t.closest('button, label, input')) { $('#tf-folder').click(); return; }
    const exp = t.closest('[data-tf-export]'); if (exp) return exportAs(exp.dataset.tfExport);
    const vf = t.closest('[data-tf-var]');
    if (vf && fresh()) { const p = vf.dataset.tfVar; return change(st => { const i = st.vars.indexOf(p); if (i < 0) st.vars.push(p); else st.vars.splice(i, 1); }); }
    const a = t.closest('[data-tf]'); if (!a) return;
    switch (a.dataset.tf) {
      case 'folder': return $('#tf-folder').click();
      case 'plan': return $('#tf-planfile').click();
      case 'sample': return sample();
      case 'reset-sizes': return change(st => { st.sizes = {}; });
      case 'zoom-in': return zoomMid(1.25);
      case 'zoom-out': return zoomMid(.8);
      case 'fit': return fit();
      case 'clear': return clearSel();
    }
  });
  document.addEventListener('change', e => {
    const t = e.target; if (!t.matches || !root()) return;
    if (t.id === 'tf-folder') { load(fromInput(t.files)); t.value = ''; }
    else if (t.id === 'tf-planfile') { const f = t.files[0]; t.value = ''; if (f) load(new Map([[f.name, f]])); }
    else if (t.matches('[data-tf=group]') && fresh()) change(st => { st.group = t.value; });
    else if (t.matches('[data-tf=layout]') && fresh()) change(st => { st.layout = t.value; });
  });
  document.addEventListener('keydown', e => {
    const v = e.target.closest && e.target.closest('#tfview'); if (!v) return;
    const n = e.target.closest('.tfn, .tff'), k = e.key;
    if (n && (k === 'Enter' || k === ' ')) { e.preventDefault(); e.stopPropagation(); return n.dispatchEvent(new MouseEvent('click', { bubbles: true })); } // capture phase: the shell's role=button handler calls click(), which SVG boxes lack
    const pan = { ArrowLeft: [60, 0], ArrowRight: [-60, 0], ArrowUp: [0, 60], ArrowDown: [0, -60] }[k];
    if (pan) { e.preventDefault(); tf.x += pan[0]; tf.y += pan[1]; return apply(); }
    if (k === '+' || k === '=') return zoomMid(1.25);
    if (k === '-' || k === '_') return zoomMid(.8);
    if (k === '0') return fit();
    if (k === 'Escape') clearSel();
  }, true);
  // dropping a folder or a plan.json anywhere on the tab
  const files = e => root() && view() === 'diagram' && e.dataTransfer && [...e.dataTransfer.types].includes('Files'); // only the Terraform page takes files
  document.addEventListener('dragover', e => { if (files(e) && e.target.closest && e.target.closest('#tf')) { e.preventDefault(); const z = $('#tf-drop'); if (z) z.classList.add('over'); } });
  document.addEventListener('dragleave', e => { const z = $('#tf-drop'); if (z && !(e.relatedTarget && z.contains(e.relatedTarget))) z.classList.remove('over'); });
  document.addEventListener('drop', async e => {
    if (!files(e) || !e.target.closest || !e.target.closest('#tf')) return;
    e.preventDefault(); const z = $('#tf-drop'); if (z) z.classList.remove('over');
    try { load(await fromDrop(e.dataTransfer)); } catch (err) { fail('', 'Could not read what you dropped: ' + err.message); }
  });
  addEventListener('resize', () => { if (vw()) show(); });
  const boot = () => { if (fresh() && vw()) show(); };
  document.addEventListener('DOMContentLoaded', boot); document.addEventListener('htmx:afterSettle', boot);
})();
