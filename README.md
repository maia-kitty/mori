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
| NetworkManager or `iw` and `wpa_supplicant` (`wpa_cli`) | Wi-Fi controls; standalone wpa_supplicant needs user access to its control socket |
| PipeWire and WirePlumber | Audio and the bar's volume controls |
| brightnessctl | Laptop backlight control |
| power-profiles-daemon | Battery popup power profiles |
| Kitty | Terminal and terminal-based launch shortcuts |
| Fuzzel | Application launcher and clipboard picker |
| wl-clipboard and cliphist | Clipboard history and copying selections |
| awww | Wallpaper daemon and per-output wallpaper selection |
| Swaylock | Lock screen and the power menu's lock action |
| Bash and jq | Helper scripts |
| Zenity | Wallpaper folder picker and Wi-Fi password dialog |

KDE Connect is optional. If its QML module is unavailable, the KDE Connect bar widget stays hidden while the rest of the shell loads. Sending the clipboard from that widget requires `kdeconnect-cli`.

On a standalone `wpa_supplicant` setup, the network popup can add open and WPA-Personal networks. Saving new connections across restarts also requires `wpa_supplicant` to allow `SAVE_CONFIG` (`update_config=1`).

The shell settings menu also edits Niri input settings. `niri/config.kdl` includes `niri/mori/input.kdl`; the Input page controls keyboard layout, mouse and touchpad acceleration speed, tap-to-click, natural scrolling, and disable-while-typing. Leaving keyboard layout empty follows the system setting. Time & date controls the bar clock's 12/24-hour format, seconds, and date order; its time format also applies to calendar event times. Module, appearance, and time settings save immediately. Power menu, Input, and Displays have Apply buttons; closing settings discards their pending changes, and display changes require a timed confirmation.

Notification history keeps the newest 500 entries for the current shell session. The notification list creates rows as they become visible. Calendar, network, volume, and notification popup contents unload when closed, and settings loads only the selected page; pending saves and display rollback remain active. Volume tracks the default audio sink while closed and discovers all nodes when opened. Overview and workspace controls share one Niri event stream.

### Fonts and appearance

| Asset | What it is (for) |
| --- | --- |
| Old Standard TT | GUI font |
| IBM Plex Mono | Terminal and code font |
| Symbols Nerd Font | Shell icons |
| adw-gtk3 | Base GTK 3 theme, styled with color overrides |
| Adwaita icons | GTK application icons |
| Adwaita | Cursor |

Mori’s custom GTK styling is included in `gtk/`: GTK 3 defines the Everforest color overrides in `gtk.css`, and GTK 4 imports the same palette. The GTK settings select `adw-gtk3-dark` as the base theme.

The Everforest terminal theme, Mori application palettes, Old Standard TT, and IBM Plex Mono are included in the repository. The base GTK theme, icon packs, and cursor themes are not bundled. The bundled fonts retain their SIL Open Font License files.

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

Install GNU Stow and the dependencies for the components you want using your package manager. The cursor theme, Symbols Nerd Font, and base GTK theme need to be installed separately.

```bash
git clone https://github.com/maia-kitty/mori.git
cd mori
stow --simulate -v -t ~ fonts bin niri quickshell systemd kitty fuzzel swaylock
stow -t ~ fonts bin niri quickshell systemd kitty fuzzel swaylock
fc-cache -f ~/.local/share/fonts
```

Choose only the packages you want. Other home-directory packages, such as `gtk`, `qt`, `fish`, or `nvim`, can be stowed individually. Back up conflicting files before replacing them. Keep the checkout in place: the installed symlinks point into it.

Before using Niri, adjust `niri/.config/niri/mori/outputs.kdl` for your monitors. Ensure `~/.local/bin` is on your PATH for the desktop helpers. Before stowing `qt`, update the `/home/martin/` palette paths in its settings. Review the CachyOS-specific source and personal paths in the Fish configuration.

To start Mori with your graphical session:

```bash
systemctl --user daemon-reload
systemctl --user enable mori-quickshell.service
```

In an active Niri session, run `systemctl --user start mori-quickshell.service`. Alternatively, launch the shell directly with `qs --no-duplicate -c mori`.

### Portable power menu

The power menu uses the `mori-power` helper from the `bin` package; keep `~/.local/bin` on your graphical session's PATH. If you already installed Mori before this helper was added, run `stow -R -t ~ bin` once from the checkout to install it. It selects `systemctl` on a running systemd system, or elogind's `loginctl` when its power commands and login manager are available. On other setups it uses the installed `reboot` and `poweroff` commands, and `zzz` or `pm-suspend` for suspend. This supports runit, OpenRC, dinit, and SysV setups through their available power tools. Missing actions are dimmed and disabled, and command failures appear in the popup.

On Void with elogind, no command overrides are needed. Elogind power actions require a correctly configured session and polkit permissions; see the [Void power-management handbook](https://docs.voidlinux.org/config/power-management.html). Native commands run as your user and may need an authorized wrapper. Mori does not automatically invoke sudo, doas, or pkexec, and does not retry another backend after an action fails.

To override individual actions, open **Settings → Power menu**, enter commands such as `loginctl --no-ask-password suspend` or your authorized wrapper, and click **Apply** (Ctrl+Enter). Leave a field blank, or choose **Use automatic**, to restore automatic selection for that action. Quote paths and arguments containing spaces. Closing settings discards unapplied edits.

Commands are saved with the other shell settings in `~/.config/quickshell/mori-settings.json` (or `$XDG_CONFIG_HOME/quickshell/mori-settings.json` when set), outside the checkout. Its optional `power` section looks like:

```json
{
  "power": {
    "suspend": ["my-suspend-wrapper"],
    "reboot": ["my-reboot-wrapper"],
    "poweroff": ["my-poweroff-wrapper"]
  }
}
```

Replace those examples with your installed commands or executable wrapper paths. Omit any action to keep automatic selection for it. Each stored override is a nonempty array of nonempty strings: the executable followed by its arguments. The settings editor handles quoting and converts commands to these arrays. Arguments are passed literally; shell expressions and aliases are not evaluated. Terminal password prompts do not work in the menu, so configure wrappers with suitable authorization beforehand. Overrides are read each time the menu opens and when an action runs, and survive pulls and changes to other settings. Lock and logout continue to use Swaylock and Niri.

Run `mori-power --resolve` to inspect the selected commands without executing a power action. Starting the shell directly with `qs --no-duplicate -c mori` also works without systemd; init-specific session startup is separate from the power menu.

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
sudo cp -r fonts/.local/share/fonts/old-standard-tt /usr/local/share/fonts/
sudo fc-cache -f /usr/local/share/fonts/old-standard-tt
```

Resolve existing conflicts and check other SDDM theme overrides before deploying. This selects the Mori theme; enabling SDDM as your login manager is a separate step.
