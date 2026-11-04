// Atomic globe: the world drawn in particles, assembling from the core, with a beacon
// on Berekuso (where benj started) and sonar pings where you touch. No image maps,
// no network. Drag to spin. Our own build, inspired by the Atomic Globe idea.
import * as THREE from './three.module.min.js';
import { LAND, LAND_W, LAND_H } from './land.js';

const bytes = Uint8Array.from(atob(LAND), (c) => c.charCodeAt(0));
const isLand = (lat, lon) => {
  const x = Math.min(LAND_W - 1, Math.floor(((lon + 180) / 360) * LAND_W));
  const y = Math.min(LAND_H - 1, Math.floor(((90 - lat) / 180) * LAND_H));
  const i = x + y * LAND_W;
  return (bytes[i >> 3] >> (i & 7)) & 1;
};
const toVec = (lat, lon, r) => {
  const a = THREE.MathUtils.degToRad(lat), b = THREE.MathUtils.degToRad(lon);
  return [Math.cos(a) * Math.sin(b) * r, Math.sin(a) * r, Math.cos(a) * Math.cos(b) * r];
};

export function mount(el, cfg = {}) {
  const low = (navigator.hardwareConcurrency || 4) <= 4 || innerWidth < 500;
  const T = cfg.count || (low ? 9000 : 20000);
  const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true, preserveDrawingBuffer: !!cfg.capture });
  renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 1.5));
  renderer.domElement.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;display:block;touch-action:pan-y';
  el.appendChild(renderer.domElement);
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(36, 1, 0.1, 30);
  camera.position.z = 6.6;
  const world = new THREE.Group();
  scene.add(world);

  const pos = [], from = [], seeds = [], land = [];
  for (let i = 0; i < T; i++) {
    const y = 1 - (2 * i) / (T - 1), lat = Math.asin(y) * 57.2958, lon = ((i * 137.50776) % 360) - 180;
    const l = isLand(lat, lon);
    if (!l && i % 11 !== 0) continue; // Oceans stay sparse so the continents read.
    pos.push(...toVec(lat, lon, 1.6));
    const s = Math.random();
    from.push(...toVec(lat, lon, 0.05 + s * 0.2));
    seeds.push(s);
    land.push(l ? 1 : 0);
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.BufferAttribute(new Float32Array(pos), 3));
  geo.setAttribute('aFrom', new THREE.BufferAttribute(new Float32Array(from), 3));
  geo.setAttribute('aS', new THREE.BufferAttribute(new Float32Array(seeds), 1));
  geo.setAttribute('aLand', new THREE.BufferAttribute(new Float32Array(land), 1));
  const uni = { uT: { value: 0 }, uIn: { value: 0 }, uPx: { value: 1 }, uPing: { value: new THREE.Vector3(0, 0, 1) }, uPingT: { value: -9 }, uHome: { value: new THREE.Vector3(...toVec(5.76, -0.22, 1.6)) } };
  const mat = new THREE.ShaderMaterial({
    transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, uniforms: uni,
    vertexShader: `attribute vec3 aFrom; attribute float aS,aLand; uniform float uT,uIn,uPx,uPingT; uniform vec3 uPing,uHome;
      varying float vL; varying float vF; varying float vP; varying float vH;
      void main(){
        float k=smoothstep(aS*.5,.5+aS*.5,uIn);
        vec3 p=mix(aFrom,position,k)*(1.+.004*sin(uT+aS*20.));
        float d=distance(normalize(position),normalize(uPing));
        float wave=max(0.,1.-abs(d-(uT-uPingT)*.9)*9.)*step(uPingT,uT)*max(0.,1.-(uT-uPingT)*.45);
        p*=1.+wave*.05; vP=wave;
        vH=smoothstep(.32,0.,distance(position,uHome));
        vL=aLand;
        vec4 mv=modelViewMatrix*vec4(p,1.);
        vF=smoothstep(-1.6,.7,(modelMatrix*vec4(p,1.)).z);
        gl_PointSize=(aLand>.5?1.7:.9)*uPx*(1.+wave*1.6+vH*.9);
        gl_Position=projectionMatrix*mv;
      }`,
    fragmentShader: `varying float vL,vF,vP,vH;
      void main(){float d=length(gl_PointCoord-.5);float a=smoothstep(.5,.1,d);
        vec3 c=vL>.5?mix(vec3(.2,.75,.68),vec3(.62,1.,.9),vF):vec3(.24,.32,.66);
        c=mix(c,vec3(1.,.74,.2),max(vP,vH));
        gl_FragColor=vec4(c,a*(vL>.5?.9:.28)*(.1+.9*vF));}`,
  });
  const pts = new THREE.Points(geo, mat);
  pts.frustumCulled = false;
  world.add(pts);

  // A soft atmosphere: fresnel shell.
  const atmo = new THREE.Mesh(new THREE.SphereGeometry(1.63, 48, 32), new THREE.ShaderMaterial({
    transparent: true, depthWrite: false, side: THREE.BackSide, blending: THREE.AdditiveBlending,
    vertexShader: 'varying vec3 vN;void main(){vN=normalize(normalMatrix*normal);gl_Position=projectionMatrix*modelViewMatrix*vec4(position*1.06,1.);}',
    fragmentShader: 'varying vec3 vN;void main(){float f=pow(1.-abs(vN.z),2.6);f*=smoothstep(0.,.25,1.-abs(vN.z));gl_FragColor=vec4(vec3(.2,.72,.8)*f*.9,f*.5);}',
  }));
  scene.add(atmo);

  // Beacon on Berekuso.
  const [hx, hy, hz] = toVec(5.76, -0.22, 1.6);
  const beacon = new THREE.Group();
  beacon.position.set(hx, hy, hz);
  beacon.lookAt(hx * 2, hy * 2, hz * 2);
  world.add(beacon);
  const dot = new THREE.Mesh(new THREE.CircleGeometry(0.032, 20), new THREE.MeshBasicMaterial({ color: 0xffcf5c }));
  dot.position.z = 0.012;
  beacon.add(dot);
  const rings = [0, 1, 2].map((i) => {
    const r = new THREE.Mesh(new THREE.RingGeometry(0.06, 0.068, 40), new THREE.MeshBasicMaterial({ color: 0xffb627, transparent: true, depthWrite: false, side: THREE.DoubleSide }));
    r.position.z = 0.01;
    beacon.add(r);
    return { r, o: i / 3 };
  });
  const tag = document.createElement('div');
  tag.textContent = cfg.label || 'Berekuso, Ghana';
  tag.style.cssText = 'position:absolute;left:0;top:0;font:600 12px "Instrument Sans",system-ui;color:#ffcf5c;text-shadow:0 1px 8px #000;white-space:nowrap;pointer-events:none';
  el.appendChild(tag);

  // Start facing Ghana.
  let yaw = THREE.MathUtils.degToRad(0.22) + 0.15, pitch = 0.12, velYaw = 0.06, dragging = false, lx = 0, ly = 0, startX = 0, startY = 0;
  const dom = renderer.domElement;
  const ray = new THREE.Raycaster();
  const onDown = (e) => { dragging = true; lx = startX = e.clientX; ly = startY = e.clientY; dom.setPointerCapture?.(e.pointerId); };
  const onMove = (e) => {
    if (!dragging) return;
    velYaw = (e.clientX - lx) * 0.006;
    yaw += velYaw;
    pitch = THREE.MathUtils.clamp(pitch + (e.clientY - ly) * 0.004, -0.9, 0.9);
    lx = e.clientX; ly = e.clientY;
  };
  const onUp = (e) => {
    dragging = false;
    if (Math.hypot(e.clientX - startX, e.clientY - startY) < 6) {
      const r = dom.getBoundingClientRect();
      ray.setFromCamera(new THREE.Vector2(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1), camera);
      const hit = new THREE.Vector3();
      if (ray.ray.intersectSphere(new THREE.Sphere(new THREE.Vector3(), 1.6), hit)) {
        uni.uPing.value.copy(world.worldToLocal(hit));
        uni.uPingT.value = uni.uT.value;
      }
    }
  };
  dom.addEventListener('pointerdown', onDown);
  dom.addEventListener('pointermove', onMove);
  dom.addEventListener('pointerup', onUp);
  dom.addEventListener('pointercancel', onUp);

  const resize = () => {
    const w = Math.max(el.clientWidth, 1), h = Math.max(el.clientHeight, 1);
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.fov = 36 * Math.max(1, 1 / camera.aspect);
    camera.updateProjectionMatrix();
    uni.uPx.value = Math.min(devicePixelRatio || 1, 1.5) * Math.max(1, Math.min(w, h) / 360);
  };
  const ro = new ResizeObserver(resize); ro.observe(el); resize();

  let raf = 0, dead = false, t = 0, last = performance.now();
  const v = new THREE.Vector3();
  const loop = () => {
    if (dead) return;
    raf = requestAnimationFrame(loop);
    const now = performance.now(), dt = Math.min((now - last) / 1000, 0.05);
    last = now; t += dt;
    uni.uT.value = t;
    uni.uIn.value = Math.min(1, uni.uIn.value + dt * 0.42);
    if (!dragging) { yaw += velYaw * dt * 2; velYaw += (0.05 - velYaw) * Math.min(dt * 1.5, 1); }
    world.rotation.set(pitch, yaw, 0);
    for (const o of rings) {
      const k = ((t * 0.5 + o.o) % 1);
      o.r.scale.setScalar(0.7 + k * 3.6);
      o.r.material.opacity = (1 - k) * 0.85;
    }
    world.updateMatrixWorld();
    v.set(hx, hy, hz);
    world.localToWorld(v);
    const facing = v.z > 0.2;
    tag.style.opacity = facing && uni.uIn.value > 0.8 ? '1' : '0';
    v.project(camera);
    tag.style.transform = `translate(${(v.x * 0.5 + 0.5) * el.clientWidth + 12}px,${(-v.y * 0.5 + 0.5) * el.clientHeight - 20}px)`;
    renderer.render(scene, camera);
  };
  loop();
  return {
    send() {},
    dispose() {
      dead = true;
      cancelAnimationFrame(raf);
      ro.disconnect();
      scene.traverse((o) => { o.geometry?.dispose?.(); o.material?.dispose?.(); });
      renderer.dispose();
      renderer.forceContextLoss?.();
      dom.remove();
      tag.remove();
    },
  };
}
