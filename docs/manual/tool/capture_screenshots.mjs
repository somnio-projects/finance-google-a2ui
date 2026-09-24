// Captures the manual's screenshots from a running stack, straight to PNG files.
//
// The manual is only honest if its pictures can be retaken, so this drives a
// headless Chrome over the DevTools protocol rather than being a folder of
// images somebody once pasted in. Node 22+ only: it uses the built-in
// WebSocket and fetch, so there is nothing to install.
//
//   node docs/manual/tool/capture_screenshots.mjs [--url http://localhost:3000]
//                                                 [--email you@example.com]
//
// Chrome must already be listening on --port (default 9333):
//   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
//     --headless=new --disable-gpu --user-data-dir=/tmp/ggu-chrome \
//     --remote-debugging-port=9333 --hide-scrollbars about:blank
import {writeFileSync, mkdirSync} from 'node:fs';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const arg = (name, fallback) => {
  const i = process.argv.indexOf(`--${name}`);
  return i === -1 ? fallback : process.argv[i + 1];
};
const url = arg('url', 'http://localhost:3000');
const email = arg('email', 'demo@somnio.dev');
const port = arg('port', '9333');
const outDir = resolve(dirname(fileURLToPath(import.meta.url)), '..', 'assets');
mkdirSync(outDir, {recursive: true});

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// --- a minimal CDP client -------------------------------------------------
const targets = await (await fetch(`http://127.0.0.1:${port}/json/new?about:blank`, {method: 'PUT'})).json();
const ws = new WebSocket(targets.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r, {once: true}));
let nextId = 0;
const pending = new Map();
ws.addEventListener('message', (e) => {
  const msg = JSON.parse(e.data);
  if (msg.id !== undefined && pending.has(msg.id)) {
    const {resolve: ok, reject} = pending.get(msg.id);
    pending.delete(msg.id);
    msg.error ? reject(new Error(JSON.stringify(msg.error))) : ok(msg.result);
  }
});
const send = (method, params = {}) =>
  new Promise((ok, reject) => {
    const id = ++nextId;
    pending.set(id, {resolve: ok, reject});
    ws.send(JSON.stringify({id, method, params}));
  });

// --- the gestures the app understands ------------------------------------
const click = async (x, y) => {
  for (const type of ['mousePressed', 'mouseReleased']) {
    await send('Input.dispatchMouseEvent', {type, x, y, button: 'left', clickCount: 1, buttons: type === 'mousePressed' ? 1 : 0});
  }
  await sleep(350);
};
const type_ = async (text) => {
  await send('Input.insertText', {text});
  await sleep(350);
};
const scrollBy = async (y, dy) => {
  await send('Input.dispatchMouseEvent', {type: 'mouseWheel', x: 187, y, deltaX: 0, deltaY: dy});
  await sleep(700);
};
const shot = async (name) => {
  // Park the pointer off the content first: a hover state (a carousel arrow,
  // a row highlight) is not part of the screen and must not appear in a manual.
  await send('Input.dispatchMouseEvent', {type: 'mouseMoved', x: 5, y: 5});
  await sleep(700);
  const {data} = await send('Page.captureScreenshot', {format: 'png', captureBeyondViewport: false});
  const file = `${outDir}/${name}.png`;
  writeFileSync(file, Buffer.from(data, 'base64'));
  console.log(`wrote ${file}`);
};

// --- the walkthrough ------------------------------------------------------
await send('Page.enable');
await send('Runtime.enable');
// A phone, at 2x, because this is a mobile-first product and the manual shows it as one.
await send('Emulation.setDeviceMetricsOverride', {width: 375, height: 812, deviceScaleFactor: 2, mobile: true});

await send('Page.navigate', {url});
await sleep(6000);
await shot('01-sign-in');

await click(187, 408);          // the e-mail field
await type_(email);
await click(187, 480);          // Continue with email
await sleep(7000);
await shot('02-home-top');

await scrollBy(600, 700);
await shot('03-home-suggested-questions');

const TABS = {home: 47, holdings: 140, activity: 234, assistant: 327};
await click(TABS.holdings, 760);
await sleep(4000);
await shot('04-holdings');
await scrollBy(400, 1150);
await shot('05-holdings-positions');

await click(TABS.activity, 760);
await sleep(4000);
await shot('06-activity');

await click(TABS.assistant, 760);
await sleep(3000);
await click(132, 697);          // the question field
await type_('How is my portfolio allocated?');
await click(340, 697);          // send
await sleep(22000);             // a real model turn, not a stub
await shot('07-assistant-answer');

ws.close();
console.log('done');
