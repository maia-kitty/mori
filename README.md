# Mori 森

## AI usage disclaimer

This rice was made with AI assistance. AI helped write, modify, organize, and troubleshoot parts of the configuration, including the custom shell. I review and use the resulting files, but this is an evolving personal setup, and mistakes may still be present. Read through the configuration before using it on your own machine.

## About the rice

**Mori** comes from the Japanese word for **forest**, 森. The name was chosen because of the usage of the Everforest palette.

This is my personal Linux desktop rice and dotfiles collection, built around **Niri** and a custom **Quickshell** bar. The goal is a consistent look across the whole system.

I personally use CachyOs so it was made with it in mind.

## Dependencies

| Component | What it is (for) |
| --- | --- |
| Niri | Wayland compositor |
| Quickshell | Bar, popups, notifications, and desktop controls |
| PipeWire and WirePlumber | Audio and the bar's volume controls |
| Kitty | Terminal and terminal-based launch shortcuts |
| Fuzzel | Application launcher and clipboard picker |
| wl-clipboard and cliphist | Clipboard history and copying selections |
| awww | Wallpaper daemon and per-output wallpaper selection |
| Swaylock | Lock screen and the power menu's lock action |
| Bash and jq | Helper scripts |
| Zenity | Wallpaper folder picker and Wi-Fi password dialog |

The shell imports `org.kde.kdeconnect`, so **KDE Connect and its QML module are required by the current shell**, even if you do not pair a phone.

### Fonts and appearance

| Asset | What it is (for) |
| --- | --- |
| Geist | Main font |
| Geist Mono | Main font but mono |
| Maple Mono | Terminal font |
| Symbols Nerd Font | Shell icons |
| adw-gtk3 | Base GTK 3 theme, styled with color overrides |
| Adwaita icons | GTK application icons |
| Bibata Modern Classic | Cursor |

Mori’s custom GTK styling is included in `gtk/`: GTK 3 defines the Everforest color overrides in `gtk.css`, and GTK 4 imports the same palette. The GTK settings select `adw-gtk3-dark` as the base theme.

The Everforest terminal theme and Mori application palettes are included in the repository. Fonts, the base GTK theme, icon packs, and cursor themes are not bundled.

## Optional software I use

These applications have configurations, themes, or shortcuts here. They are optional for the desktop itself; individual shortcuts and integrations need their corresponding program installed.

| Software | What it is (for) |
| --- | --- |
| Fish | Shell of choice |
| Neovim / LazyVim | CLI Editor |
| Zed | GUI Editor |
| Yazi | CLI file manager |
| Nemo | GUI file manager |
| btop | System monitor |
| Fastfetch | Quick system info (larping) |
| Cava | Audio visualizer |
| Kew | Terminal music player |
| Equibop | Discord client |
| Zen Browser | Browser |
| Obsidian | Notes app |
| SDDM | Login manager |
| khal and vdirsyncer | Quickshell calendar integration |
| lavat and tty-clock | Terminal visuals with Fish helpers |

## Installer

Requires Python 3 to start. On CachyOS/Arch, the installer offers to install missing dependencies, including GNU Stow, for the components you select. It previews repository packages for pacman and AUR candidates for an existing paru or yay, then asks before installing. On other distributions, install the equivalent dependencies and GNU Stow yourself.

```bash
git clone https://github.com/maia-kitty/mori.git
cd mori
./install.py --dry-run
./install.py
```

Run as your normal user. Choose the dotfile packages you want; the installer offers backups for conflicts, a Zen profile picker, optional SDDM deployment using sudo, and shell service enablement. The preview leaves packages, files, and services unchanged. Fonts/cursors and calendar dependencies are optional. Software installation does not enable network managers or other system services.

Regular dotfiles stay managed by Stow. Qt settings with personal paths become local copies; their palettes remain linked. Zen CSS can be linked or copied. Backups are saved under `~/.local/state/mori/backups/`. Keep the checkout in place for symlinked files.

Before using Niri, adjust `niri/.config/niri/mori/outputs.kdl` for your monitors. Ensure `~/.local/bin` is on your PATH for the desktop helpers. For Zen, launch it once to create a profile, close it during installation, then enable `toolkit.legacyUserProfileCustomizations.stylesheets` in `about:config` and restart it.
