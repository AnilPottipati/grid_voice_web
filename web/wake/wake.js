// "Hey Grid" wake word, run entirely in the browser (nothing is sent anywhere while it listens).
// Pipeline (openWakeWord): 16 kHz audio -> 80 ms chunks -> melspectrogram.onnx -> embedding_model.onnx (96 numbers per chunk)
// -> the last 16 embeddings -> grid_wake.onnx -> a score from 0 to 1. A wake is N scores in a row at or above the threshold.
// The page gives this file: the onnxruntime-web object (ort), a mic resampler, the audio worklet source, and the settings.
(function () {
  const CHUNK = 1280, CTXN = 480, WIN = 76, EMB = 16, MAXQ = 16000 * 3, CLIP = 16000 * 3;
  let ort = null, S = null, loading = null;
  const st = { on: false, score: 0, peak: 0, warm: false, error: '' };

  async function loadModels(base) {
    if (S) return S;
    if (!loading) loading = (async () => {
      ort.env.wasm.numThreads = 1;             // one thread: no SharedArrayBuffer needed
      ort.env.wasm.proxy = true;               // inference runs in a worker, so the page stays smooth
      const o = { executionProviders: ['wasm'] };
      const [m, e, w] = await Promise.all(['melspectrogram', 'embedding_model', 'grid_wake'].map(n => ort.InferenceSession.create(base + n + '.onnx', o)));
      S = { m, e, w };
      return S;
    })().catch(err => { loading = null; throw err; });
    return loading;
  }

  function pipeline(M) {
    let tail = new Float32Array(CTXN), mel = [], emb = [];
    return async function (f32) {
      const x = new Float32Array(CTXN + CHUNK); x.set(tail); x.set(f32, CTXN); tail = x.slice(x.length - CTXN);
      const r = await M.m.run({ [M.m.inputNames[0]]: new ort.Tensor('float32', x, [1, x.length]) });
      const d = r[M.m.outputNames[0]].data, n = d.length / 32;
      for (let i = 0; i < n; i++) { const fr = new Float32Array(32); for (let j = 0; j < 32; j++) fr[j] = d[i * 32 + j] / 10 + 2; mel.push(fr); }
      if (mel.length > WIN) mel.splice(0, mel.length - WIN);
      if (mel.length < WIN) return null;
      const inp = new Float32Array(WIN * 32); mel.forEach((fr, i) => inp.set(fr, i * 32));
      const er = await M.e.run({ [M.e.inputNames[0]]: new ort.Tensor('float32', inp, [1, WIN, 32, 1]) });
      emb.push(Float32Array.from(er[M.e.outputNames[0]].data));
      if (emb.length > EMB) emb.shift();
      if (emb.length < EMB) return null;
      const wi = new Float32Array(EMB * 96); emb.forEach((v, i) => wi.set(v, i * 96));
      const wr = await M.w.run({ [M.w.inputNames[0]]: new ort.Tensor('float32', wi, [1, EMB, 96]) });
      return wr[M.w.outputNames[0]].data[0];
    };
  }

  let cur = null, ring = new Int16Array(0);
  function cat(a, b, max, T) { const all = new T(a.length + b.length); all.set(a); all.set(b, a.length); return all.length > max ? all.slice(all.length - max) : all; }

  // o: { ort, base, worklet, makeResampler, threshold(), need(), onWake(stream), onError(msg) }
  async function start(o) {
    if (cur) return;
    ort = o.ort;
    const run = { active: true, stream: null, ctx: null, node: null };
    cur = run; st.on = true; st.score = 0; st.peak = 0; st.warm = false; st.error = '';
    try {
      const M = await loadModels(o.base);
      const chunk = pipeline(M);
      const zero = new Float32Array(CHUNK);
      for (let i = 0; i < 30; i++) await chunk(zero);          // fill the buffers with silence so it is ready at once
      if (!run.active) return;
      run.stream = o.stream || await navigator.mediaDevices.getUserMedia({ audio: { channelCount: 1, echoCancellation: true, noiseSuppression: true } });
      if (!run.active) { run.stream.getTracks().forEach(t => t.stop()); return; }
      run.ctx = new AudioContext({ sampleRate: 16000 });
      await run.ctx.audioWorklet.addModule(URL.createObjectURL(new Blob([o.worklet], { type: 'application/javascript' })));
      run.node = new AudioWorkletNode(run.ctx, 'pcm-tap');
      run.ctx.createMediaStreamSource(run.stream).connect(run.node);
      try { await run.ctx.resume(); } catch (e) { }
      const rs = o.makeResampler(run.ctx.sampleRate);
      let pend = new Float32Array(0), pumping = false, hits = 0;
      async function pump() {
        pumping = true;
        try {
          while (run.active && pend.length >= CHUNK) {
            const c = pend.slice(0, CHUNK); pend = pend.slice(CHUNK);
            const s = await chunk(c);
            if (!run.active) return;
            if (s == null) continue;
            st.score = s; st.warm = true; if (s > st.peak) st.peak = s;
            hits = s >= o.threshold() ? hits + 1 : 0;
            if (hits >= o.need()) { const clip = ring.slice(Math.max(0, ring.length - 32000)); const keep = stop(true); o.onWake(keep, clip); return; }
          }
        } catch (e) { st.error = String(e && e.message || e); if (o.onError) o.onError(st.error); stop(false); }
        finally { pumping = false; }
      }
      run.node.port.onmessage = e => {
        if (!run.active) return;
        const i16 = rs(e.data);
        ring = cat(ring, i16, CLIP, Int16Array);
        pend = cat(pend, Float32Array.from(i16), MAXQ, Float32Array);
        if (!pumping) pump();
      };
      if (run.ctx.state !== 'running') st.error = 'tap';       // the browser wants one tap before it allows the mic stream to run
    } catch (e) {
      st.error = String(e && e.message || e); if (o.onError) o.onError(st.error); stop(false);
    }
  }

  // stop(true) keeps the microphone stream open and returns it, so live mode can take it over without losing the first words.
  function stop(keepStream) {
    const run = cur; if (!run) return null;
    run.active = false; cur = null; st.on = false;
    try { run.node && run.node.disconnect(); } catch (e) { }
    try { run.ctx && run.ctx.close(); } catch (e) { }
    if (keepStream) return run.stream;
    try { run.stream && run.stream.getTracks().forEach(t => t.stop()); } catch (e) { }
    return null;
  }

  function resume() { try { if (cur && cur.ctx && cur.ctx.state !== 'running') { cur.ctx.resume().then(() => { if (cur && cur.ctx.state === 'running' && st.error === 'tap') st.error = ''; }); } } catch (e) { } }

  // the last 3 seconds heard while listening, as a 16 kHz WAV (for checking and tuning on this device; never uploaded)
  function clipWav() {
    const n = ring.length, b = new ArrayBuffer(44 + n * 2), v = new DataView(b);
    const w = (p, s) => { for (let i = 0; i < s.length; i++) v.setUint8(p + i, s.charCodeAt(i)); };
    w(0, 'RIFF'); v.setUint32(4, 36 + n * 2, true); w(8, 'WAVE'); w(12, 'fmt '); v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 1, true);
    v.setUint32(24, 16000, true); v.setUint32(28, 32000, true); v.setUint16(32, 2, true); v.setUint16(34, 16, true); w(36, 'data'); v.setUint32(40, n * 2, true);
    for (let i = 0; i < n; i++) v.setInt16(44 + i * 2, ring[i], true);
    return new Blob([b], { type: 'audio/wav' });
  }

  // the last `sec` seconds heard, as raw 16 kHz 16-bit mono PCM (sent only to check whose voice said "Hey Grid")
  function clipPcm(sec) { const n = Math.min(ring.length, Math.round(16000 * (sec || 2))); return ring.slice(ring.length - n); }

  window.Wake = { start, stop, resume, clipWav, clipPcm, state: st };
})();
