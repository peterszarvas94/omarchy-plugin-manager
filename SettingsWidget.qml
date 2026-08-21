import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.peterszarvas94.plugin-manager"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing : false
  readonly property string stateFile: Quickshell.env("XDG_RUNTIME_DIR")
    + "/io.github.peterszarvas94.plugin-manager-state.json"

  function injectPanel() {
    var panel = panelLoader.item
    if (!panel || !root.bar) return
    panel.bar = root.bar
    panel.anchorItem = button
    panel.hostWidget = root
    panel.shell = root.bar.shell
    panel.pluginRegistry = root.bar.shell ? root.bar.shell.pluginRegistry : null
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰐱"
    tooltipText: "Plugin Manager"
    onPressed: root.toggle()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  onBarChanged: root.injectPanel()

  FileView {
    path: root.stateFile
    watchChanges: true
    printErrors: false
    onLoaded: root.openPendingState()
  }

  function openPendingState() {
    if (!panelLoader.item) {
      Qt.callLater(root.openPendingState)
      return
    }
    if (panelLoader.item.restoringState) return
    if (pendingStateProbe.running) return
    pendingStateProbe.running = true
  }

  Process {
    id: pendingStateProbe
    command: ["bash", "-c", "jq -e '.ready == true' \"$1\" >/dev/null 2>&1", "plugin-manager-state", root.stateFile]
    onExited: if (exitCode === 0 && panelLoader.item) panelLoader.item.open()
  }
}
