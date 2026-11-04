// Team portraits made of dots, with depth, data-rain and lightning-like contours.
// Inspired by the feel of lusion.co/about, built from scratch for benj.
// Drop a clear headshot at web/team/<id>.jpg and that person's portrait appears
// automatically. Until then an anonymous dotted bust holds their place, never a fake face.
import * as THREE from './three.module.min.js';

const SIDE = 200;

function bustCanvas() {
  // Anonymous shape, lit from the side so the dots read as a volume.
  const c = document.createElement('canvas');
  c.width = c.height = SIDE;
  const g = c.getContext('2d', { willReadFrequently: true });
  g.fillStyle = '#000'; g.fillRect(0, 0, SIDE, SIDE);
  g.save();
  g.filter = `blur(${SIDE * 0.016}px)`;
  const light = (x0, y0, r0, x, y, r, col) => { const a = g.createRadialGradient(x0, y0, r0, x, y, r); a.addColorStop(0, col); a.addColorStop(1, '#0a0a0a'); return a; };
  g.fillStyle = light(SIDE * 0.62, SIDE * 0.76, 4, SIDE * 0.5, SIDE * 0.86, SIDE * 0.5, '#9a9a9a');
  g.beginPath(); g.ellipse(SIDE * 0.5, SIDE * 0.98, SIDE * 0.4, SIDE * 0.29, 0, 0, 7); g.fill();
  g.fillStyle = '#4d4d4d';
  g.fillRect(SIDE * 0.42, SIDE * 0.56, SIDE * 0.16, SIDE * 0.2);
  g.fillStyle = light(SIDE * 0.6, SIDE * 0.33, 3, SIDE * 0.5, SIDE * 0.38, SIDE * 0.27, '#f2f2f2');
  g.beginPath(); g.ellipse(SIDE * 0.5, SIDE * 0.38, SIDE * 0.19, SIDE * 0.25, 0, 0, 7); g.fill();
  g.restore();
  return c;
}

const loadPortrait = (src) => new Promise((resolve) => {
  if (!src) return resolve(bustCanvas());
  const im = new Image();
  im.onload = () => {
    const c = document.createElement('canvas');
    c.width = c.height = SIDE;
    const g = c.getContext('2d', { willReadFrequently: true });
    const s = Math.min(im.width, im.height);
    g.filter = 'contrast(1.25) brightness(1.05) grayscale(1)';
    g.drawImage(im, (im.width - s) / 2, Math.max(0, (im.height - s) * 0.15), s, s, 0, 0, SIDE, SIDE);
    resolve(c);
  };
  im.onerror = () => resolve(bustCanvas());
  im.src = src;
});

function sample(canvas, N) {
  const d = canvas.getContext('2d', { willReadFrequently: true }).getImageData(0, 0, SIDE, SIDE).data;
  const lum = (x, y) => d[(x + y * SIDE) * 4] / 255;
  const pos = new Float32Array(N * 3), bright = new Float32Array(N);
  let i = 0, guard = 0;
  while (i < N && guard < N * 80) {
    guard++;
    const x = Math.floor(Math.random() * SIDE), y = Math.floor(Math.random() * SIDE);
    const l = lum(x, y);
    if (Math.random() > l * 0.95 + 0.006) continue;
    pos.set([(x / SIDE - 0.5) * 4.6, (0.5 - y / SIDE) * 4.6, l * 0.75 + (Math.random() - 0.5) * 0.03], i * 3);
    bright[i] = l;
    i++;
  }
  for (; i < N; i++) { pos.set([(Math.random() - 0.5) * 5, (Math.random() - 0.5) * 5, -1], i * 3); bright[i] = 0.02; }
  return { pos, bright };
}

