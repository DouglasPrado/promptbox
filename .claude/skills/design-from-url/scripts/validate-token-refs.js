#!/usr/bin/env node
const fs = require('fs');
const file = process.argv[2] || 'DESIGN.md';
const text = fs.readFileSync(file,'utf8');
const match = text.match(/^---\s*\n([\s\S]*?)\n---\s*(?:\n|$)/);
if (!match) { console.error('ERROR: missing YAML frontmatter'); process.exit(1); }
const yaml = match[1].split(/\r?\n/);
const roots = new Set(['colors','typography','rounded','spacing','components']);
const paths = new Set();
let stack=[];
for (const line of yaml) {
  if (!line.trim() || /^\s*#/.test(line)) continue;
  const m=line.match(/^(\s*)([A-Za-z0-9_-]+):(?:\s|$)/); if(!m) continue;
  const level=Math.floor(m[1].length/2), key=m[2];
  stack=stack.slice(0,level); stack[level]=key;
  const p=stack.filter(Boolean).join('.'); if(roots.has(stack[0])) paths.add(p);
}
const refs=[...text.matchAll(/\{((?:colors|typography|rounded|spacing|components)\.[A-Za-z0-9_.-]+)\}/g)].map(m=>m[1]);
const unresolved=[...new Set(refs.filter(r=>!paths.has(r)))];
const canonical=['## Overview','## Colors','## Typography','## Layout','## Elevation & Depth','## Shapes','## Components',"## Do's and Don'ts",'## Responsive Behavior','## Iteration Guide','## Known Gaps'];
let prev=-1; const missing=[], order=[];
for(const h of canonical){const i=text.indexOf(h); if(i<0) missing.push(h); else if(i<prev) order.push(h); else prev=i;}
const errors=[];
if(unresolved.length) errors.push(`unresolved token refs: ${unresolved.join(', ')}`);
if(missing.length) errors.push(`missing sections: ${missing.join(', ')}`);
if(order.length) errors.push(`section order errors: ${order.join(', ')}`);
if(/REPLACE_ME|TODO_PLACEHOLDER|<reference-design-analysis>/i.test(text)) errors.push('template placeholders remain');
if(errors.length){for(const e of errors) console.error('ERROR:',e); process.exit(1);}
console.log(`OK: ${refs.length} token references resolved; canonical structure present.`);
