// Run an R script in webR (base R 4.6 compiled to WebAssembly; offline, from the npm `webr` package).
//   node run_r.mjs <driver.R> --mount=<hostDir>:<vfsDir> [...] --pull=<vfsDir>:<hostDir>
// Host folders are *copied* into the virtual file system, so the apps' files are never written.
import { WebR } from 'webr';
import fs from 'fs';
import path from 'path';

const args = process.argv.slice(2);
const script = args.find(a => !a.startsWith('--'));
const mounts = args.filter(a => a.startsWith('--mount=')).map(a => a.slice(8).split(':'));
const pulls = args.filter(a => a.startsWith('--pull=')).map(a => a.slice(7).split(':'));
const SKIP = new Set(['.git', 'renv', 'node_modules', '.Rproj.user', '__MACOSX', 'songs', 'songs_all', 'cache', 'preview', 'examples', 'media']);

const webR = new WebR();
await webR.init();
const made = new Set();
const mkdirp = async (p) => { let cur = ''; for (const d of p.split('/').filter(Boolean)) { cur += '/' + d; if (!made.has(cur)) { made.add(cur); try { await webR.FS.mkdir(cur); } catch (e) {} } } };
let nfiles = 0;
const copyIn = async (host, vfs) => {
  const st = fs.statSync(host);
  if (st.isDirectory()) {
    await mkdirp(vfs);
    for (const f of fs.readdirSync(host)) { if (!SKIP.has(f) && !f.endsWith('.zip') && !f.endsWith('.RData') && !f.endsWith('.rds') && !f.endsWith('.psarc')) await copyIn(path.join(host, f), vfs + '/' + f); }
  } else if (st.size < 20e6) {
    await mkdirp(path.dirname(vfs)); await webR.FS.writeFile(vfs, new Uint8Array(fs.readFileSync(host))); nfiles++;
  }
};
for (const [h, v] of mounts) await copyIn(path.resolve(h), v);
await mkdirp('/bench/out');
await webR.FS.writeFile('/bench/driver.R', new Uint8Array(fs.readFileSync(script)));
const shelter = await new webR.Shelter();
const res = await shelter.captureR(`tryCatch(source('/bench/driver.R', echo = FALSE), error = function(e) { cat('R ERROR:', conditionMessage(e), '\\n'); if (!inherits(e, 'quiet_error')) print(sys.calls()) })`,
  { captureStreams: true, captureConditions: true });
let failed = false;
for (const o of res.output) {
  if (o.type === 'stdout') { console.log(o.data); if (String(o.data).startsWith('R ERROR')) failed = true; }
  else if (o.type === 'stderr') console.error(o.data);
  else if (o.type === 'warning' || o.type === 'error') {
    let m = ''; try { m = (await (await o.data.get('message')).toJs()).values.join(' '); } catch (e) { m = '(condition)'; }
    console.error(o.type.toUpperCase() + ':', m); if (o.type === 'error') failed = true;
  }
}
const pull = async (vfs, host) => {
  const node = await webR.FS.lookupPath(vfs);
  if (node.isFolder) { fs.mkdirSync(host, { recursive: true }); for (const n of Object.keys(node.contents || {})) await pull(vfs + '/' + n, path.join(host, n)); }
  else fs.writeFileSync(host, Buffer.from(await webR.FS.readFile(vfs)));
};
for (const [v, h] of pulls) await pull(v, path.resolve(h));
console.error(`[run_r] mounted ${nfiles} files; ${failed ? 'FAILED' : 'ok'}`);
shelter.purge();
process.exit(failed ? 1 : 0);
