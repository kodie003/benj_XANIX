// Benj the mascot: modelled and rigged entirely in code with three.js.
// A chunky street-runner kid: backwards marigold cap with a kente band, ink hoodie,
// big sneakers, and the red-edged stock book from the shops we interviewed.
// Every state is a pose function; the rig blends between them, so moods never pop.
import * as THREE from './three.module.min.js';

const C = {
  skin: 0x8f5733, skinDark: 0x70412a, hair: 0x15100d, cap: 0xffb627, capDark: 0xd98a0b,
  hoodie: 0x2747d8, hoodieLight: 0x3c62f2, teal: 0x2ee6c5, pants: 0x4b5068, sole: 0xf6f3ea,
  shoe: 0xff5a4f, lace: 0xffffff, white: 0xffffff, iris: 0x2b160a, tongue: 0xe2636b, book: 0xf4eedd, bookEdge: 0xd8262f,
};

const DEG = Math.PI / 180;
const damp = (a, b, k, dt) => a + (b - a) * (1 - Math.exp(-k * dt));

// Rounded box / egg shapes: a sphere pushed toward a superellipsoid.
function blob(rx, ry, rz, p = 0.7, seg = 28) {
  const g = new THREE.SphereGeometry(1, seg, Math.round(seg * 0.75));
  const a = g.attributes.position;
  for (let i = 0; i < a.count; i++) {
    const f = (v) => Math.sign(v) * Math.pow(Math.abs(v), p);
    a.setXYZ(i, f(a.getX(i)) * rx, f(a.getY(i)) * ry, f(a.getZ(i)) * rz);
  }
  g.computeVertexNormals();
  return g;
}
const mesh = (geo, mat, parent, x = 0, y = 0, z = 0) => {
  const m = new THREE.Mesh(geo, mat);
  m.position.set(x, y, z);
  if (parent) parent.add(m);
  return m;
};
const group = (parent, x = 0, y = 0, z = 0) => {
  const g = new THREE.Group();
  g.position.set(x, y, z);
  parent.add(g);
  return g;
};

// Soft fresnel rim so the character reads against the dark UI.
function rimMat(color, { rough = 0.62, metal = 0, rim = 0.5, rimColor = 0x9fb4ff, map = null } = {}) {
  const m = new THREE.MeshStandardMaterial({ color, roughness: rough, metalness: metal, map });
  m.onBeforeCompile = (s) => {
    s.uniforms.uRimC = { value: new THREE.Color(rimColor) };
    s.uniforms.uRimS = { value: rim };
    s.fragmentShader = s.fragmentShader
      .replace('#include <common>', '#include <common>\nuniform vec3 uRimC; uniform float uRimS;')
      .replace('#include <emissivemap_fragment>', `#include <emissivemap_fragment>
        float rimF = pow(1.0 - saturate(dot(normalize(vViewPosition), normal)), 2.6);
        totalEmissiveRadiance += uRimC * rimF * uRimS;`);
  };
  return m;
}

// Kente band: woven blocks of gold, green, red and black drawn to a canvas.
function kenteTexture() {
  const c = document.createElement('canvas');
  c.width = 256; c.height = 32;
  const g = c.getContext('2d');
  const cols = ['#111111', '#ffc21a', '#0f8a4b', '#d8262f', '#ffc21a', '#111111', '#0f8a4b', '#ffc21a'];
  for (let x = 0; x < 16; x++) {
    for (let y = 0; y < 2; y++) {
      g.fillStyle = cols[(x * 3 + y * 5) % cols.length];
      g.fillRect(x * 16, y * 16, 16, 16);
      g.fillStyle = 'rgba(255,255,255,.22)';
      if ((x + y) % 2) for (let k = 0; k < 4; k++) g.fillRect(x * 16, y * 16 + k * 4, 16, 1);
    }
  }
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.wrapS = THREE.RepeatWrapping;
  t.repeat.set(2, 1);
  return t;
}

