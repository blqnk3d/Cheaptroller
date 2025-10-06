// udp-smooth-controller-optimized-fixed.js
const dgram = require('dgram');
const robot = require('robotjs');
const os = require('os');

const UDP_PORT = 8080;

// ---------- Configurable parameters ----------
let MAX_SPEED = 80;
let DEADZONE = 0.05;
let DEADZONE_EXIT = 0.035;
let SMOOTH_TIME = 0.06;
let TICK_RATE = 60;
let TURN_RATE_DEG_PER_SEC = 720;
let SENSITIVITY_CURVE = 1.0;
let EPS_KEY_TOGGLE_MS = 30;

const BUTTON_MAPPING = { right: { 0: 'enter', 1: 'tab' } };
let dynamicConfig = { MAX_SPEED, DEADZONE, DEADZONE_EXIT, SMOOTH_TIME, TICK_RATE, TURN_RATE_DEG_PER_SEC, SENSITIVITY_CURVE };

// ---------- State ----------
let lastTime = process.hrtime.bigint();
let tickIntervalMs = Math.round(1000 / TICK_RATE);

let latestInput = { left: { x: 0, y: 0, ts: 0 }, right: { x: 0, y: 0, ts: 0 } };
let smoothed = { left: { x: 0, y: 0 }, right: { x: 0, y: 0 } };
let lastOutput = { leftAxes: { x: 0, y: 0 }, rightAxes: { x: 0, y: 0 }, mousePosSub: { x: 0, y: 0 } };
let pressedButtons = { left: new Set(), right: new Set() };
let pressedDirectionKeys = new Set();
let lastKeyToggleTime = 0;
const screenSize = robot.getScreenSize();
let mousePos = robot.getMousePos();

// ---------- Helpers ----------
const nowMs = () => Number(process.hrtime.bigint()) / 1e6; // Fixed BigInt -> Number
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const magnitude = (x, y) => Math.hypot(x, y);
const normalize = (x, y) => { const m = Math.hypot(x, y); return m ? [x/m, y/m] : [0,0]; };
const mag01 = (x, y) => clamp(magnitude(x, y), 0, 1);
const smoothingAlpha = (dtSec, tauSec) => tauSec <= 0 ? 1.0 : 1 - Math.exp(-dtSec / tauSec);
const angleOf = (x, y) => Math.atan2(y, x);
const angleDiff = (a, b) => { let d = a - b; while(d<=-Math.PI)d+=2*Math.PI; while(d>Math.PI)d-=2*Math.PI; return d; };

function applyConfig(updates) {
  if(typeof updates!=='object') return;
  for(const [k,v] of Object.entries(updates)) if(dynamicConfig.hasOwnProperty(k)&&typeof v==='number') dynamicConfig[k]=v;
  MAX_SPEED=dynamicConfig.MAX_SPEED;
  DEADZONE=dynamicConfig.DEADZONE;
  DEADZONE_EXIT=dynamicConfig.DEADZONE_EXIT;
  SMOOTH_TIME=dynamicConfig.SMOOTH_TIME;
  TICK_RATE=dynamicConfig.TICK_RATE;
  tickIntervalMs=Math.round(1000/TICK_RATE);
  TURN_RATE_DEG_PER_SEC=dynamicConfig.TURN_RATE_DEG_PER_SEC;
  SENSITIVITY_CURVE=dynamicConfig.SENSITIVITY_CURVE;
  console.log('🔧 Config updated:', dynamicConfig);
}

function mapDirectionToKeysFromAxes(ax, ay) {
  const keys = new Set();
  if(ay<-DEADZONE) keys.add('w'); else if(ay>DEADZONE) keys.add('s');
  if(ax<-DEADZONE) keys.add('a'); else if(ax>DEADZONE) keys.add('d');
  return keys;
}

function updatePressedDirectionKeys(side, newKeys) {
  const now = nowMs();
  for(const key of Array.from(pressedDirectionKeys)) if(!newKeys.has(key) && now - lastKeyToggleTime>EPS_KEY_TOGGLE_MS){ robot.keyToggle(key,'up'); pressedDirectionKeys.delete(key); lastKeyToggleTime=now; }
  for(const key of newKeys) if(!pressedDirectionKeys.has(key) && now - lastKeyToggleTime>EPS_KEY_TOGGLE_MS){ robot.keyToggle(key,'down'); pressedDirectionKeys.add(key); lastKeyToggleTime=now; }
}

function handleButton(side, idx, down) {
  if(side==='left'){
    if(idx===0){ robot.mouseToggle(down?'down':'up','left'); return; }
    if(idx===1){ robot.mouseToggle(down?'down':'up','right'); return; }
    if(idx===2){ robot.mouseToggle(down?'down':'up','middle'); return; }
  }
  const key=BUTTON_MAPPING[side]?.[idx];
  if(key) robot.keyToggle(key, down?'down':'up');
  if(down) pressedButtons[side].add(idx); else pressedButtons[side].delete(idx);
}

