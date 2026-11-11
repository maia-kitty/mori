# Mori 森

My Linux desktop rice and dotfiles: **Niri**, a custom **Quickshell** bar, and the **Everforest** palette. Built on CachyOS. Mori means “forest” in Japanese.

Made with AI assistance; review the configuration before using it.

## Desktop dependencies

Install GNU Stow and the dependencies for the components you want.

| Software | Purpose |
| --- | --- |
| Niri / Quickshell | Compositor / desktop shell |
| Foot / Fuzzel / Swaylock | Terminal / launcher / lock screen |
| awww | Wallpapers |
| swaybg | Optional: static wallpaper backend (**Settings → Appearance**) |
| PipeWire + WirePlumber | Audio |
| NetworkManager, or iw + wpa_supplicant | Wi-Fi |
| brightnessctl / power-profiles-daemon | Backlight / power profiles |
| wl-clipboard + cliphist | Clipboard history |
| grim | Screenshots for the light/dark crossfade (without it, switches aren't faded) |
| Bash, jq, Python 3.9+ | Helpers |
| [upkeep](https://github.com/maia-kitty/upkeep) | Updater behind the Updates widget |

**Appearance:** Literata and IBM Plex Mono are bundled; install Symbols Nerd Font, adw-gtk3, and Adwaita icons/cursor separately. Qt styling uses qt5ct and qt6ct-kde, with colors matching GTK.

## Software I use

These are optional. Apps without bundled configs use external themes or setup; Zed’s theme can be downloaded in Zed.

| Software | Purpose |
| --- | --- |
| Fish | Shell |
| Neovim / LazyVim, Zed | Editors |
| Yazi / Nemo | File managers |
| Kitty | Alternative terminal |
| btop / Fastfetch | System monitor / system info |
| Cava / Kew | Visualizer / music player |
| Equibop | Discord client |
| Zen Browser / Obsidian | Browser / notes |
| greetd or SDDM | Login manager (Mori's login screen, or the SDDM theme) |
| KDE Connect | Phone integration |
| khal + vdirsyncer | Calendar integration |
| lavat / tty-clock | Terminal visuals |

## Get started

Follow the [installation guide](docs/setup.md) for dependencies, Stow setup, session startup, Zen, and SDDM.

See [functions and shortcuts](docs/functions.md) for bar settings, desktop controls, the power menu, and updates.
