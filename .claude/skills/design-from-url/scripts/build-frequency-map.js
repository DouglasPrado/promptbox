#!/usr/bin/env node
const fs = require('fs');
const [inputPath, outPath] = process.argv.slice(2);
if (!outPath) { console.error('Usage: build-frequency-map.js evidence.json frequencies.json'); process.exit(2); }
const evidence = JSON.parse(fs.readFileSync(inputPath,'utf8'));
const result = {};
for (const [key,values] of Object.entries(evidence.samples || {})) {
  const counts = new Map();
  for (const raw of values || []) {
    const value = typeof raw === 'string' ? raw.trim() : JSON.stringify(raw);
    if (!value) continue;
    counts.set(value,(counts.get(value)||0)+1);
  }
  result[key] = [...counts.entries()].sort((a,b)=>b[1]-a[1] || a[0].localeCompare(b[0])).map(([value,count])=>({value,count}));
}
fs.writeFileSync(outPath,JSON.stringify(result,null,2)+'\n');
console.log(outPath);
