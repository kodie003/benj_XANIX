// Poddy, the benj mascot. 3D model "Poddy M1 - Stylized Floating Robot" by Exmoor beast
// (https://sketchfab.com/Exmoorbeast), CC BY 4.0. Converted from FBX to glTF, textures
// resized, and its six held poses kept as clips; no geometry was redrawn.
//
// The app only sends a mood name. Each mood is one of the model's poses plus a little
// procedural life: floating, blinking, looking at your finger, and a wave when tapped.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { clone as cloneSkinned } from 'three/addons/utils/SkeletonUtils.js';

const MOODS = {
  idle: { pose: 'rest', bob: 1 },
  hello: { pose: 'hello', bob: 1.2 },
  present: { pose: 'present', bob: 0.8 },
  welcome: { pose: 'welcome', bob: 1.6 },
  shock: { pose: 'shock', bob: 0.4, shake: 1 },
  sad: { pose: 'sad', bob: 0.35 },
  sleep: { pose: 'sad', bob: 0.2, eyes: 0.12 },
};

let gltfPromise = null;
const loadModel = () => (gltfPromise ??= new GLTFLoader().loadAsync(new URL('./poddy.glb', import.meta.url).href));

export function supported() {
  try {
    const c = document.createElement('canvas');
    return !!(c.getContext('webgl2') || c.getContext('webgl'));
  } catch (_) {
    return false;
  }
}

