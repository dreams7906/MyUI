// Renders the mascot frames listed in frames.json from a Live2D sample model.
//
//   npm i playwright pixi.js@6.5.10 pixi-live2d-display@0.4.0 live2dcubismcore@1.0.2
//   node render.js           -> out/<index>_<Name>.png (+ out/base/ for the blush pass)
//   python post.py           -> ../../assets/hiyori.png
//
// The model comes from Live2D's CubismWebSamples (Free Material License).
const fs = require('fs');
const path = require('path');
const http = require('http');
const { chromium } = require('playwright');

const DIR = __dirname;
const job = JSON.parse(fs.readFileSync(path.join(DIR, 'frames.json'), 'utf8'));
const BASE = `https://raw.githubusercontent.com/Live2D/CubismWebSamples/develop/Samples/Resources/${job.model}/`;

async function download(rel) {
  const target = path.join(DIR, 'model', job.model, rel);
  if (fs.existsSync(target)) return fs.readFileSync(target);
  const res = await fetch(BASE + rel);
  if (!res.ok) throw new Error(`download failed: ${rel} (${res.status})`);
  const data = Buffer.from(await res.arrayBuffer());
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, data);
  return data;
}

async function fetchModel() {
  const manifest = JSON.parse(await download(`${job.model}.model3.json`));
  const refs = manifest.FileReferences;
  const files = [refs.Moc, ...(refs.Textures || []), refs.Physics, refs.Pose, refs.DisplayInfo, refs.UserData].filter(Boolean);
  for (const group of Object.values(refs.Motions || {})) for (const m of group) files.push(m.File);
  for (const file of files) await download(file);
}

(async () => {
  await fetchModel();
  const server = http.createServer((req, res) => {
    const file = path.join(DIR, decodeURIComponent(req.url.split('?')[0]));
    fs.readFile(file, (err, data) => {
      if (err) { res.writeHead(404); res.end(); return; }
      const type = file.endsWith('.html') ? 'text/html' : file.endsWith('.js') ? 'text/javascript' : file.endsWith('.json') ? 'application/json' : file.endsWith('.png') ? 'image/png' : 'application/octet-stream';
      res.writeHead(200, { 'Content-Type': type }); res.end(data);
    });
  });
  await new Promise((resolve) => server.listen(8765, resolve));
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const page = await browser.newPage();
  page.on('pageerror', (e) => console.error('pageerror:', e.message));
  await page.goto('http://127.0.0.1:8765/render.html');
  await page.evaluate(([name, size]) => window.setup(name, size), [job.model, job.canvas]);

  const out = path.join(DIR, 'out');
  fs.mkdirSync(path.join(out, 'base'), { recursive: true });
  const save = (file, url) => fs.writeFileSync(file, Buffer.from(url.split(',')[1], 'base64'));
  for (const [index, frame] of job.frames.entries()) {
    const name = `${String(index).padStart(2, '0')}_${frame.name}`;
    save(path.join(out, name + '.png'), await page.evaluate(([p, place, ticks]) => window.frame(p, place, ticks), [frame.params, job.place, job.settleTicks]));
    if (job.blush[frame.name]) {
      // Same pose with the default blush, so post.py can isolate and strengthen the cheeks.
      const base = Object.assign({}, frame.params, { ParamCheek: 0 });
      save(path.join(out, 'base', name + '.png'), await page.evaluate(([p, place, ticks]) => window.frame(p, place, ticks), [base, job.place, job.settleTicks]));
    }
    console.log('rendered', name);
  }
  await browser.close();
  server.close();
})().catch((err) => { console.error(err); process.exit(1); });
