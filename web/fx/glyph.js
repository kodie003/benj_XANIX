// Poured-metal and liquid-glass type. One shader, three looks:
//   metal: the benj logo as liquid metal (boot loader)
//   glass: the word "benj" as refractive glass (name reveal)
//   ring : a liquid-metal ring around an icon (primary action badge)
// Written for benj; inspired by the look of liquid-logo / glass-type components.
import { shaderCanvas, heightField, drawLogo, NOISE } from './glsl.js';

const FRAG = NOISE + `
uniform sampler2D uH; uniform float uMode; uniform vec2 uP; uniform float uIn; uniform float uAsp;
float H(vec2 uv){return texture2D(uH,uv).r;}
vec3 env(vec3 d){ // A little studio: warm key, cool sky, marigold floor bounce.
  float y=d.y*.5+.5;
  vec3 c=mix(vec3(.07,.07,.16),vec3(.78,.86,1.),smoothstep(.45,.95,y));
  c=mix(c,vec3(1.,.66,.16),smoothstep(.5,.0,y)*.9);
  c+=vec3(1.,.95,.82)*pow(max(0.,dot(d,normalize(vec3(.5,.7,.5)))),22.)*2.4;
  c+=vec3(.2,.95,.8)*pow(max(0.,dot(d,normalize(vec3(-.7,-.1,.5)))),9.)*.65;
  return c;
}
void main(){
  vec2 uv=gl_FragCoord.xy/uR;
  vec2 q=uv-.5; if(uAsp>1.) q.x*=uAsp; else q.y/=uAsp; q+=.5;
  if(q.x<0.||q.x>1.||q.y<0.||q.y>1.){gl_FragColor=vec4(0.);return;}
  // Slow liquid wobble in the sampled surface.
  vec2 w=vec2(fbm(q*3.2+vec2(uT*.22,-uT*.17)),fbm(q*3.2+vec2(-uT*.19,uT*.2)+7.))*.018*(1.-.45*uIn);
  float h=H(q+w);
  float reveal=smoothstep(0.,1.,uIn);
  float edge=mix(.62,.3,reveal);
  float m=smoothstep(edge,edge+.05,h);
  if(m<.002){gl_FragColor=vec4(0.);return;}
  float e=.006;
  vec3 n=normalize(vec3(H(q+w-vec2(e,0))-H(q+w+vec2(e,0)),H(q+w-vec2(0,e))-H(q+w+vec2(0,e)),.06));
  n.xy+=(uP)*.08;
  vec3 v=vec3(0,0,1);
  vec3 r=reflect(-v,normalize(n+vec3(0,0,.02)));
  float fr=pow(1.-max(dot(n,v),0.),3.);
  vec3 col;float a;
  if(uMode<.5||uMode>1.5){ // metal
    float flow=fbm(q*2.4+r.xy*1.9+uT*.09);
    vec3 e1=env(normalize(r+vec3(flow*.8,flow*.5,0.)));
    col=e1*mix(vec3(1.),vec3(1.,.86,.62),.42);
    col=mix(col,vec3(1.),fr*.5);
    a=1.;
  }else{ // glass: bends a moving aurora behind it and catches sharp highlights
    vec2 rf=q+n.xy*.32;
    float au=fbm(rf*2.1+uT*.12);
    vec3 back=mix(vec3(.04,.07,.2),vec3(.15,.9,.76),smoothstep(-.25,.35,au));
    back=mix(back,vec3(1.,.72,.2),smoothstep(.05,.55,fbm(rf*1.5-uT*.09+4.)));
    col=back*.86+env(r)*(.16+fr*.9);
    col+=pow(max(0.,dot(n,normalize(vec3(.4,.6,.7)))),60.)*1.1;
    a=mix(.82,1.,fr);
  }
  gl_FragColor=vec4(col*m*a,m*a);
}`;

export function mount(el, cfg = {}) {
  const mode = cfg.look === 'glass' ? 1 : cfg.look === 'ring' ? 2 : 0;
  let target = cfg.autoIn === false ? 0 : 1, val = 0;
  const px = { x: 0, y: 0 };
  const sc = shaderCanvas(el, FRAG, {
    uniforms: ['uH', 'uMode', 'uP', 'uIn', 'uAsp'],
    capture: cfg.capture,
    onFrame(gl, U) {
      val += (target - val) * 0.035;
      const asp = el.clientWidth / Math.max(el.clientHeight, 1);
      gl.uniform1f(U.uIn, val);
      gl.uniform1f(U.uMode, mode);
      gl.uniform1f(U.uAsp, asp);
      gl.uniform2f(U.uP, px.x, px.y);
      gl.uniform1i(U.uH, 0);
    },
  });
  if (!sc) return { send() {}, dispose() {} };
  const draw = mode === 1
    ? (g, S) => {
      // Always fit the word inside the texture, whatever the box shape.
      const text = cfg.text || 'benj';
      let size = S * 0.42;
      g.font = `800 ${size}px Bricolage, system-ui, sans-serif`;
      size *= Math.min(1, (S * 0.86) / g.measureText(text).width);
      g.font = `800 ${size}px Bricolage, system-ui, sans-serif`;
      g.textAlign = 'center'; g.textBaseline = 'middle';
      g.fillText(cfg.text || 'benj', S / 2, S * 0.47);
    }
    : mode === 2
      ? (g, S) => { g.lineWidth = S * 0.075; g.beginPath(); g.arc(S / 2, S / 2, S * 0.38, 0, 6.2832); g.stroke(); }
      : drawLogo;
  const setup = () => heightField(sc.gl, draw, 512);
  // The name needs its real font before it can be drawn into the height field.
  setup();
  if (mode === 1 && document.fonts?.load) {
    // The font ships with the app; redraw as soon as the browser has it.
    const face = new FontFace('Bricolage', 'url(assets/assets/fonts/BricolageGrotesque.ttf)', { weight: '200 800' });
    face.load().then((f) => { document.fonts.add(f); setup(); }).catch(() => {});
  }
  const onMove = (e) => {
    px.x = (e.clientX / innerWidth - 0.5) * 2;
    px.y = -(e.clientY / innerHeight - 0.5) * 2;
  };
  addEventListener('pointermove', onMove, { passive: true });
  el.dispatchEvent(new CustomEvent('fx', { detail: JSON.stringify({ name: 'ready' }) }));
  return {
    send(m) { if (m.in !== undefined) target = m.in; },
    dispose() { removeEventListener('pointermove', onMove); sc.dispose(); },
  };
}
