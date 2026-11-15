const wcmatch = require("./vendor/wildcard-match");
const cache = new Map();

function compile(pattern) {
  let isMatch = cache.get(pattern);
  if (!isMatch) {
    isMatch = wcmatch(pattern.trim(), { separator: " " });
    cache.set(pattern, isMatch);
  }
  return isMatch;
}

function firstMatch(list, subject) {
  for (const [pattern, entry] of Object.entries(list)) {
    if (compile(pattern)(subject)) return { pattern, entry };
  }
  return null;
}

function listBinaries(list) {
  const names = new Set();
  for (const pattern of Object.keys(list)) {
    const first = pattern.trim().split(/\s+/)[0];
    if (first && !first.includes("*")) names.add(first);
  }
  return [...names];
}

module.exports = { compile, firstMatch, listBinaries };