// ---------- Mouse movement ----------
function applyMouseMoveByVector(nx, ny, dtSec) {
  const mag = mag01(nx, ny);
  if(mag<DEADZONE && mag<DEADZONE_EXIT) return;
  const scaledMag = Math.pow(mag, SENSITIVITY_CURVE);
  const speed = MAX_SPEED*30*scaledMag;
  const [dirX, dirY] = normalize(nx, ny);
  lastOutput.mousePosSub.x += dirX*speed*dtSec;
  lastOutput.mousePosSub.y += dirY*speed*dtSec;
  const moveX = Math.trunc(lastOutput.mousePosSub.x);
  const moveY = Math.trunc(lastOutput.mousePosSub.y);
  if(moveX!==0 || moveY!==0){
    mousePos.x = clamp(mousePos.x+moveX,0,screenSize.width-1);
    mousePos.y = clamp(mousePos.y+moveY,0,screenSize.height-1);
    robot.moveMouse(mousePos.x, mousePos.y);
    lastOutput.mousePosSub.x -= moveX;
    lastOutput.mousePosSub.y -= moveY;
  }
}

// ---------- UDP Server ----------
const server = dgram.createSocket('udp4');
server.on('message',(msg,rinfo)=>{
  try{
    const d=JSON.parse(msg.toString());
    const t=d.type, side=d.side, now=nowMs();
    if(t==='move'){ const x=Number(d.x||0), y=Number(d.y||0); if(side==='left'||side==='right') latestInput[side]={x,y,ts:now}; }
    else if(t==='button_down'||t==='button_up'){ handleButton(side,d.index,t==='button_down'); }
    else if(t==='config'&&d.constants){ applyConfig(d.constants); server.send(JSON.stringify({type:'config_ack',updatedConfig:dynamicConfig}), rinfo.port,rinfo.address); }
  }catch(e){ console.error('❌ UDP parse error:',e); }
});
server.on('listening',()=>{ const addr=server.address(); console.log(`🟢 UDP server running on ${getAllLocalIPs().join(",")}:${addr.port}`); });
server.bind(UDP_PORT,'0.0.0.0');

// ---------- Main tick loop ----------
function tick(){
  const now=process.hrtime.bigint();
  const dtSec=Number(now-lastTime)/1e9; 
  lastTime=now;
  const alpha=smoothingAlpha(dtSec,SMOOTH_TIME), magAlpha=smoothingAlpha(dtSec,SMOOTH_TIME*0.8);

  ['left','right'].forEach(side=>{
    let input=latestInput[side]; 
    if(nowMs()-input.ts>250) input={x:0,y:0};
    const s=smoothed[side]; s.x=s.x*(1-alpha)+input.x*alpha; s.y=s.y*(1-alpha)+input.y*alpha;

    const prev=side==='left'?lastOutput.leftAxes:lastOutput.rightAxes;
    const prevMag=mag01(prev.x,prev.y), targetMag=mag01(s.x,s.y);
    const targetAngle=targetMag>0?angleOf(s.x,s.y):0, prevAngle=prevMag>0?angleOf(prev.x,prev.y):0;
    const maxRad=(TURN_RATE_DEG_PER_SEC*dtSec*Math.PI)/180;
    let newAngle=prevMag>0 && targetMag>0 ? prevAngle+clamp(angleDiff(targetAngle,prevAngle),-maxRad,maxRad)
                  : prevMag>0 && targetMag<=0 ? prevAngle+clamp(angleDiff(0,prevAngle),-maxRad,maxRad)
                  : targetAngle;
    const newMag=prevMag*(1-magAlpha)+targetMag*magAlpha;
    const nx=newMag*Math.cos(newAngle), ny=newMag*Math.sin(newAngle);
    if(side==='left') lastOutput.leftAxes={x:nx,y:ny}; else lastOutput.rightAxes={x:nx,y:ny};
  });

  // Left stick -> WASD
  const ax=lastOutput.leftAxes.x, ay=lastOutput.leftAxes.y;
  const mag=mag01(ax,ay);
  const keys=(mag<DEADZONE)?new Set():mapDirectionToKeysFromAxes(ax,ay);
  updatePressedDirectionKeys('left',keys);

  // Right stick -> Mouse
  applyMouseMoveByVector(lastOutput.rightAxes.x,lastOutput.rightAxes.y,dtSec);

  const next=tickIntervalMs-(Number(process.hrtime.bigint()-now)/1e6);
  setTimeout(tick,Math.max(0,next));
}
lastTime=process.hrtime.bigint();
setTimeout(tick,tickIntervalMs);

// ---------- Utility ----------
function getAllLocalIPs(){
  const ips=[]; 
  for(const name of Object.keys(os.networkInterfaces()))
    for(const net of os.networkInterfaces()[name])
      if(net.family==='IPv4'&&!net.internal&&!net.address.startsWith('169.254.')) ips.push(net.address);
  return ips.length>0?ips:['127.0.0.1'];
}