// Tiny raw-WebGL helper shared by the shader effects, so they stay usable
// without loading three.js (the boot screen must be as light as possible).
export const NOISE = `
vec2 hash2(vec2 p){p=vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3)));return -1.+2.*fract(sin(p)*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p),u=f*f*(3.-2.*f);
  return mix(mix(dot(hash2(i),f),dot(hash2(i+vec2(1,0)),f-vec2(1,0)),u.x),mix(dot(hash2(i+vec2(0,1)),f-vec2(0,1)),dot(hash2(i+vec2(1,1)),f-vec2(1,1)),u.x),u.y);}
float fbm(vec2 p){float v=0.,a=.5;for(int i=0;i<4;i++){v+=a*noise(p);p=p*2.03+vec2(1.7,9.2);a*=.5;}return v;}
`;

export function shaderCanvas(el, frag, { maxDpr = 1.5, uniforms = [], onFrame, capture = false } = {}) {
  const canvas = document.createElement('canvas');
  canvas.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;display:block';
  el.appendChild(canvas);
  const gl = canvas.getContext('webgl', { alpha: true, premultipliedAlpha: true, antialias: false, preserveDrawingBuffer: capture });
  if (!gl) return null;
  const compile = (type, src) => {
    const s = gl.createShader(type);
    gl.shaderSource(s, src);
    gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) console.error(gl.getShaderInfoLog(s));
    return s;
  };
  const prog = gl.createProgram();
  gl.attachShader(prog, compile(gl.VERTEX_SHADER, 'attribute vec2 p;void main(){gl_Position=vec4(p,0,1);}'));
  gl.attachShader(prog, compile(gl.FRAGMENT_SHADER, 'precision highp float;uniform vec2 uR;uniform float uT;' + frag));
  gl.linkProgram(prog);
  gl.useProgram(prog);
  const buf = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, buf);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0);
  gl.bindAttribLocation(prog, 0, 'p');
  gl.linkProgram(prog);
  gl.useProgram(prog);
  gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
  const U = { R: gl.getUniformLocation(prog, 'uR'), T: gl.getUniformLocation(prog, 'uT') };
  for (const u of uniforms) U[u] = gl.getUniformLocation(prog, u);
  gl.enable(gl.BLEND);
  gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);

  const resize = () => {
    const d = Math.min(window.devicePixelRatio || 1, maxDpr);
    canvas.width = Math.max(1, el.clientWidth * d);
    canvas.height = Math.max(1, el.clientHeight * d);
    gl.viewport(0, 0, canvas.width, canvas.height);
  };
  const ro = new ResizeObserver(resize);
  ro.observe(el);
  resize();

  let raf = 0, visible = true, dead = false;
  const start = performance.now();
  const draw = () => {
    raf = 0;
    if (dead || !visible) return;
    raf = requestAnimationFrame(draw);
    const t = (performance.now() - start) / 1000;
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.uniform2f(U.R, canvas.width, canvas.height);
    gl.uniform1f(U.T, t);
    onFrame?.(gl, U, t);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
  };
  const io = new IntersectionObserver((e) => { visible = e[0].isIntersecting; if (visible && !raf) draw(); });
  io.observe(el);
  draw();
  return {
    gl, canvas, U,
    dispose() {
      dead = true;
      cancelAnimationFrame(raf);
      ro.disconnect(); io.disconnect();
      gl.getExtension('WEBGL_lose_context')?.loseContext();
      canvas.remove();
    },
  };
}

// Draw a mask on a 2D canvas and blur it into a soft height field: this is what
// gives text and logos their thick, poured, liquid-glass bevel in the shaders below.
export function heightField(gl, draw, size = 512) {
  const c = document.createElement('canvas');
  c.width = c.height = size;
  const g = c.getContext('2d');
  const pass = (blur, alpha) => { g.save(); g.filter = `blur(${blur}px)`; g.globalAlpha = alpha; draw(g, size); g.restore(); };
  g.fillStyle = '#000'; g.fillRect(0, 0, size, size);
  g.fillStyle = '#fff'; g.strokeStyle = '#fff';
  g.globalCompositeOperation = 'lighter';
  pass(size * 0.032, 0.42); pass(size * 0.014, 0.32); pass(size * 0.005, 0.26);
  const tex = gl.createTexture();
  gl.activeTexture(gl.TEXTURE0);
  gl.bindTexture(gl.TEXTURE_2D, tex);
  gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, c);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  return tex;
}

export const drawLogo = (g, S) => {
  // The benj mark: a lowercase "b" whose bowl is an eye holding a spark of foresight.
  const s = S / 100;
  g.lineCap = 'round';
  g.lineWidth = 13 * s;
  g.beginPath(); g.moveTo(33 * s, 16 * s); g.lineTo(33 * s, 66 * s); g.stroke();
  g.beginPath(); g.arc(52 * s, 62 * s, 19.5 * s, 0, 6.2832); g.stroke();
  const cx = 52 * s, cy = 62 * s, r = 8.8 * s;
  g.beginPath();
  for (let i = 0; i < 8; i++) {
    const q = i % 2 ? r * 0.26 : r;
    const a = (i * Math.PI) / 4 - Math.PI / 2;
    g.lineTo(cx + Math.cos(a) * q, cy + Math.sin(a) * q);
  }
  g.closePath(); g.fill();
};
