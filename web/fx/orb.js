// The voice orb: a living, breathing sphere that listens. Its surface is driven by the
// real microphone level (with the browser's noise suppression on), and it changes
// colour by state: listening (teal), thinking (violet swirl), confirming (marigold).
import { shaderCanvas, NOISE } from './glsl.js';

const FRAG = NOISE + `
uniform float uLvl; uniform vec3 uA; uniform vec3 uB; uniform float uSwirl;
void main(){
  vec2 p=(gl_FragCoord.xy-.5*uR)/min(uR.x,uR.y);
  float r=length(p), ang=atan(p.y,p.x);
  float R0=.25+uLvl*.05+.006*sin(uT*1.6);
  // A wobbling silhouette: louder voice, bigger waves.
  float wob=fbm(vec2(cos(ang),sin(ang))*1.8+uT*(.35+uLvl*.7))*(.05+uLvl*.11);
  float rr=R0+wob;
  float d=r-rr;
  float body=smoothstep(.006,-.006,d);
  // A fake sphere normal gives the fluid inside real volume.
  float z=sqrt(max(rr*rr-r*r,0.))/max(rr,.001);
  vec3 n=normalize(vec3(p/max(rr,.001),z+.001));
  vec2 s=n.xy/(1.3+n.z);
  float c=uT*.25*uSwirl;mat2 rot=mat2(cos(c),-sin(c),sin(c),cos(c));
  float f1=fbm(rot*s*3.0+vec2(uT*.28,-uT*.2));
  float f2=fbm(rot*s*5.5-vec2(uT*.2,uT*.13)+f1*1.6);
  vec3 col=mix(uA*.28,uA,smoothstep(-.3,.28,f1));
  col=mix(col,uB,smoothstep(.0,.42,f2));
  col+=pow(1.-n.z,2.6)*mix(uA,vec3(1.),.45)*1.3;
  col+=pow(max(dot(n,normalize(vec3(-.45,.6,.65))),0.),34.)*.95;
  col*=.72+.5*n.z;
  float glow=exp(-max(d,0.)*(9.-uLvl*3.))*.62;
  float ring=exp(-abs(r-(rr+.09+uLvl*.05+.012*sin(uT*2.)))*95.)*.34;
  float ring2=exp(-abs(r-(rr+.17+uLvl*.1))*140.)*.16;
  vec3 g=(uA*glow+uB*ring+uA*ring2)*(1.-body);
  float al=clamp(body+glow+ring+ring2,0.,1.);
  gl_FragColor=vec4(col*body+g,al);
}`;

const STATES = {
  idle: [[0.2, 0.55, 0.95], [0.18, 0.9, 0.77], 0.5],
  listen: [[0.1, 0.82, 0.72], [0.42, 0.95, 0.65], 1],
  think: [[0.46, 0.33, 0.98], [0.95, 0.42, 0.8], 3.2],
  confirm: [[1.0, 0.68, 0.14], [1.0, 0.86, 0.45], 0.8],
  error: [[1.0, 0.33, 0.3], [1.0, 0.62, 0.3], 0.6],
};

export function mount(el, cfg = {}) {
  const lerp = (a, b, k) => a + (b - a) * k;
  let target = STATES[cfg.state] || STATES.idle;
  const cur = { a: [...target[0]], b: [...target[1]], s: target[2], lvl: 0 };
  let lvlT = 0, analyser = null, stream = null, ctx = null, bins = null;
  const sc = shaderCanvas(el, FRAG, {
    uniforms: ['uLvl', 'uA', 'uB', 'uSwirl'],
    capture: cfg.capture,
    onFrame(gl, U, t) {
      for (let i = 0; i < 3; i++) { cur.a[i] = lerp(cur.a[i], target[0][i], 0.05); cur.b[i] = lerp(cur.b[i], target[1][i], 0.05); }
      cur.s = lerp(cur.s, target[2], 0.04);
      if (analyser) {
        analyser.getByteFrequencyData(bins);
        // Speech band only, so a fridge hum doesn't excite the orb.
        let sum = 0;
        for (let i = 2; i < 24; i++) sum += bins[i];
        lvlT = Math.min(1, (sum / 22 / 255) * 2.1);
      }
      cur.lvl = lerp(cur.lvl, lvlT, 0.22);
      gl.uniform1f(U.uLvl, cur.lvl);
      gl.uniform3fv(U.uA, cur.a);
      gl.uniform3fv(U.uB, cur.b);
      gl.uniform1f(U.uSwirl, cur.s);
    },
  });
  if (!sc) return { send() {}, dispose() {} };
  const stopMic = () => {
    stream?.getTracks().forEach((t) => t.stop());
    ctx?.close?.();
    stream = ctx = analyser = null;
    lvlT = 0;
  };
  const startMic = async () => {
    try {
      stream = await navigator.mediaDevices.getUserMedia({ audio: { noiseSuppression: true, echoCancellation: true, autoGainControl: true } });
      ctx = new (window.AudioContext || window.webkitAudioContext)();
      analyser = ctx.createAnalyser();
      analyser.fftSize = 256;
      analyser.smoothingTimeConstant = 0.72;
      bins = new Uint8Array(analyser.frequencyBinCount);
      ctx.createMediaStreamSource(stream).connect(analyser);
    } catch (_) { /* The orb still animates; speech recognition reports its own error. */ }
  };
  return {
    send(m) {
      if (m.state && STATES[m.state]) target = STATES[m.state];
      if (m.mic === true) startMic();
      if (m.mic === false) stopMic();
      if (m.level !== undefined) lvlT = m.level;
    },
    dispose() { stopMic(); sc.dispose(); },
  };
}
