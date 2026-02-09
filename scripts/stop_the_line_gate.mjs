import fs from "node:fs";

function fail(msg){ console.error(msg); process.exit(1); }
function ok(msg){ console.log(msg); process.exit(0); }

const pr = process.env.PR_NUMBER || "";
const sim = process.env.SIMULATE_FAILURE_CLASS || ""; // proof-only
const classKey = sim || ""; // CI discovery added in next step

if(!pr) fail("STOP_THE_LINE FAIL: PR_NUMBER missing");
if(!classKey) ok("STOP_THE_LINE PASS: no stop-the-line condition (no failing class detected)");

console.log("STOP_THE_LINE class=" + classKey);

const waiverPath = `docs/waivers/WAIVER_PR${pr}.md`;
const incidentsPath = `docs/threats/INCIDENTS.md`;

const waiverExists = fs.existsSync(waiverPath);
const incidentText = fs.existsSync(incidentsPath) ? fs.readFileSync(incidentsPath,"utf8") : "";
const incidentExists = incidentText.includes(`PR: ${pr}`) && incidentText.includes(`FailureClass: ${classKey}`);

if(waiverExists && incidentExists) fail("STOP_THE_LINE FAIL: both INCIDENT and WAIVER exist (mutual exclusivity)");
if(!waiverExists && !incidentExists) fail("STOP_THE_LINE FAIL: missing acknowledgment. Add INCIDENT (PR: N, FailureClass: KEY) OR waiver file with exact text 'QA: NOT AN INCIDENT'.");

if(waiverExists){
  const w = fs.readFileSync(waiverPath,"utf8");
  if(!w.includes("QA: NOT AN INCIDENT")) fail("STOP_THE_LINE FAIL: waiver missing exact text: QA: NOT AN INCIDENT");
  ok("STOP_THE_LINE PASS: waiver present");
}
ok("STOP_THE_LINE PASS: incident present");