export function mount(el, cfg = {}) {
  const members = cfg.members || [];
  const low = (navigator.hardwareConcurrency || 4) <= 4 || innerWidth < 500;
  const N = cfg.count || (low ? 14000 : 30000);
  const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: false, preserveDrawingBuffer: !!cfg.capture });
  renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 1.5));
  renderer.domElement.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;display:block;touch-action:pan-y';
  el.appendChild(renderer.domElement);
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(38, 1, 0.1, 50);
  camera.position.set(0, 0, 7.4);

  // Portrait dots.
  const geo = new THREE.BufferGeometry();
  const initial = new Float32Array(N * 3);
  const seed = new Float32Array(N);
  for (let i = 0; i < N; i++) { initial.set([(Math.random() - 0.5) * 7, (Math.random() - 0.5) * 7, (Math.random() - 0.5) * 3], i * 3); seed[i] = Math.random(); }
  geo.setAttribute('position', new THREE.BufferAttribute(initial, 3));
  geo.setAttribute('aTo', new THREE.BufferAttribute(new Float32Array(initial), 3));
  geo.setAttribute('aFromL', new THREE.BufferAttribute(new Float32Array(N), 1));
  geo.setAttribute('aToL', new THREE.BufferAttribute(new Float32Array(N), 1));
  geo.setAttribute('aSeed', new THREE.BufferAttribute(seed, 1));
  const uni = { uT: { value: 0 }, uK: { value: 0 }, uPx: { value: 1 }, uM: { value: new THREE.Vector3(99, 99, 0) }, uF: { value: 0 } };
  const mat = new THREE.ShaderMaterial({
    transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, uniforms: uni,
    vertexShader: `attribute vec3 aTo; attribute float aFromL,aToL,aSeed;
      uniform float uT,uK,uPx,uF; uniform vec3 uM; varying float vL; varying float vS;
      void main(){
        float k=smoothstep(aSeed*.45,.55+aSeed*.45,uK);
        vec3 p=mix(position,aTo,k);
        // Particles lift and swirl mid-morph, so a change of person feels like a current.
        float m=sin(k*3.14159);
        p.xy+=vec2(sin(aSeed*90.+uT),cos(aSeed*60.+uT))*m*.5;
        p.z+=m*sin(aSeed*40.)*.8;
        // Finger or cursor pushes the dots away, liquid-like.
        vec2 d=p.xy-uM.xy; float r=length(d);
        float f=smoothstep(1.05,0.,r)*uF;
        p.xy+=normalize(d+.0001)*f*.55*(0.7+aSeed*.6);
        p.z+=f*.5;
        p+=vec3(sin(uT*.6+aSeed*20.),cos(uT*.5+aSeed*17.),sin(uT*.4+aSeed*11.))*.006;
        vL=mix(aFromL,aToL,k); vS=aSeed;
        vec4 mv=modelViewMatrix*vec4(p,1.);
        gl_PointSize=(1.05+vL*1.9)*uPx*(7.4/-mv.z);
        gl_Position=projectionMatrix*mv;
      }`,
    fragmentShader: `varying float vL; varying float vS;
      void main(){float d=length(gl_PointCoord-.5);float a=smoothstep(.5,.2,d);
        vec3 c=mix(vec3(.4,.62,.76),vec3(.93,.98,1.),vL);
        gl_FragColor=vec4(c,a*(.3+vL*.7));}`,
  });
  const pts = new THREE.Points(geo, mat);
  pts.frustumCulled = false;
  scene.add(pts);

  // Data rain: thin falling columns behind the portrait.
  const RN = low ? 800 : 1800;
  const rg = new THREE.BufferGeometry();
  const rp = new Float32Array(RN * 3), rs = new Float32Array(RN);
  for (let i = 0; i < RN; i++) { const col = Math.floor(Math.random() * 36); rp.set([(col / 36 - 0.5) * 12, Math.random() * 8 - 4, -2.2 - (col % 5) * 0.4], i * 3); rs[i] = Math.random(); }
  rg.setAttribute('position', new THREE.BufferAttribute(rp, 3));
  rg.setAttribute('aS', new THREE.BufferAttribute(rs, 1));
  const rm = new THREE.ShaderMaterial({
    transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, uniforms: { uT: uni.uT, uPx: uni.uPx },
    vertexShader: `attribute float aS; uniform float uT,uPx; varying float vA;
      void main(){vec3 p=position;p.y=mod(p.y-uT*(.28+aS*.5)+4.,8.)-4.;
        vA=(.2+.8*pow(fract(aS*7.+uT*.25),6.))*smoothstep(4.,2.4,abs(p.y));
        gl_PointSize=uPx*2.1;gl_Position=projectionMatrix*modelViewMatrix*vec4(p,1.);}`,
    fragmentShader: 'varying float vA;void main(){gl_FragColor=vec4(vec3(.6,.85,1.)*vA,vA*.85);}',
  });
  scene.add(new THREE.Points(rg, rm));

  // Contour "lightning" at the base: bright flowing filaments like an electric coastline.
  const LINES = 7, LP = 110;
  const lineObjs = [];
  for (let l = 0; l < LINES; l++) {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(LP * 3), 3));
    const m = new THREE.Line(g, new THREE.LineBasicMaterial({ color: l % 3 === 0 ? 0xdff6ff : 0x77c7c4, transparent: true, opacity: l % 3 === 0 ? 0.75 : 0.32, blending: THREE.AdditiveBlending, depthWrite: false }));
    m.frustumCulled = false;
    scene.add(m);
    lineObjs.push(m);
  }
  const wave = (x, t, l) => Math.sin(x * 2.3 + t * 0.7 + l) * 0.17 + Math.sin(x * 6.1 - t * 1.1 + l * 2.2) * 0.075 + Math.sin(x * 15.0 + t * 1.8 + l * 1.3) * 0.03;
  const updateLines = (t) => {
    lineObjs.forEach((m, l) => {
      const a = m.geometry.attributes.position;
      for (let i = 0; i < LP; i++) {
        const x = (i / (LP - 1) - 0.5) * 9;
        const env = Math.exp(-x * x * 0.1);
        a.setXYZ(i, x, -2.9 + l * 0.12 + wave(x, t, l) * env * 1.6, 0.6 - l * 0.1);
      }
      a.needsUpdate = true;
    });
  };

  const pointer = new THREE.Vector3(99, 99, 0);
  const plane = new THREE.Plane(new THREE.Vector3(0, 0, 1), 0);
  const ray = new THREE.Raycaster();
  const onMove = (e) => {
    const r = renderer.domElement.getBoundingClientRect();
    ray.setFromCamera(new THREE.Vector2(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1), camera);
    ray.ray.intersectPlane(plane, pointer);
    uni.uF.value = 1;
  };
  const onLeave = () => { uni.uF.value = 0; };
  const dom = renderer.domElement;
  dom.addEventListener('pointermove', onMove, { passive: true });
  dom.addEventListener('pointerdown', onMove, { passive: true });
  dom.addEventListener('pointerleave', onLeave);

  const samples = new Map();
  const getSample = async (m) => {
    if (samples.has(m?.id)) return samples.get(m?.id);
    const cvs = await loadPortrait(m?.photo);
    const s = sample(cvs, N);
    samples.set(m?.id, s);
    return s;
  };

  let index = 0, kT = 0;
  const morphTo = async (i) => {
    index = (i + members.length) % Math.max(members.length, 1);
    const s = await getSample(members[index]);
    const pa = geo.attributes.position, to = geo.attributes.aTo, fl = geo.attributes.aFromL, tl = geo.attributes.aToL;
    const k = Math.min(uni.uK.value, 1);
    if (k > 0) { pa.array.set(to.array); fl.array.set(tl.array); }
    to.array.set(s.pos);
    tl.array.set(s.bright);
    pa.needsUpdate = to.needsUpdate = fl.needsUpdate = tl.needsUpdate = true;
    uni.uK.value = 0;
    kT = 1;
    el.dispatchEvent(new CustomEvent('fx', { detail: JSON.stringify({ name: 'member', index }) }));
  };

  const resize = () => {
    const w = Math.max(el.clientWidth, 1), h = Math.max(el.clientHeight, 1);
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.fov = 38 * Math.max(1, 0.8 / camera.aspect);
    camera.updateProjectionMatrix();
    uni.uPx.value = Math.min(devicePixelRatio || 1, 1.5) * Math.max(0.85, h / 720);
  };
  const ro = new ResizeObserver(resize); ro.observe(el); resize();

  let raf = 0, dead = false, t = 0, last = performance.now();
  const auto = cfg.autoMs ?? 6500;
  let nextAuto = auto / 1000;
  const loop = () => {
    if (dead) return;
    raf = requestAnimationFrame(loop);
    const now = performance.now(), dt = Math.min((now - last) / 1000, 0.05);
    last = now; t += dt;
    uni.uT.value = t;
    uni.uM.value.lerp(pointer, 0.2);
    uni.uK.value = Math.min(kT, uni.uK.value + dt * 0.62);
    pts.rotation.y = Math.sin(t * 0.25) * 0.08;
    updateLines(t);
    if (auto && members.length > 1) { nextAuto -= dt; if (nextAuto <= 0) { nextAuto = auto / 1000; morphTo(index + 1); } }
    renderer.render(scene, camera);
  };
  morphTo(0);
  loop();

  return {
    send(m) { if (m.index !== undefined) { nextAuto = auto / 1000; morphTo(m.index); } },
    dispose() {
      dead = true;
      cancelAnimationFrame(raf);
      ro.disconnect();
      dom.removeEventListener('pointermove', onMove);
      dom.removeEventListener('pointerdown', onMove);
      dom.removeEventListener('pointerleave', onLeave);
      scene.traverse((o) => { o.geometry?.dispose?.(); o.material?.dispose?.(); });
      renderer.dispose();
      renderer.forceContextLoss?.();
      dom.remove();
    },
  };
}
