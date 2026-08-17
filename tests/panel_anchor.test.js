const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const panel = fs.readFileSync(path.join(__dirname, "..", "Panel.qml"), "utf8");

assert.match(panel, /anchorItem:\s*root\.anchorItem/);
assert.doesNotMatch(panel, /centerOnBar:\s*true/);

console.log("Panel anchor test passed");