export function mount(el, mood = 'idle') {
  const still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: 'low-power' });
  renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.domElement.style.cssText = 'width:100%;height:100%;display:block;touch-action:pan-y';
  el.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  scene.add(new THREE.HemisphereLight(0xffffff, 0x9aa7c7, 2.2));
  const key = new THREE.DirectionalLight(0xffffff, 2.4);
  key.position.set(3, 5, 6);
  scene.add(key);
  const rim = new THREE.DirectionalLight(0xb8ffcf, 1.2);
  rim.position.set(-4, 2, -3);
  scene.add(rim);
  const cam = new THREE.PerspectiveCamera(28, 1, 0.1, 500);

  const state = { mood: MOODS[mood] ? mood : 'idle', until: 0, after: null, look: new THREE.Vector2(), blink: 0, nextBlink: 2, dead: false };
  let rig = null;

  const resize = () => {
    const w = el.clientWidth || 1, h = el.clientHeight || 1;
    renderer.setSize(w, h, false);
    cam.aspect = w / h;
    cam.updateProjectionMatrix();
  };
  const ro = new ResizeObserver(resize);
  ro.observe(el);
  resize();

  loadModel().then((gltf) => {
    if (state.dead) return;
    // Each screen gets its own copy; the downloaded file is shared.
    const root = cloneSkinned(gltf.scene);
    // Fit him into the box whatever the units.
    const box = new THREE.Box3().setFromObject(root);
    const size = box.getSize(new THREE.Vector3());
    const s = 1 / size.y;
    root.scale.setScalar(s);
    root.position.set(-box.getCenter(new THREE.Vector3()).x * s, -box.min.y * s, -box.getCenter(new THREE.Vector3()).z * s);
    const holder = new THREE.Group();
    holder.add(root);
    scene.add(holder);
    cam.position.set(0, 0.55, 3.4);
    cam.lookAt(0, 0.5, 0);

    const mixer = new THREE.AnimationMixer(root);
    const actions = {};
    for (const clip of gltf.animations) {
      const a = mixer.clipAction(clip);
      a.setLoop(THREE.LoopRepeat);
      a.enabled = true;
      a.setEffectiveWeight(0);
      a.play();
      actions[clip.name] = a;
    }
    const bones = {};
    root.traverse((o) => { if (o.isBone && !bones[o.name]) bones[o.name] = o; });
    // The model's screen is see-through glass with the eyes behind it.
    root.traverse((o) => {
      if (!o.isMesh) return;
      o.frustumCulled = false;
      if (o.material && o.material.name === 'screen') { o.material.transparent = true; o.material.depthWrite = false; o.renderOrder = 2; }
    });
    rig = { root, holder, mixer, actions, bones, weights: Object.fromEntries(Object.keys(actions).map((k) => [k, 0])) };
  });

  // Eyes follow a finger or the mouse; a tap makes him wave.
  const onMove = (e) => {
    const r = el.getBoundingClientRect();
    state.look.set(((e.clientX - r.left) / r.width) * 2 - 1, ((e.clientY - r.top) / r.height) * 2 - 1);
    state.look.clampScalar(-1.5, 1.5);
  };
  const onTap = () => {
    if (state.mood === 'sleep' || state.mood === 'shock') { set('hello', 1600); return; }
    set('hello', 1600);
  };
  window.addEventListener('pointermove', onMove, { passive: true });
  el.addEventListener('pointerdown', onTap);

  function set(next, ms) {
    if (!MOODS[next]) return;
    if (ms) {
      state.after = state.after && state.until > performance.now() ? state.after : state.mood;
      state.until = performance.now() + ms;
    } else {
      state.after = null;
      state.until = 0;
    }
    state.mood = next;
  }

  const clock = new THREE.Clock();
  let t = 0;
  const tick = () => {
    if (state.dead) return;
    raf = requestAnimationFrame(tick);
    if (document.hidden) return;
    const dt = Math.min(clock.getDelta(), 0.05);
    t += dt;
    if (state.after && performance.now() > state.until) { state.mood = state.after; state.after = null; }
    const m = MOODS[state.mood];
    if (rig) {
      // Cross-fade the held poses.
      const k = 1 - Math.exp(-dt * 7);
      for (const [name, a] of Object.entries(rig.actions)) {
        const target = name === m.pose ? 1 : 0;
        rig.weights[name] += (target - rig.weights[name]) * k;
        a.setEffectiveWeight(rig.weights[name]);
      }
      rig.mixer.update(dt);

      const motion = still ? 0 : 1;
      // Float on his spring, with a nervous shake when something is running out.
      rig.holder.position.y = Math.sin(t * 2.1) * 0.035 * m.bob * motion;
      rig.holder.rotation.z = Math.sin(t * 1.3) * 0.03 * m.bob * motion + (m.shake ? Math.sin(t * 38) * 0.012 * motion : 0);
      // Turn towards the finger.
      const yaw = state.look.x * 0.35, pitch = state.look.y * 0.12;
      rig.holder.rotation.y += (yaw - rig.holder.rotation.y) * k * 0.6;
      rig.holder.rotation.x += (pitch - rig.holder.rotation.x) * k * 0.6;
      // Blink every few seconds; sleepy eyes stay nearly shut.
      state.nextBlink -= dt;
      if (state.nextBlink <= 0) { state.blink = 0.16; state.nextBlink = 2.5 + Math.random() * 3.5; }
      state.blink = Math.max(0, state.blink - dt);
      const open = m.eyes ?? (state.blink > 0 ? 0.1 : 1);
      for (const n of ['eye_l_01', 'eye_r_01']) {
        const b = rig.bones[n];
        if (b) b.scale.y += (open - b.scale.y) * Math.min(1, dt * 30);
      }
      // Antennae sway.
      for (const [n, ph] of [['antenna_l_01', 0], ['antenna_r_01', 1.7]]) {
        const b = rig.bones[n];
        if (b) b.rotation.x += Math.sin(t * 3 + ph) * 0.004 * motion;
      }
    }
    renderer.render(scene, cam);
  };
  let raf = requestAnimationFrame(tick);

  return {
    set: (mood, ms) => set(mood, ms),
    dispose() {
      state.dead = true;
      cancelAnimationFrame(raf);
      ro.disconnect();
      window.removeEventListener('pointermove', onMove);
      el.removeEventListener('pointerdown', onTap);
      renderer.dispose();
      renderer.domElement.remove();
    },
  };
}

// The Flutter side talks to this.
const handles = new WeakMap();
window.Poddy = {
  supported,
  mount(el, mood) { if (!handles.has(el)) handles.set(el, mount(el, mood)); },
  set(el, mood, ms) { handles.get(el)?.set(mood, ms); },
  dispose(el) { handles.get(el)?.dispose(); handles.delete(el); },
};
