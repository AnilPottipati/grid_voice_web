// Glue between the Flutter app and wake.js ("Hey Grid", openWakeWord, runs in the browser).
// Dart calls window.GridWake.*; nothing here sends audio anywhere.
(function () {
  const WORKLET = 'class P extends AudioWorkletProcessor{process(i){const c=i[0][0];if(c)this.port.postMessage(c.slice(0));return true}}registerProcessor("pcm-tap",P);';

  function makeResampler(rate) {
    const ratio = rate / 16000;
    let carry = new Float32Array(0), pos = 0;
    const toI16 = v => { v = Math.max(-1, Math.min(1, v)); return v < 0 ? v * 32768 : v * 32767; };
    return f => {
      if (rate === 16000) { const o = new Int16Array(f.length); for (let i = 0; i < f.length; i++) o[i] = toI16(f[i]); return o; }
      const buf = new Float32Array(carry.length + f.length); buf.set(carry); buf.set(f, carry.length);
      const out = [];
      while (pos + 1 < buf.length) { const i = Math.floor(pos), fr = pos - i; out.push(toI16(buf[i] + (buf[i + 1] - buf[i]) * fr)); pos += ratio; }
      const keep = Math.floor(pos); carry = buf.slice(keep); pos -= keep;
      return Int16Array.from(out);
    };
  }

  const url = p => new URL(p, document.baseURI).href;

  window.GridWake = {
    available() { return typeof ort !== 'undefined' && !!window.Wake; },
    // onWake(stream, clipInt16), onError(message)
    start(threshold, need, onWake, onError) {
      ort.env.wasm.wasmPaths = url('wake/ort/');
      return window.Wake.start({
        ort, base: url('wake/'), worklet: WORKLET, makeResampler,
        threshold: () => threshold, need: () => need, onWake, onError,
      });
    },
    stop(keepStream) { return window.Wake.stop(!!keepStream); },
    resume() { window.Wake.resume(); },
    status() { const s = window.Wake.state; return JSON.stringify({ on: s.on, warm: s.warm, score: s.score, peak: s.peak, error: s.error }); },
    downloadClip() {
      const a = document.createElement('a');
      a.href = URL.createObjectURL(window.Wake.clipWav());
      a.download = 'wake-clip-' + Date.now() + '.wav';
      document.body.appendChild(a); a.click(); a.remove();
    },
  };
  // the browser wants one tap before it lets the mic stream run
  addEventListener('pointerdown', () => { try { window.Wake.resume(); } catch (e) { } }, { passive: true });
})();
