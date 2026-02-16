import fs from "node:fs";
import { detectFoundationDriftClass } from "./foundation_drift_detector.mjs";
function fail(m){console.error(m);process.exit(1)} function ok(m){console.log(m);process.exit(0)}
const pr=process.env.PR_NUMBER||""; const sha=process.env.PR_HEAD_SHA||""; const sim=process.env.SIMULATE_FAILURE_CLASS||"";
const classKey=sim||detectFoundationDriftClass(); const trig=Boolean(classKey);
if(!pr) fail("STOP_THE_LINE_XOR FAIL: PR_NUMBER missing");
console.log("PR_NUMBER="+pr); console.log("STOP_THE_LINE_TRIGGERED="+(trig?"true":"false"));
if(!trig){ console.log("INCIDENT_DETECTED=false"); console.log("WAIVER_DETECTED=false"); console.log("XOR_RESULT=PASS"); ok("STOP_THE_LINE_XOR PASS: not triggered"); }
console.log("STOP_THE_LINE_CLASS="+classKey);
const it=fs.existsSync("docs/threats/INCIDENTS.md")?fs.readFileSync("docs/threats/INCIDENTS.md","utf8"):"";
const inc=it.includes(`PR: ${pr}`)||(sha && it.includes(sha));
let w=false; try{ w=fs.existsSync(`docs/waivers/WAIVER_PR${pr}.md`);}catch(e){w=false}
console.log("INCIDENT_DETECTED="+(inc?"true":"false")); console.log("WAIVER_DETECTED="+(w?"true":"false"));
if(w && inc){ console.log("XOR_RESULT=FAIL"); fail("STOP_THE_LINE_XOR FAIL: both INCIDENT and WAIVER exist"); }
if(w){ console.log("XOR_RESULT=FAIL"); fail("STOP_THE_LINE_XOR FAIL: waiver present but operator decision is INCIDENT"); }
if(!inc){ console.log("XOR_RESULT=FAIL"); fail("STOP_THE_LINE_XOR FAIL: missing INCIDENT entry tied to PR number or PR HEAD SHA"); }
console.log("XOR_RESULT=PASS"); ok("STOP_THE_LINE_XOR PASS: incident present and waiver absent");