// The "b" on the hoodie chest.
function badgeTexture() {
  const c = document.createElement('canvas');
  c.width = c.height = 128;
  const g = c.getContext('2d');
  g.fillStyle = '#ffb627';
  g.beginPath(); g.arc(64, 64, 62, 0, 7); g.fill();
  g.fillStyle = '#141a3c';
  g.font = '800 104px system-ui, sans-serif';
  g.textAlign = 'center'; g.textBaseline = 'middle';
  g.fillText('b', 64, 58);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

function curveTube(points, r, mat, parent) {
  const curve = new THREE.CatmullRomCurve3(points.map((p) => new THREE.Vector3(...p)));
  return mesh(new THREE.TubeGeometry(curve, 24, r, 10, false), mat, parent);
}

function buildCharacter() {
  const M = {
    skin: rimMat(C.skin, { rough: 0.48, rim: 0.32, rimColor: 0xffc28a }),
    skinD: rimMat(C.skinDark, { rough: 0.55, rim: 0.1 }),
    hair: rimMat(C.hair, { rough: 0.85, rim: 0.12 }),
    cap: rimMat(C.cap, { rough: 0.42, rim: 0.3, rimColor: 0xfff0c0 }),
    capD: rimMat(C.capDark, { rough: 0.5, rim: 0.1 }),
    hoodie: rimMat(C.hoodie, { rough: 0.72, rim: 0.45, rimColor: 0x9fc0ff }),
    hoodieL: rimMat(C.hoodieLight, { rough: 0.72, rim: 0.5 }),
    teal: rimMat(C.teal, { rough: 0.4, rim: 0.25 }),
    pants: rimMat(C.pants, { rough: 0.8, rim: 0.35, rimColor: 0xb7b4e8 }),
    sole: rimMat(C.sole, { rough: 0.5, rim: 0.1 }),
    shoe: rimMat(C.shoe, { rough: 0.38, rim: 0.3, rimColor: 0xffd0c0 }),
    white: new THREE.MeshStandardMaterial({ color: C.white, roughness: 0.2 }),
    iris: new THREE.MeshStandardMaterial({ color: C.iris, roughness: 0.15 }),
    gold: new THREE.MeshStandardMaterial({ color: 0xc27a1a, roughness: 0.25 }),
    dark: new THREE.MeshStandardMaterial({ color: 0x3a0f14, roughness: 0.6 }),
    tongue: new THREE.MeshStandardMaterial({ color: C.tongue, roughness: 0.5 }),
    shine: new THREE.MeshBasicMaterial({ color: 0xffffff }),
    book: rimMat(C.book, { rough: 0.9, rim: 0.05 }),
    bookE: rimMat(C.bookEdge, { rough: 0.7, rim: 0.1 }),
    badge: new THREE.MeshStandardMaterial({ map: badgeTexture(), roughness: 0.5 }),
    kente: new THREE.MeshStandardMaterial({ map: kenteTexture(), roughness: 0.6 }),
  };

  const R = {}; // the rig
  const root = new THREE.Group();
  R.root = root;
  R.hips = group(root, 0, 0.98, 0);
  R.spine = group(R.hips, 0, 0.1, 0);

  // Torso: a slightly pear-shaped hoodie.
  const torsoG = blob(0.47, 0.52, 0.36, 0.8, 32);
  { // Broad at the shoulders, narrow at the waist.
    const a = torsoG.attributes.position;
    for (let i = 0; i < a.count; i++) {
      const k = 0.8 + 0.2 * THREE.MathUtils.smoothstep(a.getY(i), -0.5, 0.25);
      a.setX(i, a.getX(i) * k); a.setZ(i, a.getZ(i) * (0.88 + 0.12 * k));
    }
    torsoG.computeVertexNormals();
  }
  mesh(torsoG, M.hoodie, R.spine, 0, 0.36, 0);
  mesh(blob(0.28, 0.12, 0.05, 0.6), M.hoodieL, R.spine, 0, 0.13, 0.3); // kangaroo pocket
  const badge = mesh(new THREE.CircleGeometry(0.095, 28), M.badge, R.spine, 0.2, 0.53, 0.356);
  badge.rotation.set(-10 * DEG, 24 * DEG, 0);
  // Hem and hood.
  mesh(new THREE.TorusGeometry(0.325, 0.05, 12, 32).rotateX(Math.PI / 2).scale(1, 1, 0.76), M.hoodieL, R.spine, 0, -0.1, 0);
  const hood = mesh(new THREE.TorusGeometry(0.24, 0.1, 14, 28).rotateX(Math.PI / 2 - 0.35), M.hoodieL, R.spine, 0, 0.82, -0.05);
  hood.scale.set(1.06, 1, 1.05);
  curveTube([[-0.1, 0.78, 0.28], [-0.11, 0.62, 0.362], [-0.09, 0.46, 0.378]], 0.013, M.teal, R.spine);
  curveTube([[0.07, 0.78, 0.28], [0.08, 0.64, 0.362], [0.06, 0.51, 0.378]], 0.013, M.teal, R.spine);
  mesh(new THREE.SphereGeometry(0.024, 10, 8), M.teal, R.spine, -0.09, 0.45, 0.38);
  mesh(new THREE.SphereGeometry(0.024, 10, 8), M.teal, R.spine, 0.06, 0.5, 0.38);

  // Neck + head. The head is deliberately big: that is where the personality lives.
  R.neck = group(R.spine, 0, 0.84, 0.01);
  mesh(new THREE.CylinderGeometry(0.11, 0.13, 0.16, 16), M.skinD, R.neck, 0, 0.03, 0);
  R.head = group(R.neck, 0, 0.12, 0.01);
  R.head.scale.setScalar(1.08);
  const skullG = blob(0.52, 0.52, 0.48, 0.95, 48);
  { // Taper the lower face into a soft jaw, keep full cheeks.
    const a = skullG.attributes.position;
    for (let i = 0; i < a.count; i++) {
      const y = a.getY(i) / 0.52;
      const low = THREE.MathUtils.smoothstep(-y, 0.1, 1.0);
      a.setX(i, a.getX(i) * (1 - low * 0.2));
      a.setZ(i, a.getZ(i) * (1 - low * 0.08));
    }
    skullG.computeVertexNormals();
  }
  const skull = mesh(skullG, M.skin, R.head, 0, 0.36, 0);
  skull.name = 'skull';
  for (const s of [-1, 1]) {
    const ear = mesh(blob(0.085, 0.115, 0.05, 0.9, 14), M.skin, R.head, s * 0.5, 0.36, -0.01);
    ear.rotation.y = s * 0.45;
    mesh(blob(0.045, 0.07, 0.02, 0.9, 10), M.skinD, ear, s * 0.012, 0, 0.03);
  }
  mesh(blob(0.062, 0.05, 0.06, 0.95, 16), M.skinD, R.head, 0, 0.3, 0.475); // nose

  // Hair: tight fade showing under the cap.
  // Hair shares the skull's superellipse so the hairline is one clean curve.
  const hairG = new THREE.SphereGeometry(1, 48, 24, 0, Math.PI * 2, 0, 1.36);
  hairG.rotateX(-0.5);
  {
    const a = hairG.attributes.position;
    const f = (v) => Math.sign(v) * Math.pow(Math.abs(v), 0.95);
    for (let i = 0; i < a.count; i++) a.setXYZ(i, f(a.getX(i)) * 0.531, f(a.getY(i)) * 0.531, f(a.getZ(i)) * 0.491);
    hairG.computeVertexNormals();
  }
  mesh(hairG, M.hair, R.head, 0, 0.36, 0);

  // Backwards cap: crown + brim behind + adjuster strap + kente band.
  R.cap = group(R.head, 0, 0.665, -0.035);
  R.cap.rotation.x = -0.26;
  const crown = new THREE.SphereGeometry(0.52, 40, 20, 0, Math.PI * 2, 0, Math.PI * 0.5);
  mesh(crown, M.cap, R.cap, 0, 0.03, 0).scale.set(1.0, 0.72, 0.97);
  const bandM = mesh(new THREE.CylinderGeometry(0.521, 0.525, 0.085, 44, 1, true), M.kente, R.cap, 0, 0.03, 0);
  bandM.scale.z = 0.97;
  bandM.material.side = THREE.DoubleSide;
  mesh(new THREE.SphereGeometry(0.04, 12, 10), M.capD, R.cap, 0, 0.405, 0); // button
  const brim = mesh(blob(0.33, 0.028, 0.25, 0.6, 24), M.capD, R.cap, 0, -0.01, -0.65);
  brim.rotation.x = 0.12;
  // Worn backwards: the snap-back opening faces forward.
  const arch = mesh(new THREE.TorusGeometry(0.085, 0.018, 10, 22, Math.PI), M.capD, R.cap, 0, 0.065, 0.502);
  arch.rotation.x = -0.1;
  mesh(new THREE.CapsuleGeometry(0.017, 0.17, 6, 10).rotateZ(Math.PI / 2), M.capD, R.cap, 0, 0.065, 0.505);

  // Eyes: big, glossy, gold-ringed. Lids are separate so blinks stay in the rig.
  R.eyes = [];
  const lidG = new THREE.SphereGeometry(1, 24, 12, 0, Math.PI * 2, 0, Math.PI * 0.5);
  for (const s of [-1, 1]) {
    const e = group(R.head, s * 0.19, 0.38, 0.41);
    e.rotation.y = s * 0.2;
    mesh(blob(0.118, 0.142, 0.06, 0.92, 26), M.white, e, 0, 0, 0);
    const look = group(e, 0, 0, 0.04);
    mesh(new THREE.SphereGeometry(0.098, 24, 18).scale(1, 1.12, 0.3), M.gold, look, 0, 0, 0);
    mesh(new THREE.SphereGeometry(0.076, 24, 18).scale(1, 1.12, 0.36), M.iris, look, 0, 0, 0.005);
    mesh(new THREE.SphereGeometry(0.03, 12, 10), M.shine, look, 0.033, 0.05, 0.034);
    mesh(new THREE.SphereGeometry(0.014, 8, 6), M.shine, look, -0.034, -0.034, 0.034);
    const lidTop = group(e, 0, 0, 0);
    mesh(lidG, M.skin, lidTop).scale.set(0.128, 0.152, 0.082);
    const lidBot = group(e, 0, 0, 0);
    const lb = mesh(lidG, M.skin, lidBot);
    lb.scale.set(0.128, 0.152, 0.082);
    lb.rotation.x = Math.PI;
    const brow = group(R.head, s * 0.19, 0.58, 0.455);
    mesh(blob(0.098, 0.021, 0.028, 0.55, 12), M.hair, brow);
    brow.rotation.y = s * 0.26;
    R.eyes.push({ side: s, look, lidTop, lidBot, brow });
  }

  // Mouths: swapped by mood, blended by scale so changes feel like squash and stretch.
  R.mouths = {};
  const mouth = group(R.head, 0, 0.165, 0.445);
  R.mouthRoot = mouth;
  const arc = (bend, w = 0.13) => curveTube([[-w, bend * 0.5, 0], [-w * 0.45, -bend * 0.25, 0.022], [0, -bend * 0.5, 0.03], [w * 0.45, -bend * 0.25, 0.022], [w, bend * 0.5, 0]], 0.0165, M.dark, mouth);
  R.mouths.smile = arc(0.085);
  R.mouths.worry = arc(-0.055, 0.09);
  const grin = group(mouth);
  mesh(blob(0.135, 0.085, 0.035, 0.85, 20), M.dark, grin);
  mesh(blob(0.09, 0.03, 0.02, 0.8, 12), M.white, grin, 0, 0.043, 0.024);
  mesh(blob(0.07, 0.04, 0.03, 0.95, 12), M.tongue, grin, 0, -0.038, 0.016);
  R.mouths.grin = grin;
  const oh = group(mouth);
  mesh(blob(0.058, 0.078, 0.03, 0.95, 16), M.dark, oh);
  mesh(blob(0.036, 0.024, 0.02, 0.95, 10), M.tongue, oh, 0, -0.04, 0.012);
  R.mouths.oh = oh;

  // Arms: shoulder -> elbow -> hand.
  R.arms = [];
  for (const s of [-1, 1]) {
    const shoulder = group(R.spine, s * 0.43, 0.66, 0);
    const upper = mesh(new THREE.CapsuleGeometry(0.125, 0.27, 8, 18), M.hoodie, shoulder, 0, -0.17, 0);
    upper.name = 'upper';
    const elbow = group(shoulder, 0, -0.38, 0);
    mesh(new THREE.CapsuleGeometry(0.112, 0.2, 8, 18), M.hoodie, elbow, 0, -0.13, 0);
    mesh(new THREE.TorusGeometry(0.097, 0.03, 10, 22).rotateX(Math.PI / 2), M.hoodieL, elbow, 0, -0.29, 0);
    const hand = group(elbow, 0, -0.34, 0);
    hand.scale.setScalar(1.22);
    mesh(blob(0.098, 0.105, 0.085, 0.9, 16), M.skin, hand, 0, -0.03, 0);
    const thumb = mesh(new THREE.CapsuleGeometry(0.031, 0.06, 6, 10), M.skin, hand, -s * 0.085, 0.0, 0.05);
    thumb.rotation.z = s * 0.75;
    for (let f = 0; f < 3; f++) {
      const fg = mesh(new THREE.CapsuleGeometry(0.026, 0.055, 6, 8), M.skin, hand, -0.055 + f * 0.055, -0.11, 0.03);
      fg.name = 'finger';
    }
    R.arms.push({ side: s, shoulder, elbow, hand });
  }

  // The stock book lives in the left hand and only appears when logging.
  R.book = group(R.spine, -0.02, 0.42, 0.58);
  R.book.rotation.x = -0.42;
  mesh(new THREE.BoxGeometry(0.62, 0.46, 0.06), M.bookE, R.book);
  mesh(new THREE.BoxGeometry(0.58, 0.42, 0.03), M.book, R.book, 0, 0, 0.036);
  for (let l = 0; l < 4; l++) mesh(new THREE.BoxGeometry(0.46, 0.012, 0.006), M.dark, R.book, 0, 0.13 - l * 0.085, 0.054);
  R.book.visible = false;

  // Legs + chunky sneakers: oversized feet give the mobile-game silhouette.
  R.legs = [];
  for (const s of [-1, 1]) {
    const thigh = group(R.hips, s * 0.185, -0.04, 0);
    mesh(new THREE.CapsuleGeometry(0.17, 0.2, 8, 18), M.pants, thigh, 0, -0.16, 0);
    const knee = group(thigh, 0, -0.34, 0);
    mesh(new THREE.CapsuleGeometry(0.15, 0.16, 8, 18), M.pants, knee, 0, -0.12, 0);
    const ankle = group(knee, 0, -0.3, 0);
    mesh(new THREE.TorusGeometry(0.125, 0.034, 10, 24).rotateX(Math.PI / 2), M.teal, ankle, 0, 0.02, 0);
    const shoe = group(ankle, 0, -0.1, 0.09);
    shoe.scale.setScalar(1.22);
    mesh(blob(0.17, 0.11, 0.28, 0.72, 22), M.shoe, shoe, 0, 0.0, 0);
    mesh(blob(0.185, 0.055, 0.305, 0.5, 22), M.sole, shoe, 0, -0.085, 0.005);
    mesh(blob(0.12, 0.03, 0.08, 0.7, 12), M.sole, shoe, 0, 0.0, 0.2).rotation.x = 0.35;
    for (let l = 0; l < 3; l++) {
      const lace = mesh(new THREE.CapsuleGeometry(0.012, 0.11, 4, 8), M.white, shoe, 0, 0.1 - l * 0.004 + (l - 1) * 0.012, 0.11 - l * 0.06);
      lace.rotation.z = Math.PI / 2;
    }
    R.legs.push({ side: s, thigh, knee, ankle });
  }

  root.traverse((o) => { if (o.isMesh) { o.castShadow = true; } });
  return R;
}

// ---------------- Poses: each returns the targets the rig should move toward. ----------------
const BASE = () => ({
  hipY: 0, hipRot: 0, spineX: 0, spineZ: 0, headX: 0, headY: 0, headZ: 0,
  armL: [12, 0, 10], armR: [12, 0, 10], elbowL: 12, elbowR: 12,
  legL: 0, legR: 0, kneeL: 0, kneeR: 0, browA: 0, browY: 0, lid: 0, mouth: 'smile', book: false,
  gaze: true,
});
const poses = {
  idle(t) {
    const p = BASE();
    p.spineX = Math.sin(t * 1.6) * 0.012;
    p.hipY = Math.sin(t * 1.6) * 0.012;
    p.headZ = Math.sin(t * 0.6) * 0.03;
    p.armL[2] = 11 + Math.sin(t * 1.6) * 1.5;
    p.armR[2] = 11 + Math.sin(t * 1.6) * 1.5;
    return p;
  },
  wave(t) {
    const p = poses.idle(t);
    p.armR = [-22, 0, 150 + Math.sin(t * 11) * 17];
    p.elbowR = 28 + Math.sin(t * 11 + 1) * 13;
    p.headZ = -0.08; p.spineZ = 0.03; p.mouth = 'grin'; p.browY = 0.012;
    return p;
  },
  celebrate(t) {
    const p = BASE();
    const j = Math.abs(Math.sin(t * 6.2));
    p.hipY = j * 0.42;
    p.kneeL = p.kneeR = (1 - j) * 30 + 10;
    p.legL = p.legR = -(1 - j) * 15 - 5;
    p.armL = [-16, 0, 145 + j * 20];
    p.armR = [-16, 0, 145 + j * 20];
    p.elbowL = p.elbowR = 12;
    p.spineX = -0.08; p.headX = -0.08;
    p.mouth = 'grin'; p.browY = 0.02; p.gaze = false;
    return p;
  },
  worried(t) {
    const p = BASE();
    p.spineX = 0.08;
    p.headX = 0.06 + Math.sin(t * 2.2) * 0.012;
    p.headY = Math.sin(t * 2.6) * 0.14;
    p.armL = [-55, 0, 22]; p.armR = [-55, 0, 22];
    p.elbowL = 105; p.elbowR = 105;
    p.browA = 0.42; p.browY = 0.012; p.mouth = 'worry'; p.lid = 0.06;
    return p;
  },
  think(t) {
    const p = poses.idle(t);
    p.armR = [-70, 0, 12]; p.elbowR = 125;
    p.headX = -0.1; p.headZ = 0.12; p.headY = 0.16;
    p.browA = -0.12; p.mouth = 'oh'; p.gaze = false; p.lookX = 0.5; p.lookY = 0.6;
    return p;
  },
  listen(t) {
    const p = poses.idle(t);
    p.armR = [-40, 0, 62]; p.elbowR = 118;
    p.headZ = -0.17; p.headY = 0.12;
    p.browY = 0.016; p.mouth = 'smile';
    return p;
  },
  talk(t) {
    const p = poses.idle(t);
    p.armR = [-30 + Math.sin(t * 3) * 10, 0, 34 + Math.sin(t * 2) * 8]; p.elbowR = 60;
    p.headX = Math.sin(t * 5) * 0.022;
    p.mouth = Math.sin(t * 15) + Math.sin(t * 7.3) > 0.1 ? 'oh' : 'grin';
    return p;
  },
  log(t) {
    const p = poses.idle(t);
    p.book = true;
    p.armL = [-20, 0, 8]; p.elbowL = 74;
    p.armR = [-22, 0, 4]; p.elbowR = 88 + Math.sin(t * 9) * 5;
    p.headX = 0.2; p.lookY = -0.7; p.lookX = -0.1; p.gaze = false;
    return p;
  },
  point(t) {
    const p = poses.idle(t);
    p.armR = [-85, 0, 26]; p.elbowR = 8;
    p.spineZ = 0.04; p.mouth = 'grin';
    p.browY = 0.012;
    return p;
  },
  run(t) {
    const p = BASE();
    const w = t * 13;
    p.spineX = 0.22;
    p.hipY = Math.abs(Math.sin(w)) * 0.1;
    p.hipRot = Math.sin(w) * 0.13;
    p.legL = Math.sin(w) * 58; p.legR = -Math.sin(w) * 58;
    p.kneeL = 45 + Math.max(0, -Math.cos(w)) * 70;
    p.kneeR = 45 + Math.max(0, Math.cos(w)) * 70;
    p.armL = [-Math.sin(w) * 60 - 10, 0, 10];
    p.armR = [Math.sin(w) * 60 - 10, 0, 10];
    p.elbowL = p.elbowR = 90;
    p.headX = -0.14; p.mouth = 'grin'; p.browY = 0.01; p.gaze = false;
    return p;
  },
  sleep(t) {
    const p = BASE();
    p.spineX = 0.12 + Math.sin(t * 1.1) * 0.012;
    p.headX = 0.34; p.headZ = 0.12;
    p.armL[2] = 6; p.armR[2] = 6;
    p.lid = 1; p.mouth = 'oh'; p.gaze = false;
    return p;
  },
};
const STATES = Object.keys(poses);

function neutralEnv(renderer) {
  const s = new THREE.Scene();
  s.background = new THREE.Color(0x12162c);
  const add = (c, x, y, z, sc) => {
    const m = new THREE.Mesh(new THREE.SphereGeometry(1, 12, 8), new THREE.MeshBasicMaterial({ color: c }));
    m.position.set(x, y, z); m.scale.setScalar(sc); s.add(m);
  };
  add(0xfff1d6, 5, 8, 6, 3.2);
  add(0x7a95ff, -8, 3, -2, 3);
  add(0xffb627, 3, -6, 5, 2.4);
  add(0x2ee6c5, -5, -4, 6, 2);
  const pm = new THREE.PMREMGenerator(renderer);
  const t = pm.fromScene(s, 0.05).texture;
  pm.dispose();
  return t;
}

export function mount(el, cfg = {}) {
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: !!cfg.capture });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, cfg.maxDpr || 1.75));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.12;
  renderer.domElement.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;display:block;touch-action:none';
  el.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  scene.environment = neutralEnv(renderer);
  scene.environmentIntensity = 0.62;
  const key = new THREE.DirectionalLight(0xfff0dc, 2.5); key.position.set(2.5, 5, 5); scene.add(key);
  const fill = new THREE.DirectionalLight(0x8ea6ff, 1.0); fill.position.set(-4, 1, 3); scene.add(fill);
  const back = new THREE.DirectionalLight(0xffb627, 1.6); back.position.set(0, 3, -5); scene.add(back);

  const R = buildCharacter();
  scene.add(R.root);

  // Ground glow so he stands on something in any layout.
  const shadowT = (() => {
    const c = document.createElement('canvas'); c.width = c.height = 128;
    const g = c.getContext('2d');
    const r = g.createRadialGradient(64, 64, 2, 64, 64, 64);
    r.addColorStop(0, 'rgba(0,0,0,.6)'); r.addColorStop(0.6, 'rgba(0,0,0,.22)'); r.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = r; g.fillRect(0, 0, 128, 128);
    return new THREE.CanvasTexture(c);
  })();
  const shadow = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), new THREE.MeshBasicMaterial({ map: shadowT, transparent: true, depthWrite: false }));
  shadow.rotation.x = -Math.PI / 2; shadow.position.y = 0.012;
  scene.add(shadow);

  // Sparkle burst for celebrations.
  const burstN = 42;
  const burstG = new THREE.BufferGeometry();
  burstG.setAttribute('position', new THREE.BufferAttribute(new Float32Array(burstN * 3), 3));
  const burstM = new THREE.PointsMaterial({ size: 0.11, color: 0xffcf5c, transparent: true, opacity: 0, depthWrite: false, blending: THREE.AdditiveBlending, map: starTexture() });
  const burst = new THREE.Points(burstG, burstM);
  scene.add(burst);
  const burstV = Array.from({ length: burstN }, () => new THREE.Vector3());
  let burstLife = 0;
  const fireBurst = () => {
    const a = burstG.attributes.position;
    for (let i = 0; i < burstN; i++) {
      a.setXYZ(i, 0, 1.9, 0.2);
      const th = Math.random() * 6.283, y = Math.random() * 1.4 + 0.4, sp = 1.0 + Math.random() * 1.8;
      burstV[i].set(Math.cos(th) * sp, y * sp, Math.sin(th) * sp * 0.5);
    }
    burstLife = 1;
  };

  const framing = cfg.framing || 'full'; // full | bust
  const camera = new THREE.PerspectiveCamera(framing === 'bust' ? 24 : 26, 1, 0.1, 50);
  const camY = framing === 'bust' ? 2.45 : 1.5;
  camera.position.set(0, camY, framing === 'bust' ? 4.6 : 7.4);
  camera.lookAt(0, framing === 'bust' ? 2.42 : 1.5, 0);

  let W = 1, H = 1;
  const resize = () => {
    W = Math.max(el.clientWidth, 1); H = Math.max(el.clientHeight, 1);
    renderer.setSize(W, H, false);
    camera.aspect = W / H;
    // Keep him fully in frame in narrow boxes.
    camera.fov = (framing === 'bust' ? 24 : 26) * Math.max(1, 0.8 / camera.aspect);
    camera.updateProjectionMatrix();
  };
  const ro = new ResizeObserver(resize); ro.observe(el); resize();

  // Rig state.
  let state = STATES.includes(cfg.state) ? cfg.state : 'idle';
  let oneShot = null; // {state, until}
  const P = { ...poses.idle(0) };
  const cur = {
    hipY: 0, hipRot: 0, spineX: 0, spineZ: 0, headX: 0, headY: 0, headZ: 0,
    aLx: 12, aLz: 10, aRx: 12, aRz: 10, eL: 12, eR: 12, lL: 0, lR: 0, kL: 0, kR: 0,
    browA: 0, browY: 0, lid: 0, lookX: 0, lookY: 0, turn: cfg.turn || 0,
  };
  const mouthScale = { smile: 1, worry: 0, grin: 0, oh: 0 };
  let blink = 0, nextBlink = 1.5, tapBoost = 0;
  const pointer = { x: 0, y: 0, active: false };
  const onMove = (e) => {
    const r = el.getBoundingClientRect();
    pointer.x = THREE.MathUtils.clamp((e.clientX - (r.left + r.width / 2)) / Math.max(innerWidth * 0.5, 1), -1, 1);
    pointer.y = THREE.MathUtils.clamp(-(e.clientY - (r.top + r.height * 0.3)) / Math.max(innerHeight * 0.5, 1), -1, 1);
    pointer.active = true;
  };
  addEventListener('pointermove', onMove, { passive: true });
  const fire = (name, detail) => el.dispatchEvent(new CustomEvent('fx', { detail: JSON.stringify({ name, ...detail }) }));
  const setState = (name, ms) => {
    if (!STATES.includes(name)) return;
    if (name === 'celebrate') fireBurst();
    if (ms) oneShot = { state: name, until: performance.now() + ms };
    else { state = name; oneShot = null; }
  };
  const onTap = () => { tapBoost = 1; setState('wave', 1400); fire('tap'); };
  renderer.domElement.addEventListener('pointerdown', onTap);

  let raf = 0, last = performance.now(), visible = true, disposed = false, t = cfg.t0 || 0;
  const io = new IntersectionObserver((e) => { visible = e[0].isIntersecting; if (visible && !raf) loop(); });
  io.observe(el);

  function apply(dt) {
    const stateNow = oneShot && performance.now() < oneShot.until ? oneShot.state : state;
    if (oneShot && performance.now() >= oneShot.until) oneShot = null;
    const p = poses[stateNow](t);
    const k = stateNow === 'run' || stateNow === 'celebrate' || stateNow === 'wave' ? 26 : 9;
    for (const [c, v] of [['hipY', p.hipY], ['hipRot', p.hipRot], ['spineX', p.spineX], ['spineZ', p.spineZ], ['headX', p.headX], ['headY', p.headY], ['headZ', p.headZ],
      ['aLx', p.armL[0]], ['aLz', p.armL[2]], ['aRx', p.armR[0]], ['aRz', p.armR[2]], ['eL', p.elbowL], ['eR', p.elbowR], ['lL', p.legL], ['lR', p.legR], ['kL', p.kneeL], ['kR', p.kneeR],
      ['browA', p.browA], ['browY', p.browY], ['lid', p.lid]]) cur[c] = damp(cur[c], v, k, dt);

    // Gaze: eyes lead, head follows a little.
    const gx = p.gaze && pointer.active ? pointer.x : (p.lookX ?? Math.sin(t * 0.37) * 0.25);
    const gy = p.gaze && pointer.active ? pointer.y : (p.lookY ?? Math.sin(t * 0.53) * 0.12);
    cur.lookX = damp(cur.lookX, gx, 11, dt);
    cur.lookY = damp(cur.lookY, gy, 11, dt);

    R.hips.position.y = 0.98 + cur.hipY;
    R.hips.rotation.y = cur.hipRot + cur.turn;
    R.spine.rotation.x = cur.spineX; R.spine.rotation.z = cur.spineZ;
    R.neck.rotation.y = -cur.hipRot * 0.8;
    R.head.rotation.x = cur.headX - cur.lookY * 0.1;
    R.head.rotation.y = cur.headY + cur.lookX * 0.24;
    R.head.rotation.z = cur.headZ;

    const [aL, aR] = R.arms;
    aL.shoulder.rotation.set(cur.aLx * DEG, 0, -cur.aLz * DEG);
    aR.shoulder.rotation.set(cur.aRx * DEG, 0, cur.aRz * DEG);
    aL.elbow.rotation.x = -cur.eL * DEG;
    aR.elbow.rotation.x = -cur.eR * DEG;
    const [lL, lR] = R.legs;
    lL.thigh.rotation.x = -cur.lL * DEG; lR.thigh.rotation.x = -cur.lR * DEG;
    lL.knee.rotation.x = cur.kL * DEG; lR.knee.rotation.x = cur.kR * DEG;
    R.book.visible = !!p.book;

    // Blink.
    nextBlink -= dt;
    if (nextBlink <= 0) { blink = 1; nextBlink = 1.8 + Math.random() * 3.5; }
    blink = Math.max(0, blink - dt * 7.5);
    const closed = Math.max(cur.lid, Math.sin(Math.min(blink, 1) * Math.PI));
    for (const e of R.eyes) {
      e.look.position.x = cur.lookX * 0.032;
      e.look.position.y = cur.lookY * 0.033;
      // Lids only exist while they are needed, so they never shimmer against the skull.
      e.lidTop.visible = closed > 0.015;
      e.lidBot.visible = closed > 0.5;
      e.lidTop.rotation.x = THREE.MathUtils.lerp(-1.25, 0.22, closed);
      e.lidBot.rotation.x = THREE.MathUtils.lerp(0.6, 0.2, closed);
      e.brow.position.y = 0.58 + cur.browY;
      e.brow.rotation.z = -e.side * cur.browA;
    }

    // Mouth blend by squash.
    for (const [name, m] of Object.entries(R.mouths)) {
      mouthScale[name] = damp(mouthScale[name], p.mouth === name ? 1 : 0, 16, dt);
      m.visible = mouthScale[name] > 0.03;
      m.scale.setScalar(Math.max(mouthScale[name], 0.001));
    }

    // Tap squash.
    tapBoost = Math.max(0, tapBoost - dt * 3.2);
    const sq = Math.sin(tapBoost * Math.PI) * 0.07;
    R.root.scale.set(1 + sq, 1 - sq, 1 + sq);

    shadow.scale.setScalar(1 - cur.hipY * 0.7);
    shadow.material.opacity = 1 - cur.hipY * 1.2;

    if (burstLife > 0) {
      burstLife -= dt * 0.9;
      burstM.opacity = Math.max(0, burstLife);
      const a = burstG.attributes.position;
      for (let i = 0; i < burstN; i++) {
        burstV[i].y -= 3.5 * dt;
        a.setXYZ(i, a.getX(i) + burstV[i].x * dt, a.getY(i) + burstV[i].y * dt, a.getZ(i) + burstV[i].z * dt);
      }
      a.needsUpdate = true;
    } else burstM.opacity = 0;
  }

  function step(dt) { t += dt; apply(dt); renderer.render(scene, camera); }
  function loop() {
    raf = 0;
    if (disposed || !visible) return;
    raf = requestAnimationFrame(loop);
    const now = performance.now();
    const dt = Math.min((now - last) / 1000, 0.05);
    last = now;
    step(dt);
  }
  loop();
  fire('ready');

  return {
    send(msg) {
      if (msg.state) setState(msg.state, msg.ms);
      if (msg.turn !== undefined) cur.turn = msg.turn;
    },
    // Used by the lab to render a settled pose for screenshots and the app icon.
    settle(name, seconds = 2) { setState(name); for (let i = 0; i < seconds * 30; i++) { t += 1 / 30; apply(1 / 30); } renderer.render(scene, camera); },
    scene, root: R.root, renderer,
    dispose() {
      disposed = true;
      cancelAnimationFrame(raf);
      io.disconnect(); ro.disconnect();
      removeEventListener('pointermove', onMove);
      renderer.domElement.removeEventListener('pointerdown', onTap);
      scene.traverse((o) => { o.geometry?.dispose?.(); if (o.material) (Array.isArray(o.material) ? o.material : [o.material]).forEach((m) => { m.map?.dispose?.(); m.dispose?.(); }); });
      scene.environment?.dispose?.();
      renderer.dispose();
      renderer.forceContextLoss?.();
      renderer.domElement.remove();
    },
  };
}

function starTexture() {
  const c = document.createElement('canvas'); c.width = c.height = 64;
  const g = c.getContext('2d');
  g.translate(32, 32);
  g.fillStyle = '#fff';
  g.beginPath();
  for (let i = 0; i < 8; i++) {
    const r = i % 2 ? 6 : 30, a = (i * Math.PI) / 4;
    g.lineTo(Math.cos(a) * r, Math.sin(a) * r);
  }
  g.closePath(); g.fill();
  return new THREE.CanvasTexture(c);
}
