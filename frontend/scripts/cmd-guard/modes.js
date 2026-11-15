const fs = require("fs");
const path = require("path");
const { loadRules, maybeLogSource } = require("./rules");
const { firstMatch, listBinaries } = require("./matcher");

function printBlock(subject, entry) {
  const bin = subject.split(" ")[0];
  console.error("");
  console.error(`Blocked: ${subject}`);
  if (entry.reason) console.error(`  Reason:      ${entry.reason.replace(/\$1/g, bin)}`);
  if (entry.alternate) console.error(`  Use instead: ${entry.alternate.replace(/\$1/g, bin)}`);
  console.error("");
}

function runArgs(cmd, args) {
  const { list, source } = loadRules();
  maybeLogSource(list, source);
  const subject = [cmd, ...args].join(" ").trim();
  const hit = firstMatch(list, subject);
  if (!hit || hit.entry.allowed) process.exit(0);
  printBlock(subject, hit.entry);
  process.exit(1);
}

const INSTALL_FORM = "yarn expo install";

function runPreinstall() {
  const { list, source } = loadRules();
  maybeLogSource(list, source);
  let pkg;
  try {
    pkg = JSON.parse(fs.readFileSync(path.join(process.cwd(), "package.json"), "utf8"));
  } catch (e) {
    process.exit(0);
  }
  const deps = Object.keys({ ...pkg.dependencies, ...pkg.devDependencies });
  const hits = [];
  for (const dep of deps) {
    const hit = firstMatch(list, `${INSTALL_FORM} ${dep}`);
    if (hit && !hit.entry.allowed) hits.push({ dep, entry: hit.entry });
  }
  if (hits.length === 0) process.exit(0);
  console.error("Disallowed packages found in package.json");
  process.exit(1);
}

function runListCommands() {
  const { list } = loadRules();
  for (const name of listBinaries(list)) console.log(name);
  process.exit(0);
}

module.exports = { runArgs, runPreinstall, runListCommands };