import QtQuick 2.15
import QtTest 1.3

TestCase {
  name: "PluginSearch"

  Item {
    id: fixture
    width: 400
    height: 200

    property var plugins: [
      { name: "Alpha", id: "plugin.alpha" },
      { name: "Beta", id: "plugin.beta" },
      { name: "Gamma", id: "plugin.gamma" }
    ]
    property string searchQuery: ""

    ListModel { id: displayedPlugins }

    TextInput {
      id: searchField
      onTextChanged: {
        Qt.callLater(function() { fixture.updateSearch(searchField.text) })
      }
    }

    function updateSearch(text) {
      fixture.searchQuery = text.trim().toLowerCase()
      displayedPlugins.clear()
      for (var i = 0; i < fixture.plugins.length; i++) {
        var plugin = fixture.plugins[i]
        if (!fixture.searchQuery
            || plugin.name.toLowerCase().indexOf(fixture.searchQuery) !== -1
            || plugin.id.toLowerCase().indexOf(fixture.searchQuery) !== -1) {
          displayedPlugins.append({ pluginIndex: i })
        }
      }
    }

    Repeater {
      model: displayedPlugins
      Item { required property int pluginIndex }
    }
  }

  function test_match_no_match_clear() {
    searchField.text = "a"
    tryCompare(displayedPlugins, "count", 3)

    searchField.text = "aqdsdqfqd"
    tryCompare(displayedPlugins, "count", 0)

    searchField.text = ""
    tryCompare(displayedPlugins, "count", 3)
  }
}
