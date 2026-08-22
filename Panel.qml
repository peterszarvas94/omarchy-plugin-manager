import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.peterszarvas94.plugin-manager"
  ipcTarget: ""
  manageIpc: false

  property Item anchorItem: null
  property Item hostWidget: null
  property var shell: null
  property var pluginRegistry: null
  property var plugins: []
  property string searchQuery: ""
  property string pendingRemoveId: ""
  property int selectedRow: 0
  property int selectedButton: 0
  property bool cursorActive: false

  readonly property color foreground: Color.foreground
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property string fontFamily: Style.font.family

  function open() {
    searchQuery = ""
    selectedRow = 0
    selectedButton = 0
    cursorActive = false
    if (searchField) searchField.text = ""
    if (pluginRegistry) {
      pluginRegistry.rescan()
      registryRefresh.restart()
    }
    refreshPlugins()
    root.controller.show()
    Qt.callLater(function() { if (searchField) searchField.forceActiveFocus() })
  }

  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.open() }
  function closeForPopoutSwitch() { root.close() }

  function requestClose() {
    if (hostWidget && hostWidget.bar && hostWidget.bar.shell)
      hostWidget.bar.shell.hide("io.github.peterszarvas94.plugin-manager")
    else root.close()
  }

  function runPluginAction(plugin, action) {
    if (!plugin) return
    var script = [
      "set -u",
      "action=\"$1\"; plugin_id=\"$2\"; is_bar=\"$3\"",
      "status=0",
      "case \"$action\" in",
      "  disable) omarchy-plugin-disable \"$plugin_id\" >/dev/null 2>&1 || status=$? ;;",
      "  enable) if [[ \"$is_bar\" == 1 ]]; then omarchy-plugin-enable \"$plugin_id\" --section right >/dev/null 2>&1 || status=$?; else omarchy-plugin-enable \"$plugin_id\" >/dev/null 2>&1 || status=$?; fi ;;",
      "  clone) source_location=$(omarchy-shell shell listShellConfig 2>/dev/null | jq -r --arg id \"$plugin_id\" 'first([\"left\",\"center\",\"right\"][] as $section | ((.bar.layout[$section] // []) | to_entries[]) | select((.value.id // .value) == $id) | \"\\($section):\\(.key)\") // \"\"' 2>/dev/null || true); omarchy-plugin-clone \"$plugin_id\" >/dev/null 2>&1 || status=$?; if [[ $status -eq 0 && -n \"$source_location\" ]]; then new_id=\"${USER}.${plugin_id#omarchy.}\"; source_section=\"${source_location%%:*}\"; source_index=\"${source_location##*:}\"; omarchy bar move \"$new_id\" --section \"$source_section\" --index \"$source_index\" >/dev/null 2>&1 || true; fi ;;",
      "  remove) omarchy-plugin-remove \"$plugin_id\" --yes >/dev/null 2>&1 || status=$? ;;",
      "esac",
      "exit $status"
    ].join("\n")
    root.close()
    Quickshell.execDetached(["bash", "-c", script, "plugin-manager-action",
      action, plugin.id,
      plugin.kinds.indexOf("bar-widget") !== -1 ? "1" : "0"])
  }

  function moveTabCursor(direction) {
    var rows = filteredPlugins()
    if (rows.length === 0) return

    if (!cursorActive) {
      if (direction > 0) setCursor(0, 0)
      else searchField.forceActiveFocus()
      return
    }

    if (direction > 0) {
      if (selectedButton < actionCount(rows[selectedRow]) - 1) selectedButton++
      else if (selectedRow === rows.length - 1) {
        cursorActive = false
        searchField.forceActiveFocus()
        return
      }
      else {
        selectedRow++
        selectedButton = 0
      }
    } else if (selectedRow === 0 && selectedButton === 0) {
      cursorActive = false
      searchField.forceActiveFocus()
      return
    } else if (selectedButton > 0) {
      selectedButton--
    } else {
      selectedRow = (selectedRow - 1 + rows.length) % rows.length
      selectedButton = actionCount(rows[selectedRow]) - 1
    }
    cursorActive = true
  }

  function refreshPlugins() {
    if (!pluginRegistry) return
    var next = []
    var installed = pluginRegistry.installedPlugins || {}
    for (var id in installed) {
      var manifest = installed[id]
      if (!manifest) continue
      var kinds = manifest.kinds || []
      var isBarWidget = kinds.indexOf("bar-widget") !== -1
      next.push({
        id: String(manifest.id || id),
        name: String(manifest.name || id),
        sourceDir: String(manifest.__sourceDir || ""),
        kinds: kinds,
        firstParty: manifest.__isFirstParty === true,
        enabled: isBarWidget ? pluginRegistry.inBar(id) : pluginRegistry.isEnabled(id),
        canDisable: true,
        canFolder: String(manifest.__sourceDir || "") !== "",
        canClone: manifest.__isFirstParty === true && id !== "io.github.peterszarvas94.plugin-manager",
        canRemove: manifest.__isFirstParty !== true && id !== "io.github.peterszarvas94.plugin-manager",
        canOpen: id !== "io.github.peterszarvas94.plugin-manager" && (manifest.kinds || []).some(function(kind) {
          return ["bar-widget", "panel", "overlay", "menu"].indexOf(kind) !== -1
        })
      })
    }
    next.sort(function(a, b) { return a.name.localeCompare(b.name) })
    plugins = next
    updateDisplayedPlugins()
  }

  function togglePlugin(plugin) {
    if (!plugin || !plugin.canDisable) return
    runPluginAction(plugin, plugin.enabled ? "disable" : "enable")
  }

  function askRemove(plugin) {
    if (!plugin || !plugin.canRemove) return
    pendingRemoveId = plugin.id
    confirmDialog.message = "Remove plugin '" + escapeText(plugin.name) + "'?"
    confirmDialog.opened = true
  }

  function clonePlugin(plugin) {
    if (!plugin || !plugin.canClone) return
    runPluginAction(plugin, "clone")
  }

  function confirmAction() {
    confirmDialog.opened = false
    var plugin = null
    for (var i = 0; i < plugins.length; i++) {
      if (plugins[i].id === pendingRemoveId) {
        plugin = plugins[i]
        break
      }
    }
    pendingRemoveId = ""
    if (plugin && plugin.canRemove) {
      runPluginAction(plugin, "remove")
    }
  }

  function cancelAction() {
    pendingRemoveId = ""
    confirmDialog.opened = false
  }

  function escapeText(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&apos;")
  }

  function filteredPlugins() {
    var query = searchQuery.toLowerCase()
    if (!query) return plugins
    return plugins.filter(function(plugin) {
      return pluginMatches(plugin, query)
    })
  }

  function pluginMatches(plugin, query) {
    return plugin.name.toLowerCase().indexOf(query) !== -1
      || plugin.id.toLowerCase().indexOf(query) !== -1
  }

  function updateDisplayedPlugins(query) {
    displayedPluginModel.clear()
    query = query === undefined ? searchQuery.toLowerCase() : query
    for (var i = 0; i < plugins.length; i++) {
      if (!query || pluginMatches(plugins[i], query))
        displayedPluginModel.append({ pluginIndex: i })
    }
  }

  function actionCount(plugin) {
    return actionNames(plugin).length
  }

  function actionNames(plugin) {
    if (!plugin) return []
    var actions = []
    if (plugin.canClone) actions.push("clone")
    if (plugin.canRemove) actions.push("remove")
    if (plugin.canOpen && plugin.enabled) actions.push("open")
    if (plugin.canFolder) actions.push("folder")
    if (plugin.canDisable) actions.push("toggle")
    return actions
  }

  function actionIndex(plugin, action) {
    return actionNames(plugin).indexOf(action)
  }

  function clampCursor() {
    var rows = filteredPlugins()
    if (rows.length === 0) {
      selectedRow = 0
      selectedButton = 0
      return
    }
    selectedRow = Math.max(0, Math.min(selectedRow, rows.length - 1))
    selectedButton = Math.max(0, Math.min(selectedButton, actionCount(rows[selectedRow]) - 1))
  }

  function setCursor(row, button) {
    cursorActive = true
    selectedRow = row
    selectedButton = button
    clampCursor()
  }

  function moveCursor(dx, dy) {
    var rows = filteredPlugins()
    if (rows.length === 0) return
    if (!cursorActive) {
      setCursor(0, 0)
      return
    }
    if (dy !== 0) {
      if (dy < 0 && selectedRow === 0) {
        cursorActive = false
        searchField.forceActiveFocus()
        return
      }
      if (dy > 0 && selectedRow === rows.length - 1) {
        cursorActive = false
        searchField.forceActiveFocus()
        return
      }
      selectedRow = Math.max(0, Math.min(rows.length - 1, selectedRow + dy))
      selectedButton = Math.min(selectedButton, actionCount(rows[selectedRow]) - 1)
    } else if (dx !== 0) {
      selectedButton = Math.max(0, Math.min(actionCount(rows[selectedRow]) - 1, selectedButton + dx))
    }
    cursorActive = true
  }

  function activateCursor() {
    var plugin = filteredPlugins()[selectedRow]
    if (!plugin) return
    var action = actionNames(plugin)[selectedButton]
    if (action === "open") openPlugin(plugin)
    else if (action === "clone") clonePlugin(plugin)
    else if (action === "toggle") togglePlugin(plugin)
    else if (action === "folder") openPluginFolder(plugin)
    else if (action === "remove") askRemove(plugin)
  }

  function ensureCursorVisible(item) {
    if (!item || !scrollArea) return
    var flick = scrollArea.contentItem
    var point = item.mapToItem(flick.contentItem || flick, 0, 0)
    var top = point.y
    var bottom = top + item.height
    if (top < flick.contentY) flick.contentY = Math.max(0, top - Style.space(8))
    else if (bottom > flick.contentY + flick.height)
      flick.contentY = bottom - flick.height + Style.space(8)
  }

  function openPlugin(plugin) {
    if (!plugin || !plugin.canOpen || !plugin.enabled || !shell) return
    root.close()
    Qt.callLater(function() { shell.summon(plugin.id, "{}") })
  }

  function openPluginFolder(plugin) {
    if (!plugin || !plugin.canFolder) return
    root.close()
    Qt.callLater(function() {
      Quickshell.execDetached(["omarchy-launch-config-editor", plugin.sourceDir])
    })
  }

  Connections {
    target: root.pluginRegistry
    function onRegistryRevisionChanged() {
      root.refreshPlugins()
      registryRefresh.restart()
    }
  }

  ListModel {
    id: displayedPluginModel
  }

  Timer {
    id: registryRefresh
    interval: 250
    repeat: false
    onTriggered: root.refreshPlugins()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(760))
    contentHeight: panel.fittedContentHeight(plugContent.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: searchField.activeFocus || confirmDialog.opened
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.requestClose()
      onTabRequested: function(direction) { root.moveTabCursor(direction) }
      onTextKey: function(t) {
        if (t === "/") {
          cursorActive = false
          searchField.forceActiveFocus()
          searchField.selectAll()
        }
      }

      ColumnLayout {
        id: plugContent
        anchors.fill: parent
        spacing: Style.space(12)

        PanelHero {
          Layout.fillWidth: true
          title: "Plugin Manager"
          meta: root.plugins.length + " plugins"
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              text: "󰐱"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          TextField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: "Type something to search"
            foreground: root.foreground
            accent: root.accent
            font.family: root.fontFamily
            onTextChanged: Qt.callLater(function() {
              var query = searchField.text.trim().toLowerCase()
              root.searchQuery = query
              root.updateDisplayedPlugins(query)
              root.clampCursor()
            })
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                root.requestClose()
                event.accepted = true
              } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                var direction = (event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab ? -1 : 1
                if (direction < 0 && !root.cursorActive) {
                  var rows = root.filteredPlugins()
                  if (rows.length > 0) {
                    var lastRow = rows.length - 1
                    root.setCursor(lastRow, root.actionCount(rows[lastRow]) - 1)
                  }
                } else {
                  root.moveTabCursor(direction)
                }
                if (root.cursorActive) keyCatcher.forceActiveFocus()
                event.accepted = true
              } else if (event.key === Qt.Key_Down) {
                root.setCursor(0, 0)
                keyCatcher.forceActiveFocus()
                event.accepted = true
              } else if (event.key === Qt.Key_Up) {
                var rows = root.filteredPlugins()
                if (rows.length > 0) {
                  var lastRow = rows.length - 1
                  root.setCursor(lastRow, root.actionCount(rows[lastRow]) - 1)
                  keyCatcher.forceActiveFocus()
                  event.accepted = true
                }
              }
            }
          }
        }

        Text {
          text: "Arrow keys or Tab navigate, / searches, and Esc closes."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        PanelSeparator {
          Layout.fillWidth: true
          foreground: root.foreground
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

            PanelSectionHeader {
              text: "INSTALLED PLUGINS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
        }

        ScrollView {
          id: scrollArea
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

          Column {
            width: scrollArea.width
            spacing: Style.space(8)

            Repeater {
              model: displayedPluginModel
              PluginRow {
                required property int index
                required property int pluginIndex
                width: parent.width
                plugin: root.plugins[pluginIndex]
                rowIndex: index
              }
            }
          }
        }
      }

      ConfirmDialog {
        id: confirmDialog
        anchors.fill: parent
        foreground: root.foreground
        fontFamily: root.fontFamily
        focus: opened
        onOpenedChanged: if (opened) forceActiveFocus()
        Keys.onPressed: function(event) {
          if (handleKey(event)) event.accepted = true
        }
        onConfirmed: root.confirmAction()
        onCanceled: root.cancelAction()
      }
    }
  }

  component PluginRow: CursorSurface {
    required property var plugin
    required property int rowIndex
    readonly property bool rowSelected: root.cursorActive && root.selectedRow === rowIndex
    hasCursor: rowSelected
    foreground: root.foreground
    implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX

    onRowSelectedChanged: if (rowSelected) root.ensureCursorVisible(this)

    RowLayout {
      id: rowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      Text {
        text: "󰐱"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        Layout.preferredWidth: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          text: plugin.name
          textFormat: Text.PlainText
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
        Text {
          text: plugin.id + " · " + (plugin.firstParty ? "Built-in" : "Third-party")
            + " · " + plugin.kinds.join(", ")
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }

      PanelActionButton {
        visible: plugin.canClone
        iconText: ""
        tooltipText: "Clone plugin"
        foreground: root.foreground
        fontFamily: root.fontFamily
        hasCursor: rowSelected && root.selectedButton === root.actionIndex(plugin, "clone")
        onHovered: function(on) {
          if (on) root.setCursor(rowIndex, root.actionIndex(plugin, "clone"))
        }
        onClicked: root.clonePlugin(plugin)
      }

      PanelActionButton {
        visible: plugin.canRemove
        iconText: ""
        tooltipText: "Remove"
        foreground: root.foreground
        fontFamily: root.fontFamily
        hasCursor: rowSelected && root.selectedButton === root.actionIndex(plugin, "remove")
        onHovered: function(on) {
          if (on) root.setCursor(rowIndex, root.actionIndex(plugin, "remove"))
        }
        onClicked: root.askRemove(plugin)
      }

      PanelActionButton {
        visible: plugin.canOpen && plugin.enabled
        iconText: "\uead3"
        tooltipText: "Open"
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: plugin.enabled
        hasCursor: rowSelected && root.selectedButton === root.actionIndex(plugin, "open")
        onHovered: function(on) {
          if (on) root.setCursor(rowIndex, root.actionIndex(plugin, "open"))
        }
        onClicked: root.openPlugin(plugin)
      }

      PanelActionButton {
        visible: plugin.canFolder
        iconText: ""
        tooltipText: "Open plugin folder"
        foreground: root.foreground
        fontFamily: root.fontFamily
        hasCursor: rowSelected && root.selectedButton === root.actionIndex(plugin, "folder")
        onHovered: function(on) {
          if (on) root.setCursor(rowIndex, root.actionIndex(plugin, "folder"))
        }
        onClicked: root.openPluginFolder(plugin)
      }

      ToggleSwitch {
        visible: plugin.canDisable
        checked: plugin.enabled
        busy: false
        cursorRing: true
        cursorPad: Style.space(3)
        foreground: root.foreground
        accent: root.accent
        hasCursor: rowSelected && root.selectedButton === root.actionIndex(plugin, "toggle")
        onHovered: function(on) {
          if (on) root.setCursor(rowIndex, root.actionIndex(plugin, "toggle"))
        }
        onToggled: root.togglePlugin(plugin)
      }
    }
  }
}
