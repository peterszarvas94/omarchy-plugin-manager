import QtQuick 2.15
import QtTest 1.3
import "../PluginList.js" as PluginList

TestCase {
  name: "PluginList"

  function row(rows, id) {
    return rows.filter(function(r) { return r.id === id })[0]
  }

  function test_failed_read_is_not_an_empty_list() {
    compare(PluginList.parse("", "/p"), null)
    compare(PluginList.parse("not json", "/p"), null)
    compare(PluginList.parse("{}", "/p"), null)
    compare(PluginList.parse("[]", "/p").length, 0)
  }

  function test_sorted_by_name() {
    var rows = PluginList.parse(JSON.stringify([
      { id: "b", name: "Beta", kinds: [] },
      { id: "a", name: "Alpha", kinds: [] }
    ]), "/p")
    compare(rows[0].id, "a")
    compare(rows[1].id, "b")
  }

  function test_first_party_can_clone_but_not_remove() {
    var plugin = PluginList.parse(JSON.stringify([
      { id: "omarchy.audio", name: "Audio", kinds: ["bar-widget"], enabled: true, canDisable: true, firstParty: true }
    ]), "/p")[0]
    compare(plugin.canClone, true)
    compare(plugin.canRemove, false)
    compare(plugin.canFolder, false)
    compare(plugin.canOpen, true)
    compare(plugin.enabled, true)
    compare(plugin.canDisable, true)
  }

  function test_third_party_lives_in_user_dir() {
    var plugin = PluginList.parse(JSON.stringify([
      { id: "x.y", name: "Y", kinds: ["service"], enabled: false, canDisable: true, firstParty: false }
    ]), "/p")[0]
    compare(plugin.sourceDir, "/p/x.y")
    compare(plugin.canRemove, true)
    compare(plugin.canClone, false)
    compare(plugin.canOpen, false)
  }

  function test_manager_cannot_remove_or_open_itself() {
    var plugin = PluginList.parse(JSON.stringify([
      { id: PluginList.SELF_ID, name: "Plugin Manager", kinds: ["bar-widget"], firstParty: false }
    ]), "/p")[0]
    compare(plugin.canRemove, false)
    compare(plugin.canOpen, false)
  }

  function test_malformed_entries_are_tolerated() {
    var rows = PluginList.parse(JSON.stringify([
      null, {}, { id: 3 }, { id: "ok", name: 7, kinds: "panel" }
    ]), "/p")
    compare(rows.length, 1)
    compare(row(rows, "ok").name, "ok")
    compare(row(rows, "ok").kinds.length, 0)
  }
}
