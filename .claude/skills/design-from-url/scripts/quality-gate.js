#!/usr/bin/env node
const fs = require('fs');
const [designPath='DESIGN.md', evidencePath, critiquePath] = process.argv.slice(2);
function readJson(p,required=true){ if(!p || !fs.existsSync(p)){ if(required) throw new Error(`missing required JSON: ${p||'(not provided)'}`); return null;} return JSON.parse(fs.readFileSync(p,'utf8')); }
const design=fs.readFileSync(designPath,'utf8');
const evidence=readJson(evidencePath);
const critique=readJson(critiquePath,false)||{findings:[]};
const failures=[], warnings=[];
const sections=['## Overview','## Colors','## Typography','## Layout','## Elevation & Depth','## Shapes','## Components',"## Do's and Don'ts",'## Responsive Behavior','## Iteration Guide','## Known Gaps'];
for(const h of sections) if(!design.includes(h)) failures.push(`missing ${h}`);
if(!/Source pages:/i.test(design)) failures.push('Overview does not list Source pages');
if(/modern[, ]+clean|clean[, ]+modern|professional and modern/i.test(design)) warnings.push('generic design language detected; verify it is made concrete');
if((evidence.pages||[]).length<1) failures.push('evidence has no inspected pages');
if((evidence.observations||[]).length<8) warnings.push('very small evidence ledger; inspect coverage');
if(!(evidence.visualDnaCandidates||[]).length) failures.push('no Visual DNA evidence');
const known=(design.match(/## Known Gaps[\s\S]*$/)?.[0]||'');
if(evidence.browserAvailable!==true && !/browser|render|screenshot|visual inspection/i.test(known)) failures.push('browser unavailable but Known Gaps does not disclose degraded visual evidence');
const blockers=(critique.findings||[]).filter(f=>f.severity==='blocker');
if(blockers.length) failures.push(`${blockers.length} unresolved critique blocker(s)`);
if(critique.generativeCoherence && critique.generativeCoherence.pass===false) failures.push('critic failed generative coherence test');
console.log(JSON.stringify({pass:failures.length===0,failures,warnings},null,2));
process.exit(failures.length?1:0);
