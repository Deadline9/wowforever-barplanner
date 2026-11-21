/* Run with jsdom available on NODE_PATH. Optional argument: upstream index.html. */
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { JSDOM, VirtualConsole } = require("jsdom");
const errors = [];
function open(file, storage = {}) {
  const console = new VirtualConsole();
  console.on("jsdomError", e => errors.push(e.message));
  return new JSDOM(fs.readFileSync(file, "utf8"), {
    url: "https://example.invalid/", runScripts: "dangerously", virtualConsole: console,
    beforeParse(w) {
      Object.assign(w, { TextEncoder, TextDecoder, ResizeObserver: class { observe() {} } });
      for (const [k, v] of Object.entries(storage)) w.localStorage.setItem(k, v);
    },
  }).window;
}
const wire = (prefix, ...lines) => prefix + ":" + Buffer.from(lines.join("\n")).toString("base64");
const row = (cmd, ...keys) => ["CMD", "0", cmd, "General", cmd, "binding", ...keys].join("\t");
let legacy, oldStorage;
if (process.argv[2]) {
  const old = open(process.argv[2]);
  old.document.getElementById("example").click();
  legacy = old.document.getElementById("out").value;
  oldStorage = old.localStorage.getItem("barplanner.v3");
  old.close();
}
let w = open("index.html"), el = id => w.document.getElementById(id);
function load(s) {
  el("in").value = s;
  el("load").click();
  assert.equal(el("in").value, "", el("loadMsg").textContent);
}
function plan(...records) { load(wire("BP2", "BARPLAN\t2", "CLASS\tSHAMAN", ...records)); }
function census(...rows) { load(wire("BC1", "BINDCENSUS\t1\t2", ...rows)); }
function check(expected, blocked = false) {
  const text = el("migrationLines").textContent;
  assert.ok(text.includes(expected), text);
  assert.equal(text.includes("BLOCKED:"), blocked, text);
}
assert.ok(el("out").value.startsWith("BP2:"));
if (legacy) {
  load(legacy);
  const payload = s => Buffer.from(s.slice(4), "base64").toString().split("\n").filter(l => !l.startsWith("NAME\t"));
  assert.deepEqual(payload(el("out").value), payload(legacy));
  el("convert").click();
  assert.ok(el("out").value.startsWith("BP2:"));
}
plan("ENSURE\tR\tRUN");
census(row("RUN", "R", "NUMLOCK"));
check("Preserved on RUN: NUMLOCK");
plan("ENSURE\tB\tBUTTON");
census(row("PACK", "B"), row("BUTTON"));
check("Warning: PACK will be unbound.");
census(row("PACK", "B", "CTRL-B"), row("ALLBAGS", "SHIFT-B"), row("ADDON", "F12"));
check("PACK remains on CTRL-B");
assert.ok(!el("migrationLines").textContent.includes("ADDON"));
plan("ENSURE\tB\tBUTTON", "ENSURE\tX\tPACK", "REMOVE\tY\tBUTTON");
census(row("PACK", "B"), row("BUTTON", "Y", "A", "C", "D"));
check("PACK remains on X");
check("Explicit removal: Y");
check("Preserved on BUTTON: A, C, D");
plan("ENSURE\tB\tBUTTON", "ENSURE\tB\tPACK");
check("competing instructions", true);
plan("ENSURE\tB\tBUTTON", "ALLOWORPHAN\tPACK");
census(row("PACK", "B"));
check("Acknowledged by plan.");
census(row("PACK", "B", "X"), "OVERRIDE\tX\tCombatModeSlot1");
check("All remaining keys for PACK have runtime overrides.", true);
plan("ENSURE\tB\tBUTTON", "ENSURE\tF\tBUTTON");
census(row("BUTTON", "B", "F"));
check("Already correct: B");
el("bindOp").value = "REMOVE";
el("opKey").value = "CTRL-B"; el("opCommand").value = "CLICK Foo:LeftButton";
el("addOp").click();
assert.ok(Buffer.from(el("out").value.slice(4), "base64").toString().includes("REMOVE\tCTRL-B\tCLICK Foo:LeftButton"));
const storage = Object.fromEntries(Object.entries(w.localStorage));
w.close(); w = open("index.html", storage);
assert.ok(el("bindingRecords").textContent.includes("CLICK Foo:LeftButton"));
assert.ok(el("bindingStatus").textContent.includes("Character-specific"));
el("bindingRecords").lastElementChild.querySelector("button").click();
assert.ok(!el("bindingRecords").textContent.includes("CLICK Foo:LeftButton"));
if (oldStorage) {
  w.close(); w = open("index.html", {"barplanner.v3": oldStorage});
  assert.ok(el("out").value.startsWith("BP1:"));
  assert.equal(w.localStorage.getItem("barplanner.v3"), oldStorage);
}
w.close();
assert.deepEqual(errors, []);
console.log("Planner import, preview, edit, storage and export passed.");
