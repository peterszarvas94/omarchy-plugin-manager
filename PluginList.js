.pragma library

var SELF_ID = "io.github.peterszarvas94.plugin-manager"
var UI_KINDS = ["bar-widget", "panel", "overlay", "menu"]

// Turns the output of `omarchy-plugin-list --json` into the rows the panel
// shows. Returns null when the output is not a plugin list, so a failed read
// can be told apart from an empty one. The shell's list does not say where a
// plugin lives, but a third-party plugin is always in the user plugin directory.
function parse(text, userPluginsDir) {
  var listed
  try {
    listed = JSON.parse(text)
  } catch (e) {
    return null
  }
  if (!Array.isArray(listed)) return null

  var rows = []
  for (var i = 0; i < listed.length; i++) {
    var entry = listed[i]
    if (!entry || typeof entry.id !== "string" || entry.id === "") continue
    var kinds = Array.isArray(entry.kinds)
      ? entry.kinds.filter(function(kind) { return typeof kind === "string" }) : []
    var firstParty = entry.firstParty === true
    var isSelf = entry.id === SELF_ID
    rows.push({
      id: entry.id,
      name: typeof entry.name === "string" && entry.name !== "" ? entry.name : entry.id,
      sourceDir: firstParty ? "" : userPluginsDir + "/" + entry.id,
      kinds: kinds,
      firstParty: firstParty,
      enabled: entry.enabled === true,
      canDisable: entry.canDisable === true,
      canFolder: !firstParty,
      canClone: firstParty,
      canRemove: !firstParty && !isSelf,
      canOpen: !isSelf && kinds.some(function(kind) { return UI_KINDS.indexOf(kind) !== -1 })
    })
  }
  rows.sort(function(a, b) { return a.name.localeCompare(b.name) })
  return rows
}
