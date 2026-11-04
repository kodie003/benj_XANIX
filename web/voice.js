// Speech to text with the browser's own recogniser (Chrome on Android uses Google's).
// English as spoken in Ghana first; the owner always sees and can fix the words.
(function () {
  let rec = null;
  window.BenjVoice = {
    supported() {
      return !!(window.SpeechRecognition || window.webkitSpeechRecognition);
    },
    // onText(text, isFinal) is called as words arrive; onEnd(error) when it stops.
    start(onText, onEnd) {
      const R = window.SpeechRecognition || window.webkitSpeechRecognition;
      if (!R) { onEnd('unsupported'); return; }
      try { rec && rec.abort(); } catch (_) {}
      rec = new R();
      rec.lang = 'en-GH';
      rec.interimResults = true;
      rec.continuous = true;
      rec.maxAlternatives = 1;
      let error = '';
      rec.onresult = (e) => {
        let text = '', isFinal = true;
        for (let i = 0; i < e.results.length; i++) {
          text += e.results[i][0].transcript + ' ';
          if (!e.results[i].isFinal) isFinal = false;
        }
        onText(text.trim(), isFinal);
      };
      rec.onerror = (e) => { error = e.error || 'error'; };
      rec.onend = () => { rec = null; onEnd(error); };
      try { rec.start(); } catch (e) { onEnd('busy'); }
    },
    stop() { try { rec && rec.stop(); } catch (_) {} },
  };
})();
