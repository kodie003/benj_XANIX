// "Saving your count": a grainy glowing shape that breathes between circle, box and
// triangle while a log is being saved, then resolves into a tick when it lands.
import { shaderCanvas, NOISE } from './glsl.js';

const FRAG = NOISE + `
uniform float uDone; uniform vec2 uP; uniform float uLvl;
float sdCircle(vec2 p,float r){return length(p)-r;}
float sdBox(vec2 p,float r){vec2 d=abs(p)-vec2(r*.82);return length(max(d,0.))+min(max(d.x,d.y),0.)-r*.14;}
float sdTri(vec2 p,float r){const float k=1.732;p.y+=r*.18;p.x=abs(p.x)-r;p.y=p.y+r/k;if(p.x+k*p.y>0.)p=vec2(p.x-k*p.y,-k*p.x-p.y)/2.;p.x-=clamp(p.x,-2.*r,0.);return -length(p)*sign(p.y)-r*.1;}
float seg(vec2 p,vec2 a,vec2 b){vec2 pa=p-a,ba=b-a;float h=clamp(dot(pa,ba)/dot(ba,ba),0.,1.);return length(pa-ba*h);}
float sdTick(vec2 p,float r){return min(seg(p,vec2(-.52,-.02)*r,vec2(-.14,-.42)*r),seg(p,vec2(-.14,-.42)*r,vec2(.62,.46)*r))-r*.09;}
void main(){
  vec2 p=(gl_FragCoord.xy-.5*uR)/min(uR.x,uR.y);
  p-=uP*.05;
  float r=.2+.012*sin(uT*2.4)+uLvl*.02;
  float t=uT*.55;
  float f=fract(t)*3.;
  float i=floor(f);f=smoothstep(.25,.75,fract(f));
  float a=i<.5?sdCircle(p,r):(i<1.5?sdBox(p,r):sdTri(p,r));
  float b=i<.5?sdBox(p,r):(i<1.5?sdTri(p,r):sdCircle(p,r));
  float d=mix(a,b,f);
  d=mix(d,sdTick(p,r*1.15),uDone);
  // Three colours travel around the outline.
  float ang=atan(p.y,p.x)/6.2832+uT*.13;
  vec3 c=.5+.5*cos(6.2832*(vec3(.02,.33,.56)+ang+.12*sin(uT*.5)));
  c=mix(vec3(1.,.71,.15),c,.55);
  c=mix(c,vec3(.18,.9,.77),smoothstep(-.2,.6,sin(ang*12.566))*.65);
  c=mix(c,vec3(.18,.9,.77),uDone);
  float core=smoothstep(.012,-.004,abs(d));
  float inner=exp(-max(-d,0.)*22.)*step(d,0.)*.4;
  float halo=exp(-max(d,0.)*(13.-uDone*5.))*.95;
  float wide=exp(-max(d,0.)*4.)*.16;
  float grain=noise(gl_FragCoord.xy*.9+uT*40.)*.5+.5;
  float l=core*1.5+inner+(halo+wide)*(.62+.5*grain);
  vec3 col=c*l+vec3(1.)*core*.5;
  float al=clamp(l,0.,1.);
  gl_FragColor=vec4(col,al);
}`;

export function mount(el, cfg = {}) {
  let done = 0, doneT = 0;
  const p = { x: 0, y: 0 };
  const sc = shaderCanvas(el, FRAG, {
    uniforms: ['uDone', 'uP', 'uLvl'],
    capture: cfg.capture,
    onFrame(gl, U) {
      done += (doneT - done) * 0.09;
      gl.uniform1f(U.uDone, done);
      gl.uniform2f(U.uP, p.x, p.y);
      gl.uniform1f(U.uLvl, 0);
    },
  });
  if (!sc) return { send() {}, dispose() {} };
  // Magnetic pull toward the finger or cursor.
  const onMove = (e) => {
    const r = el.getBoundingClientRect();
    p.x = ((e.clientX - r.left) / r.width - 0.5) * 2;
    p.y = -((e.clientY - r.top) / r.height - 0.5) * 2;
  };
  addEventListener('pointermove', onMove, { passive: true });
  return {
    send(m) { if (m.done !== undefined) doneT = m.done ? 1 : 0; },
    settle() {},
    dispose() { removeEventListener('pointermove', onMove); sc.dispose(); },
  };
}
