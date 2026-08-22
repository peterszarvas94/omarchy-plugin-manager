# Omarchy Plugin Manager

An Omarchy bar widget for browsing and managing installed shell plugins.

## Features

- Browse built-in and third-party plugins
- Search plugins by name
- Clone built-in plugins using Omarchy's native clone workflow
- Enable and disable plugins
- Remove third-party plugins with confirmation
- Open a plugin's UI or source directory
- Rescan the plugin registry
- Open the plugin directory in a file manager

## Requirements

- Omarchy with the Quattro plugin runtime
- `xdg-open` for opening directories
- `omarchy-launch-config-editor` for opening plugin source directories

The plugin runs inside the existing `omarchy-shell` process. It does not install services,
require elevated privileges, or make network requests. Plugin enable, disable, and removal
actions invoke Omarchy's `omarchy-plugin-*` commands with the current user's permissions.
It must not be launched as a separate Quickshell process.

## Install

Install and enable the plugin from its public repository:

```sh
omarchy plugin add https://github.com/peterszarvas94/omarchy-plugin-manager.git --enable
```

Place the widget in the right side of the bar (the default):

```sh
omarchy bar move io.github.peterszarvas94.plugin-manager --section right
```

If the bar does not update immediately, rescan the plugin registry:

```sh
omarchy-shell shell rescanPlugins
```

## Usage

Click the plugin icon in the bar, or open the manager through shell IPC:

```sh
omarchy-shell shell summon io.github.peterszarvas94.plugin-manager '{}'
```

Use the search field to filter plugins. Use arrow keys to navigate, `/` to focus search,
and Escape to close.

To add an optional keyboard shortcut on a stock Omarchy installation, add this to
`~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + CTRL + SHIFT + M", "Plugin Manager", "omarchy-shell shell summon io.github.peterszarvas94.plugin-manager '{}'")
```

This combination is not used by Omarchy's stock bindings. The plugin does not
install or overwrite keybindings automatically.

The manager can open the UI of enabled `bar-widget`, `panel`, `overlay`, and `menu` plugins.
Built-in plugins can be cloned with the first action button. Omarchy generates the clone ID
and display name. Built-in plugins cannot be removed. Every discovered plugin has an enable/disable toggle;
the manager must be re-enabled from the shell if it is disabled.

## Optional Application Launcher Entry

The repository includes `io.github.peterszarvas94.plugin-manager.desktop`. Install it for an application-launcher entry:

```sh
install -Dm644 io.github.peterszarvas94.plugin-manager.desktop \
  ~/.local/share/applications/io.github.peterszar94.plugin-manager.desktop
```

The desktop entry launches the same shell IPC command as the bar widget.

## Configuration

The plugin has no separate configuration file. Configure its bar position using Omarchy's bar
command:

```sh
omarchy bar move io.github.peterszarvas94.plugin-manager --section left
omarchy bar move io.github.peterszarvas94.plugin-manager --section center
omarchy bar move io.github.peterszarvas94.plugin-manager --section right
```

The plugin always discovers plugins from Omarchy's standard directory:
`~/.config/omarchy/plugins`.

The manifest declares one `bar-widget` kind. `SettingsWidget.qml` is the bar entry point and
loads `Panel.qml` internally; `Panel.qml` is not a separate manifest entry point.

## Remove

Disable and remove the plugin using its manifest ID:

```sh
omarchy plugin disable io.github.peterszarvas94.plugin-manager
omarchy plugin remove io.github.peterszar94.plugin-manager
rm -f ~/.local/share/applications/io.github.peterszar94.plugin-manager.desktop
```

The final command is only needed if the optional desktop entry was installed.

## Development and Validation

Copy or clone this repository into the user plugin directory. Plugin folders must be real
directories rather than symlinks when running the validator:

```sh
PLUGIN_DIR="$HOME/.config/omarchy/plugins/io.github.peterszar94.plugin-manager"
mkdir -p "$HOME/.config/omarchy/plugins"
cp -a . "$PLUGIN_DIR"
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.peterszar94.plugin-manager --section right
```

Validate the manifest, QML files, and desktop entry from the repository root:

```sh
omarchy plugin validate .
qmllint -I "${OMARCHY_PATH:-/usr/share/omarchy}/shell" \
  Panel.qml SettingsWidget.qml
desktop-file-validate io.github.peterszarvas94.plugin-manager.desktop
```

Before publishing, test opening and closing the panel, rescanning, enabling, disabling,
removing, restarting the shell, and reinstalling the plugin.

Inspect the discovered plugin and its enabled state with:

```sh
omarchy plugin list --json \
  | jq '.[] | select(.id == "io.github.peterszar94.plugin-manager")'
```

## Troubleshooting

If the plugin is not listed after installation, rescan and inspect the manifest:

```sh
omarchy-shell shell rescanPlugins
omarchy plugin validate "$HOME/.config/omarchy/plugins/io.github.peterszar94.plugin-manager"
omarchy plugin list --json
```

If it is listed but does not appear in the bar, enable it and confirm its placement:

```sh
omarchy plugin enable io.github.peterszar94.plugin-manager --section right
omarchy bar move io.github.peterszar94.plugin-manager --section right
```

For QML loading errors, inspect the shell log:

```sh
qs log -p "${OMARCHY_PATH:-/usr/share/omarchy}/shell" --tail 100
```

If the panel opens only once, restart the shell and confirm that `SettingsWidget.qml` still
forwards `open()`, `close()`, and `opened` to the loaded panel.

## License

MIT. See [LICENSE](LICENSE).
