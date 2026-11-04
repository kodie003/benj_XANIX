// Stock Constellation: benj's take on a knowledge graph, and it answers a real question.
// Every product is a star. Height is DAYS OF STOCK LEFT, and the glowing floor is the
// moment you run out. Drag the timeline and every star sinks toward that floor at its
// own selling speed, so the owner can literally watch next week happen.
// Links join variants of one product and things bought on the same market trip.
// Tapping a star traces what it is connected to and opens that product.
import * as THREE from './three.module.min.js';

const COOL = new THREE.Color(0x2ee6c5), WARM = new THREE.Color(0xffb627), HOT = new THREE.Color(0xff5247), DIM = new THREE.Color(0x232a4a);
const HEIGHT_PER_DAY = 0.46, MAX_DAYS = 18;
const urgency = (days, warn) => (days <= warn ? HOT : days <= warn * 2.2 ? WARM : COOL);

export function mount(el, cfg = {}) {
  el.style.touchAction = 'none';
  const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true, preserveDrawingBuffer: !!cfg.capture });
  renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 1.75));
  renderer.domElement.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;display:block';
  el.appendChild(renderer.domElement);
  const scene = new THREE.Scene();
  scene.fog = new THREE.FogExp2(0x070a18, 0.035);
  const camera = new THREE.PerspectiveCamera(46, 1, 0.1, 100);

  // Labels are real DOM text: crisp, translated later, and readable on cheap phones.
  const labels = document.createElement('div');
  labels.style.cssText = 'position:absolute;inset:0;pointer-events:none;overflow:hidden;font:600 12px "Instrument Sans",system-ui,sans-serif;color:#eef1ff';
  el.appendChild(labels);

  // ---------- The floor: the run-out line ----------
  const floorMat = new THREE.ShaderMaterial({
    transparent: true, depthWrite: false, side: THREE.DoubleSide,
    uniforms: { uT: { value: 0 } },
    vertexShader: 'varying vec2 vU;void main(){vU=uv-.5;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}',
    fragmentShader: `varying vec2 vU;uniform float uT;
      void main(){float r=length(vU)*2.;
        float rings=smoothstep(.05,.0,abs(fract(r*6.-uT*.1)-.5));
        float fade=smoothstep(1.,.15,r);
        vec3 c=mix(vec3(1.,.32,.28),vec3(1.,.55,.2),r);
        gl_FragColor=vec4(c,(rings*.28+.035*(1.-r))*fade);}`,
  });
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(16, 16), floorMat);
  floor.rotation.x = -Math.PI / 2;
  scene.add(floor);

  // Horizon rings marking how many days ahead each height is.
  const horizons = [3, 7, 14].map((d) => {
    const pts = [];
    for (let i = 0; i <= 96; i++) pts.push(new THREE.Vector3(Math.cos((i / 96) * 6.2832) * 4.3, d * HEIGHT_PER_DAY, Math.sin((i / 96) * 6.2832) * 4.3));
    const line = new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts), new THREE.LineBasicMaterial({ color: 0x8ea6ff, transparent: true, opacity: 0.16, depthWrite: false }));
    scene.add(line);
    const tag = document.createElement('div');
    tag.textContent = `${d} days`;
    tag.style.cssText = 'position:absolute;font:500 10px "JetBrains Mono",monospace;color:#8ea6ff;opacity:.72;white-space:nowrap';
    labels.appendChild(tag);
    return { d, tag };
  });

  // Background dust gives the space depth.
  const dustN = 420, dustP = new Float32Array(dustN * 3);
  for (let i = 0; i < dustN; i++) dustP.set([(Math.random() - 0.5) * 26, Math.random() * 14 - 1, (Math.random() - 0.5) * 26], i * 3);
  const dustG = new THREE.BufferGeometry();
  dustG.setAttribute('position', new THREE.BufferAttribute(dustP, 3));
  const dust = new THREE.Points(dustG, new THREE.PointsMaterial({ color: 0x8ea6ff, size: 0.03, transparent: true, opacity: 0.4, depthWrite: false }));
  scene.add(dust);

  // ---------- Stars ----------
  const starMat = new THREE.ShaderMaterial({
    transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    uniforms: { uT: { value: 0 }, uPx: { value: 1 } },
    vertexShader: `attribute float aSize; attribute vec3 aColor; attribute float aHot; attribute float aSeed;
      uniform float uT,uPx; varying vec3 vC; varying float vH;
      void main(){vC=aColor;vH=aHot;
        float pulse=1.+aHot*(.22*sin(uT*5.+aSeed*9.)+.12);
        vec4 mv=modelViewMatrix*vec4(position,1.);
        gl_PointSize=aSize*pulse*uPx*(8./-mv.z);
        gl_Position=projectionMatrix*mv;}`,
    fragmentShader: `varying vec3 vC;varying float vH;
      void main(){vec2 p=gl_PointCoord-.5;float d=length(p)*2.;
        float core=smoothstep(.28,.14,d);
        float halo=pow(max(1.-d,0.),2.3);
        float a=abs(p.x*p.y);float spike=exp(-a*220.)*pow(max(1.-d,0.),1.5)*.55;
        vec3 c=vC*(halo*.95+spike)+vec3(1.)*core*.85;
        gl_FragColor=vec4(c,clamp(core+halo*.8+spike,0.,1.));}`,
  });
  let stars = null, linkLines = null, traceLines = null, items = [], links = [], selected = null, horizon = 0, horizonT = 0;
  let positions = null;

  const layout = () => {
    // Group variants of a product into the same sector, spread sectors around a circle.
    const groups = new Map();
    items.forEach((it, i) => {
      const g = (it.group || it.name).toLowerCase();
      if (!groups.has(g)) groups.set(g, []);
      groups.get(g).push(i);
    });
    const keys = [...groups.keys()];
    keys.forEach((k, gi) => {
      const a = (gi / Math.max(keys.length, 1)) * 6.2832 + 0.5;
      const R = 1.4 + 2.5 * (0.5 + 0.5 * Math.sin(gi * 2.4));
      groups.get(k).forEach((i, vi) => {
        const off = (vi - (groups.get(k).length - 1) / 2) * 0.42;
        items[i]._x = Math.cos(a) * R + Math.cos(a + 1.57) * off;
        items[i]._z = Math.sin(a) * R + Math.sin(a + 1.57) * off;
      });
    });
  };

  const buildStars = () => {
    if (stars) { scene.remove(stars); stars.geometry.dispose(); }
    const n = items.length;
    const g = new THREE.BufferGeometry();
    positions = new Float32Array(n * 3);
    const sizes = new Float32Array(n), colors = new Float32Array(n * 3), hot = new Float32Array(n), seeds = new Float32Array(n);
    const maxV = Math.max(...items.map((i) => i.velocity || 0), 1);
    items.forEach((it, i) => {
      sizes[i] = 38 + 44 * Math.sqrt((it.velocity || 0) / maxV);
      seeds[i] = Math.random();
      it._y = Math.min(it.daysLeft ?? MAX_DAYS, MAX_DAYS) * HEIGHT_PER_DAY;
      positions.set([it._x, it._y, it._z], i * 3);
    });
    g.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    g.setAttribute('aSize', new THREE.BufferAttribute(sizes, 1));
    g.setAttribute('aColor', new THREE.BufferAttribute(colors, 3));
    g.setAttribute('aHot', new THREE.BufferAttribute(hot, 1));
    g.setAttribute('aSeed', new THREE.BufferAttribute(seeds, 1));
    stars = new THREE.Points(g, starMat);
    stars.frustumCulled = false;
    scene.add(stars);

    labels.querySelectorAll('.st').forEach((e) => e.remove());
    items.forEach((it) => {
      const l = document.createElement('div');
      l.className = 'st';
      l.textContent = it.name;
      l.style.cssText = 'position:absolute;white-space:nowrap;text-shadow:0 1px 6px #000,0 0 2px #000;will-change:transform';
      labels.appendChild(l);
      it._label = l;
    });

    if (linkLines) { scene.remove(linkLines); linkLines.geometry.dispose(); }
    linkLines = new THREE.LineSegments(new THREE.BufferGeometry(), new THREE.LineBasicMaterial({ color: 0x9fb4ff, transparent: true, opacity: 0.2, depthWrite: false, blending: THREE.AdditiveBlending }));
    linkLines.frustumCulled = false;
    scene.add(linkLines);
    if (traceLines) { scene.remove(traceLines); traceLines.geometry.dispose(); }
    traceLines = new THREE.LineSegments(new THREE.BufferGeometry(), new THREE.LineBasicMaterial({ color: 0xffcf5c, transparent: true, opacity: 0.95, depthWrite: false, blending: THREE.AdditiveBlending }));
    traceLines.frustumCulled = false;
    scene.add(traceLines);
  };

  const setData = (d) => {
    items = (d.items || []).map((x) => ({ ...x }));
    const idx = new Map(items.map((x, i) => [x.id, i]));
    links = (d.links || []).map(([a, b]) => [idx.get(a), idx.get(b)]).filter(([a, b]) => a !== undefined && b !== undefined);
    selected = null;
    layout();
    buildStars();
  };

  // Where each star is `horizon` days from now, using its own selling speed.
  const refresh = () => {
    if (!stars) return;
    const pos = stars.geometry.attributes.position, col = stars.geometry.attributes.aColor, hot = stars.geometry.attributes.aHot;
    const linked = new Set();
    if (selected !== null) for (const [a, b] of links) { if (a === selected) linked.add(b); if (b === selected) linked.add(a); }
    const c = new THREE.Color();
    items.forEach((it, i) => {
      const left = it.daysLeft == null ? null : Math.max(it.daysLeft - horizon, 0);
      const y = left == null ? MAX_DAYS * HEIGHT_PER_DAY * 0.72 : Math.min(left, MAX_DAYS) * HEIGHT_PER_DAY;
      pos.setY(i, y);
      c.copy(left == null ? new THREE.Color(0x8892b8) : urgency(left, it.warnDays ?? 2));
      if (selected !== null && i !== selected && !linked.has(i)) c.lerp(DIM, 0.82);
      col.setXYZ(i, c.r, c.g, c.b);
      hot.setX(i, left !== null && left <= (it.warnDays ?? 2) ? 1 : 0);
    });
    pos.needsUpdate = col.needsUpdate = hot.needsUpdate = true;
    const seg = [];
    for (const [a, b] of links) seg.push(pos.getX(a), pos.getY(a), pos.getZ(a), pos.getX(b), pos.getY(b), pos.getZ(b));
    linkLines.geometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(seg), 3));
    linkLines.material.opacity = selected === null ? 0.2 : 0.05;
    const tr = [];
    if (selected !== null) for (const [a, b] of links) if (a === selected || b === selected) tr.push(pos.getX(a), pos.getY(a), pos.getZ(a), pos.getX(b), pos.getY(b), pos.getZ(b));
    traceLines.geometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(tr), 3));
  };

  // ---------- Orbit (no extra library: a phone only needs drag and pinch) ----------
  const orbit = { yaw: 0.7, pitch: 0.2, dist: 12.5, yawV: 0, auto: true };
  const target = new THREE.Vector3(0, 3.2, 0);
  const pointers = new Map();
  let pinch = 0, moved = 0, downAt = null;
  const dom = renderer.domElement;
  const onDown = (e) => {
    pointers.set(e.pointerId, [e.clientX, e.clientY]);
    moved = 0; downAt = [e.clientX, e.clientY];
    orbit.auto = false;
    dom.setPointerCapture?.(e.pointerId);
  };
  const onMove = (e) => {
    const p = pointers.get(e.pointerId);
    if (!p) return;
    const dx = e.clientX - p[0], dy = e.clientY - p[1];
    p[0] = e.clientX; p[1] = e.clientY;
    if (pointers.size === 2) {
      const [a, b] = [...pointers.values()];
      const d = Math.hypot(a[0] - b[0], a[1] - b[1]);
      if (pinch) orbit.dist = THREE.MathUtils.clamp(orbit.dist * (pinch / d), 5, 22);
      pinch = d;
      return;
    }
    moved += Math.abs(dx) + Math.abs(dy);
    orbit.yaw -= dx * 0.006; orbit.yawV = -dx * 0.006;
    orbit.pitch = THREE.MathUtils.clamp(orbit.pitch + dy * 0.004, -0.15, 1.15);
  };
  const ray = new THREE.Raycaster();
  ray.params.Points.threshold = 0.42;
  const onUp = (e) => {
    pointers.delete(e.pointerId);
    pinch = 0;
    if (moved < 8 && downAt && stars) {
      const r = dom.getBoundingClientRect();
      ray.setFromCamera(new THREE.Vector2(((downAt[0] - r.left) / r.width) * 2 - 1, -((downAt[1] - r.top) / r.height) * 2 + 1), camera);
      const hit = ray.intersectObject(stars)[0];
      if (hit) {
        selected = hit.index;
        refresh();
        el.dispatchEvent(new CustomEvent('fx', { detail: JSON.stringify({ name: 'select', id: items[hit.index].id }) }));
      } else if (selected !== null) { selected = null; refresh(); el.dispatchEvent(new CustomEvent('fx', { detail: JSON.stringify({ name: 'clear' }) })); }
    }
    downAt = null;
  };
  const onWheel = (e) => { e.preventDefault(); orbit.dist = THREE.MathUtils.clamp(orbit.dist * (1 + e.deltaY * 0.001), 5, 22); };
  dom.addEventListener('pointerdown', onDown);
  dom.addEventListener('pointermove', onMove);
  dom.addEventListener('pointerup', onUp);
  dom.addEventListener('pointercancel', onUp);
  dom.addEventListener('wheel', onWheel, { passive: false });

  const resize = () => {
    const w = Math.max(el.clientWidth, 1), h = Math.max(el.clientHeight, 1);
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.fov = 46 * Math.max(1, 0.9 / camera.aspect);
    camera.updateProjectionMatrix();
    starMat.uniforms.uPx.value = Math.min(devicePixelRatio || 1, 1.75) * Math.min(h / 640, 1.2);
  };
  const ro = new ResizeObserver(resize); ro.observe(el); resize();

  let raf = 0, dead = false, last = performance.now(), t = 0;
  const v = new THREE.Vector3();
  const project = (node, x, y, z, dx = 10, dy = -7) => {
    v.set(x, y, z).project(camera);
    const w = el.clientWidth, h = el.clientHeight;
    const sx = (v.x * 0.5 + 0.5) * w, sy = (-v.y * 0.5 + 0.5) * h;
    node.style.transform = `translate(${sx + dx}px,${sy + dy}px)`;
    return v.z;
  };
  const loop = () => {
    if (dead) return;
    raf = requestAnimationFrame(loop);
    const now = performance.now(), dt = Math.min((now - last) / 1000, 0.05);
    last = now; t += dt;
    if (orbit.auto) orbit.yaw += dt * 0.09;
    else if (!pointers.size) { orbit.yaw += orbit.yawV; orbit.yawV *= 0.93; }
    camera.position.set(
      target.x + Math.sin(orbit.yaw) * Math.cos(orbit.pitch) * orbit.dist,
      target.y + Math.sin(orbit.pitch) * orbit.dist,
      target.z + Math.cos(orbit.yaw) * Math.cos(orbit.pitch) * orbit.dist,
    );
    camera.lookAt(target);
    starMat.uniforms.uT.value = t;
    floorMat.uniforms.uT.value = t;
    dust.rotation.y = t * 0.01;
    if (Math.abs(horizonT - horizon) > 0.004) { horizon += (horizonT - horizon) * 0.14; refresh(); }
    for (const h of horizons) project(h.tag, Math.sin(orbit.yaw + 1.4) * 4.3, h.d * HEIGHT_PER_DAY, Math.cos(orbit.yaw + 1.4) * 4.3, 4, -6);
    if (stars) {
      const pos = stars.geometry.attributes.position;
      items.forEach((it, i) => {
        const dist = camera.position.distanceTo(v.set(pos.getX(i), pos.getY(i), pos.getZ(i)));
        project(it._label, pos.getX(i), pos.getY(i), pos.getZ(i), 12, -8);
        const important = i === selected || it.important;
        it._label.style.opacity = selected !== null && i !== selected ? 0.3 : important ? 1 : THREE.MathUtils.clamp(1.6 - dist / 14, 0.28, 0.85);
      });
    }
    renderer.render(scene, camera);
  };
  if (cfg.items) setData(cfg);
  refresh();
  loop();
  el.dispatchEvent(new CustomEvent('fx', { detail: JSON.stringify({ name: 'ready' }) }));

  return {
    send(m) {
      if (m.items) { setData(m); refresh(); }
      if (m.horizon !== undefined) horizonT = m.horizon;
      if (m.select !== undefined) {
        const i = items.findIndex((x) => x.id === m.select);
        selected = i >= 0 ? i : null;
        refresh();
      }
    },
    dispose() {
      dead = true;
      cancelAnimationFrame(raf);
      ro.disconnect();
      dom.removeEventListener('wheel', onWheel);
      scene.traverse((o) => { o.geometry?.dispose?.(); o.material?.dispose?.(); });
      renderer.dispose();
      renderer.forceContextLoss?.();
      dom.remove();
      labels.remove();
    },
  };
}
