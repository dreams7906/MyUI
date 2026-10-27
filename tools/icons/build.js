// Packs Iconify icons into assets/icons.png + assets/icons.json for MyUI 2.
//
//   npm i playwright @iconify-json/lucide   (plus @iconify-json/<set> for any other set you list)
//   node tools/icons/build.js
//
// Icons come from the @iconify-json/<set> npm packages when installed, otherwise from the
// Iconify API (https://api.iconify.design). Every icon is drawn white so the UI can tint it.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname, '..', '..');
const SIZE = 32;            // icon pixels
const PAD = 2;              // transparent gutter on every side (stops neighbours bleeding in)
const PITCH = SIZE + PAD * 2;
const COLUMNS = Math.floor(1024 / PITCH);

function parseList(file) {
  const icons = [];
  const aliases = {};
  for (const raw of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const line = raw.replace(/#.*/, '').trim();
    if (!line) continue;
    const eq = line.indexOf('=');
    if (eq >= 0) {
      const alias = line.slice(0, eq).trim().toLowerCase();
      const target = line.slice(eq + 1).trim().toLowerCase();
      aliases[alias] = target.startsWith('lucide:') ? target.slice(7) : target;
      if (!icons.includes(aliases[alias])) icons.push(aliases[alias]);
    } else {
      const name = line.toLowerCase().startsWith('lucide:') ? line.slice(7).toLowerCase() : line.toLowerCase();
      if (!icons.includes(name)) icons.push(name);
    }
  }
  return { icons, aliases };
}

async function loadSet(prefix, names) {
  try {
    return JSON.parse(fs.readFileSync(require.resolve(`@iconify-json/${prefix}/icons.json`, { paths: [process.cwd(), __dirname] }), 'utf8'));
  } catch {
    const url = `https://api.iconify.design/${prefix}.json?icons=${names.join(',')}`;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`could not load icon set "${prefix}" (${res.status})`);
    return res.json();
  }
}

function resolve(set, name) {
  let entry = set.icons[name];
  let rotate = 0, hFlip = false, vFlip = false;
  let seen = 0;
  while (!entry && set.aliases && set.aliases[name] && seen++ < 8) {
    const alias = set.aliases[name];
    rotate += alias.rotate || 0; hFlip = hFlip !== !!alias.hFlip; vFlip = vFlip !== !!alias.vFlip;
    name = alias.parent;
    entry = set.icons[name];
  }
  if (!entry) return null;
  const w = entry.width || set.width || 16, h = entry.height || set.height || 16;
  const left = entry.left || 0, top = entry.top || 0;
  rotate += entry.rotate || 0; hFlip = hFlip !== !!entry.hFlip; vFlip = vFlip !== !!entry.vFlip;
  const t = [];
  if (hFlip || vFlip) t.push(`translate(${hFlip ? w + 2 * left : 0} ${vFlip ? h + 2 * top : 0}) scale(${hFlip ? -1 : 1} ${vFlip ? -1 : 1})`);
  if (rotate % 4) t.push(`rotate(${(rotate % 4) * 90} ${left + w / 2} ${top + h / 2})`);
  const body = t.length ? `<g transform="${t.join(' ')}">${entry.body}</g>` : entry.body;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${SIZE}" height="${SIZE}" viewBox="${left} ${top} ${w} ${h}" style="color:#fff">${body}</svg>`;
}

(async () => {
  const { icons, aliases } = parseList(path.join(__dirname, 'icons.txt'));
  const bySet = {};
  for (const name of icons) {
    const [prefix, icon] = name.includes(':') ? name.split(':') : ['lucide', name];
    (bySet[prefix] = bySet[prefix] || []).push(icon);
  }
  const sets = {};
  for (const prefix of Object.keys(bySet)) sets[prefix] = await loadSet(prefix, bySet[prefix]);

  const svgs = [];
  const index = {};
  const seen = new Map(); // names that resolve to the same drawing share one cell
  for (const name of icons) {
    const [prefix, icon] = name.includes(':') ? name.split(':') : ['lucide', name];
    const svg = resolve(sets[prefix], icon);
    if (!svg) { console.warn(`skipped ${name}: not found`); continue; }
    if (!seen.has(svg)) { seen.set(svg, svgs.length); svgs.push(svg); }
    index[name] = seen.get(svg);
  }
  for (const [alias, target] of Object.entries(aliases)) if (index[target] === undefined) delete aliases[alias];
  if (svgs.length > COLUMNS * COLUMNS) throw new Error(`too many icons (${svgs.length}, max ${COLUMNS * COLUMNS})`);

  const rows = Math.ceil(svgs.length / COLUMNS);
  const width = COLUMNS * PITCH, height = rows * PITCH;
  const cells = svgs.map((svg, i) =>
    `<div style="position:absolute;left:${(i % COLUMNS) * PITCH + PAD}px;top:${Math.floor(i / COLUMNS) * PITCH + PAD}px;width:${SIZE}px;height:${SIZE}px">${svg}</div>`).join('');
  const html = `<!doctype html><html><body style="margin:0;background:transparent"><div id="sheet" style="position:relative;width:${width}px;height:${height}px">${cells}</div></body></html>`;

  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1 });
  await page.setContent(html);
  const png = await page.locator('#sheet').screenshot({ omitBackground: true });
  await browser.close();

  const out = path.join(ROOT, 'assets');
  fs.mkdirSync(out, { recursive: true });
  fs.writeFileSync(path.join(out, 'icons.png'), png);
  const manifest = {
    version: crypto.createHash('sha1').update(png).digest('hex').slice(0, 12),
    size: SIZE, pad: PAD, pitch: PITCH, columns: COLUMNS,
    icons: index, aliases,
  };
  fs.writeFileSync(path.join(out, 'icons.json'), JSON.stringify(manifest));
  console.log(`packed ${svgs.length} icons (${width}x${height}), version ${manifest.version}`);
})().catch((err) => { console.error(err); process.exit(1); });
