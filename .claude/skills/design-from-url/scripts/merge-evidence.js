#!/usr/bin/env node
const fs = require('fs');
const [visualPath, systemPath, responsivePath, outPath] = process.argv.slice(2);
if (!outPath) { console.error('Usage: merge-evidence.js visual.json system.json responsive.json out.json'); process.exit(2); }
function read(p) { try { return JSON.parse(fs.readFileSync(p,'utf8')); } catch(e) { console.error(`Cannot read ${p}: ${e.message}`); process.exit(1); } }
const inputs = [read(visualPath), read(systemPath), read(responsivePath)];
const stable = v => typeof v === 'string' ? v : JSON.stringify(v);
const uniq = xs => { const m=new Map(); for(const x of xs.filter(v=>v!==null&&v!==undefined&&v!=='')) m.set(stable(x),x); return [...m.values()]; };
const sampleKeys = new Set(inputs.flatMap(x => Object.keys(x.samples || {})));
const samples = {};
for (const key of sampleKeys) samples[key] = inputs.flatMap(x => (x.samples && x.samples[key]) || []);
const merged = {
  generatedAt: new Date().toISOString(),
  researchers: inputs.map(x => x.researcher || 'unknown'),
  browserAvailable: inputs.some(x => x.browserAvailable === true),
  pages: uniq(inputs.flatMap(x => x.pages || [])),
  viewports: uniq(inputs.flatMap(x => x.viewports || [])),
  observations: inputs.flatMap(x => x.observations || []),
  samples,
  components: inputs.flatMap(x => x.components || []),
  transformations: inputs.flatMap(x => x.transformations || []),
  visualDnaCandidates: inputs.map(x => x.visualDna || {}).filter(x => Object.keys(x).length),
  gaps: uniq(inputs.flatMap(x => x.gaps || []))
};
fs.writeFileSync(outPath, JSON.stringify(merged,null,2)+'\n');
console.log(outPath);
