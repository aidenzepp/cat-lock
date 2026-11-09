const { execFileSync } = require("child_process");
const path = require("path");
const { environment } = require("@raycast/api");

module.exports.default = function catLock() {
  execFileSync("/usr/bin/open", [path.join(environment.assetsPath, "CatLock.app")]);
};
