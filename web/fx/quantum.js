// Loading state: thousands of points fall from chaos into order. They pass through a
// sphere and a double helix, then settle into the benj mark, which is the product's
// own idea (scattered records becoming one clear answer).
import * as THREE from './three.module.min.js';
import { drawLogo } from './glsl.js';

const fib = (i, n, r) => {
  const y = 1 - (2 * i) / (n - 1), rad = Math.sqrt(1 - y * y), th = i * 2.399963;
  return [Math.cos(th) * rad * r, y * r, Math.sin(th) * rad * r];
};
const helix = (i, n) => {
  const u = i / n, a = u * 22 + (i % 2) * Math.PI;
  const rung = i % 12 === 0;
  const k = rung ? (i % 24 === 0 ? 0.25 : 0.65) : 1;
  return [Math.cos(a) * 0.72 * k, (u - 0.5) * 3.4, Math.sin(a) * 0.72 * k];
};

function logoPoints(n) {
  const S = 180, c = document.createElement('canvas');
  c.width = c.height = S;
  const g = c.getContext('2d', { willReadFrequently: true });
  g.fillStyle = g.strokeStyle = '#fff';
  drawLogo(g, S);
  const d = g.getImageData(0, 0, S, S).data, pts = [];
  for (let y = 0; y < S; y += 1) for (let x = 0; x < S; x += 1) if (d[(x + y * S) * 4 + 3] > 128) pts.push([(x / S - 0.5) * 3.3, (0.5 - y / S) * 3.3 + 0.1]);
  const out = [];
  for (let i = 0; i < n; i++) {
    const p = pts[Math.floor(Math.random() * pts.length)] || [0, 0];
    out.push([p[0] + (Math.random() - 0.5) * 0.02, p[1] + (Math.random() - 0.5) * 0.02, (Math.random() - 0.5) * 0.12]);
  }
  return out;
}

export function mount(el, cfg = {}) {
  const low = (navigator.hardwareConcurrency || 4) <= 4 || innerWidth < 500;
  const N = cfg.count || (low ? 3600 : 9000);
  const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: false, preserveDrawingBuffer: !!cfg.capture });
  renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 1.5));
  renderer.domElement.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;display:block';
  el.appendChild(renderer.domElement);
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(42, 1, 0.1, 40);
  camera.position.z = 6.2;

  const logos = logoPoints(N);
  const a0 = new Float32Array(N * 3), a1 = new Float32Array(N * 3), a2 = new Float32Array(N * 3), a3 = new Float32Array(N * 3), seed = new Float32Array(N);
  for (let i = 0; i < N; i++) {
    a0.set([(Math.random() - 0.5) * 9, (Math.random() - 0.5) * 9, (Math.random() - 0.5) * 9], i * 3);
    a1.set(fib(i, N, 1.6), i * 3);
    a2.set(helix(i, N), i * 3);
    a3.set(logos[i], i * 3);
    seed[i] = Math.random();
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.BufferAttribute(a0, 3));
  geo.setAttribute('a1', new THREE.BufferAttribute(a1, 3));
  geo.setAttribute('a2', new THREE.BufferAttribute(a2, 3));
  geo.setAttribute('a3', new THREE.BufferAttribute(a3, 3));
  geo.setAttribute('seed', new THREE.BufferAttribute(seed, 1));
  const mat = new THREE.ShaderMaterial({
    transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    uniforms: { uT: { value: 0 }, uPhase: { value: 0 }, uPx: { value: 1 } },
    vertexShader: `
      attribute vec3 a1; attribute vec3 a2; attribute vec3 a3; attribute float seed;
      uniform float uT, uPhase, uPx; varying float vK; varying float vS;
      void main(){
        float f=clamp(uPhase,0.,3.);
        float st=clamp(f-seed*.55,0.,3.)/(1.-.183);
        vec3 p;
        float s=smoothstep(0.,1.,fract(min(st,2.9999)));
        if(st<1.) p=mix(position,a1,s); else if(st<2.) p=mix(a1,a2,s); else p=mix(a2,a3,s);
        if(st>=3.) p=a3;
        p+=vec3(sin(uT*.8+seed*40.),cos(uT*.7+seed*30.),sin(uT*.6+seed*20.))*.012;
        vS=seed; vK=clamp(st/3.,0.,1.);
        vec4 mv=modelViewMatrix*vec4(p,1.);
        gl_PointSize=(1.3+seed*2.2)*uPx*(6.2/-mv.z);
        gl_Position=projectionMatrix*mv;
      }`,
    fragmentShader: `
      varying float vK; varying float vS;
      void main(){
        float d=length(gl_PointCoord-.5);
        float a=smoothstep(.5,.05,d);
        vec3 c=mix(vec3(.2,.9,.78),vec3(1.,.72,.18),smoothstep(.3,1.,vK+vS*.2));
        c=mix(c,vec3(.5,.45,1.),smoothstep(.72,1.,vS)*(1.-vK));
        gl_FragColor=vec4(c,a*.8);
      }`,
  });
  const pts = new THREE.Points(geo, mat);
  scene.add(pts);

  const resize = () => {
    const w = Math.max(el.clientWidth, 1), h = Math.max(el.clientHeight, 1);
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.fov = 42 * Math.max(1, 0.85 / camera.aspect);
    camera.updateProjectionMatrix();
    mat.uniforms.uPx.value = Math.min(devicePixelRatio || 1, 1.5) * (h / 700 + 0.5);
  };
  const ro = new ResizeObserver(resize); ro.observe(el); resize();

  let raf = 0, dead = false, t = 0, last = performance.now(), mode = cfg.mode || 'loop', phase = cfg.phase ?? 0;
  const loop = () => {
    if (dead) return;
    raf = requestAnimationFrame(loop);
    const now = performance.now(), dt = Math.min((now - last) / 1000, 0.05);
    last = now; t += dt;
    if (mode === 'loop') phase = phase >= 3.9 ? 0 : phase + dt * 0.42; // Hold on the logo, then start again.
    else if (mode === 'finish') phase = Math.min(3, phase + dt * 0.9);
    mat.uniforms.uT.value = t;
    mat.uniforms.uPhase.value = phase;
    const settled = THREE.MathUtils.smoothstep(phase, 2, 3);
    pts.rotation.y = (1 - settled) * t * 0.35 + settled * Math.sin(t * 0.8) * 0.16;
    renderer.render(scene, camera);
  };
  loop();
  return {
    send(m) { if (m.mode) mode = m.mode; if (m.phase !== undefined) phase = m.phase; },
    dispose() { dead = true; cancelAnimationFrame(raf); ro.disconnect(); geo.dispose(); mat.dispose(); renderer.dispose(); renderer.forceContextLoss?.(); renderer.domElement.remove(); },
  };
}
