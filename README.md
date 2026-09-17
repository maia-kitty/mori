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

## Manual installation

Install GNU Stow and the dependencies for the components you want using your package manager. Fonts, cursor themes, and the base GTK theme need to be installed separately.

```bash
git clone https://github.com/maia-kitty/mori.git
cd mori
stow --simulate -v -t ~ bin niri quickshell systemd kitty fuzzel swaylock
stow -t ~ bin niri quickshell systemd kitty fuzzel swaylock
```

Choose only the packages you want. Other home-directory packages, such as `gtk`, `qt`, `fish`, or `nvim`, can be stowed individually. Back up conflicting files before replacing them. Keep the checkout in place: the installed symlinks point into it.

Before using Niri, adjust `niri/.config/niri/mori/outputs.kdl` for your monitors. Ensure `~/.local/bin` is on your PATH for the desktop helpers. Before stowing `qt`, update the `/home/martin/` palette paths in its settings. Review the CachyOS-specific source and personal paths in the Fish configuration.

To start Mori with your graphical session:

```bash
systemctl --user daemon-reload
systemctl --user enable mori-quickshell.service
```

In an active Niri session, run `systemctl --user start mori-quickshell.service`. Alternatively, launch the shell directly with `qs --no-duplicate -c mori`.

### Zen Browser

Launch Zen once to create a profile. Find its root directory in `about:profiles`, close Zen, and link the theme into that profile:

```bash
mkdir -p /path/to/zen/profile/chrome
ln -s "$PWD/zen/userChrome.css" /path/to/zen/profile/chrome/userChrome.css
```

Replace the example profile path with yours and back up any existing `userChrome.css` first. Copying the CSS instead is also an option. Enable `toolkit.legacyUserProfileCustomizations.stylesheets` in `about:config` and restart Zen.

### SDDM

With SDDM installed, deploy its theme to the system root rather than your home directory:

```bash
sudo stow --simulate -v -t / sddm
sudo stow -t / sddm
```

Resolve existing conflicts and check other SDDM theme overrides before deploying. This selects the Mori theme; enabling SDDM as your login manager is a separate step.
