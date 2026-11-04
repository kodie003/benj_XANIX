// Entry point Flutter talks to. Effects load on demand, so an owner who only logs stock
// never downloads the team page or the globe.
const handles = new WeakMap();
const HEAVY = ['mascot', 'team', 'globe', 'quantum', 'glyph'];
const LOW_END = () => (navigator.deviceMemory && navigator.deviceMemory <= 2) || matchMedia('(prefers-reduced-motion: reduce)').matches;
const hasWebGL = () => {
  try { const c = document.createElement('canvas'); return !!(c.getContext('webgl2') || c.getContext('webgl')); } catch (_) { return false; }
};

window.BenjFX = {
  lowEnd: LOW_END,
  webgl: hasWebGL,
  async mount(el, kind, json) {
    const cfg = json ? JSON.parse(json) : {};
    // The PRD targets 2 GB Android phones: graphics must never get in the way of logging.
    // These phones (and anyone who asks for reduced motion) get the still picture instead.
    if (!hasWebGL() || (LOW_END() && HEAVY.includes(kind) && !cfg.always)) {
      el.dispatchEvent(new CustomEvent('fx', { detail: JSON.stringify({ name: 'nowebgl' }) }));
      return;
    }
    const mod = await import(`./${kind}.js`);
    if (el.dataset.fxDead) return;
    handles.set(el, mod.mount(el, cfg));
    el.dispatchEvent(new CustomEvent('fx', { detail: JSON.stringify({ name: 'mounted' }) }));
  },
  send(el, json) { handles.get(el)?.send?.(JSON.parse(json)); },
  dispose(el) {
    el.dataset.fxDead = '1';
    handles.get(el)?.dispose?.();
    handles.delete(el);
  },
};

// ---- Voice: browser speech recognition. Twi and other languages can be added later. ----
let rec = null;
window.BenjVoice = {
  supported: () => !!(window.SpeechRecognition || window.webkitSpeechRecognition),
  start(onResult, onEnd, lang) {
    const R = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!R) return onEnd('unsupported');
    rec = new R();
    rec.lang = lang || 'en-GH';
    rec.interimResults = true;
    rec.continuous = false;
    rec.maxAlternatives = 1;
    let err = '';
    rec.onresult = (e) => {
      const r = e.results[e.results.length - 1];
      onResult(r[0].transcript, r.isFinal);
    };
    rec.onerror = (e) => { err = e.error || 'error'; };
    rec.onend = () => onEnd(err);
    rec.start();
  },
  stop() { try { rec?.stop(); } catch (_) {} },
};
