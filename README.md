# Omarchy Plugin Manager

The first slice of a themed Omarchy plugin manager.

Current features:

- Browse installed, built-in, and third-party plugins
- Enable and disable plugins
- Remove third-party plugins, with confirmation
- Search plugins as you type
- Open UI plugins directly from their rows
- Rescan plugin directories
- Open `~/.config/omarchy/plugins`
- Launch from the bar cog, app launcher, or shell IPC

## Local development

```bash
mkdir -p ~/.config/omarchy/plugins
ln -sfn ~/Projects/omarchy-settings ~/.config/omarchy/plugins/peti.plugins
omarchy-shell shell rescanPlugins
omarchy plugin enable peti.plugins --section right
mkdir -p ~/.local/share/applications
ln -sfn ~/Projects/omarchy-settings/peti.plugins.desktop ~/.local/share/applications/peti.plugins.desktop
```

Open it with:

```bash
omarchy-shell shell summon peti.plugins '{}'
```

## Validation

```bash
omarchy plugin validate ~/Projects/omarchy-settings
qmllint -I /usr/share/omarchy/shell ~/Projects/omarchy-settings/Panel.qml
qmllint -I /usr/share/omarchy/shell ~/Projects/omarchy-settings/SettingsWidget.qml
desktop-file-validate ~/Projects/omarchy-settings/peti.plugins.desktop
```
