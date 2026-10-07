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
| Foot | Default terminal, terminal-based launch shortcuts, and the Updates widget |
| Fuzzel | Application launcher and clipboard picker |
| wl-clipboard and cliphist | Clipboard history and copying selections |
| awww | Wallpaper daemon and per-output wallpaper selection |
| Swaylock | Lock screen and the power menu's lock action |
| Bash and jq | Helper scripts |
| Python 3.9+ | Mori updater and Updates widget |
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
| Kitty | Alternative terminal with a bundled configuration |
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
stow --simulate -v -t ~ fonts bin niri quickshell systemd foot fuzzel swaylock
stow -t ~ fonts bin niri quickshell systemd foot fuzzel swaylock
fc-cache -f ~/.local/share/fonts
```

Foot is the default terminal for Mod+T, Fuzzel, btop, and the Updates widget. The `foot` package includes the Everforest palette, IBM Plex Mono with Symbols Nerd Font fallback, and terminal key bindings. The `kitty` package remains available as an optional alternative configuration.

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

### Portable updates

`mori-update` is an interactive terminal helper in the `bin` package, requiring Python 3.9+. Run `stow -R -t ~ bin` after pulling to install it, then:

```bash
mori-update                    # Check each source, ask before upgrading it
mori-update --check            # Check only; no package installations
mori-update --check --refresh  # Also refresh cached metadata/channels
mori-update --backend none     # Only AUR-independent sources: Flatpak and Nix
mori-update --clean            # Only offer cached-package cleanup
mori-update --clean --check    # Preview cleanup without removing anything
```

It selects the system manager from `/etc/os-release`: pacman for Arch/CachyOS, APT for Debian/Ubuntu, DNF for Fedora/RHEL, Zypper for openSUSE, XBPS for Void, and APK for Alpine. Arch checks require `checkupdates` from `pacman-contrib`; they use a temporary database to avoid a partial system upgrade. Tumbleweed/Slowroll use `zypper dup`. Void may need a second run when XBPS updates itself. Immutable and declaratively managed operating systems need their own system update workflows; NixOS system rebuilds are not included. Use `--backend none` on those systems or choose a supported backend explicitly.

It also checks AUR packages with `paru` or `yay` on Arch, Flatpak when installed, and Nix user packages. Nix profiles with `manifest.json` use `nix profile upgrade --all --dry-run --refresh` (Nix 2.22+); legacy profiles with `manifest.nix` use `nix-env --upgrade --dry-run`. The default profile is `~/.nix-profile`, falling back to `$XDG_STATE_HOME/nix/profiles/profile` (normally `~/.local/state/nix/profiles/profile`). Choose another with `--nix-profile /path/to/profile`. Modern Nix only upgrades packages installed from unlocked flake references; pinned packages stay pinned. Legacy Nix checks use the current user's channels; `--refresh` updates those channels first. Home Manager, project flake locks, root profiles, and the Nix daemon are managed separately. See the [Nix profile upgrade manual](https://nix.dev/manual/nix/2.35/command-ref/new-cli/nix3-profile-upgrade.html).

APT, Zypper, APK, and legacy Nix checks use cached metadata unless `--refresh` is supplied. Other checks can contact repositories and populate caches, but do not install packages. Refreshing system metadata may require a password. Run the helper as your normal user: only system refresh/upgrade commands use `sudo` or `doas`; Nix and AUR commands run as you. Package managers retain their own transaction prompts. Failed checks skip that source, continue checking the others, and return a nonzero exit status; check timeouts default to 180 seconds and can be changed with `--timeout`. Use `--no-nix`, `--no-aur`, or `--no-flatpak` to skip sources.

Installation prompts default to yes (`[Y/n]`): press Enter to install updates. Reboot prompts default to no. The terminal interface uses Everforest colors, clear sections, package/version columns, and compact Nix flake summaries. `--verbose` shows the underlying commands and full check output. Color is disabled when output is piped, `NO_COLOR` is set, or `TERM=dumb`.

After an interactive system update session, Mori checks for reboot markers and a running kernel that has been removed or replaced on disk. It uses an installed `needrestart` (batch/list mode), `checkservices` (with reloads, config processing, and restarts disabled), or standalone `needs-restarting` to find services that need restarting. On runit, `xcheckrestart` from Void's `xtools-minimal` package is another fallback: Mori links outdated process IDs to enabled runit services through their supervisors, and reports other outdated processes for manual restart or logout. Scans may request your sudo/doas password. Choose numbered services, `0`, or `all` to restart them, or press Enter to skip; systemd service definitions are reloaded before selected services restart. Display managers and core session services are excluded and flagged for logout/reboot. On other init systems, `needrestart` results can use OpenRC, runit, or SysV restart commands when available. A recommended reboot always gets a separate confirmation prompt. If no detector is installed or scanning fails, the helper reports that limitation.

Run `mori-update --maintenance` to do these checks without checking packages, or `mori-update --maintenance --check` to report findings without restarting services or rebooting. Ordinary `--check` only checks reboot markers/kernel files; it does not run privileged service scans. Use `--no-maintenance` to skip all reboot/service checks. The reboot hints are best effort; retained kernel files, containers, or an unavailable detector can limit detection. See [needrestart's batch mode documentation](https://github.com/liske/needrestart/blob/master/README.batch.md) for the service and kernel findings it reports.

The **Cached packages** step runs after package checks/upgrades and before reboot/service checks. Each cleanup gets a separate `[Y/n]` prompt. `--check` only previews supported cleanup operations or prints the proposed command when the manager has no dry run. `--no-cleanup` skips this step; `--clean` runs it without package updates or reboot/service actions. Failed previews skip that cleanup, and failures do not block the remaining managers.

| Manager | Cleanup | What is removed or retained |
| --- | --- | --- |
| pacman | `paccache -r -k 3`, then `paccache -r -u -k 0` | Keep 3 cached versions; remove all archives of uninstalled packages. Without `paccache`, fall back to `pacman -Sc`, which follows pacman's cache policy and also offers to remove unused sync databases. |
| APT | `apt-get autoclean` | Remove obsolete downloaded packages no longer available from repositories. |
| DNF | `dnf clean packages` | Remove downloaded package archives; retain repository metadata. |
| Zypper | `zypper clean` | Remove downloaded package archives; retain repository metadata. |
| XBPS | `xbps-remove -OO` | Remove outdated archives and archives of uninstalled packages. |
| APK | `apk cache clean` | Remove obsolete or no-longer-needed archives from the configured cache. |
| paru / yay | `<helper> -Sc --aur` | Clean AUR build caches and sources with the helper's own prompts; system cache cleanup stays separate. |
| Nix | `nix-store --gc` | Collect unreachable store objects while preserving all profile generations and rollback roots. Runs as your user, including when no supported user profile exists. |
| Flatpak | `flatpak repair` for each discovered installation | Prune unreferenced store objects and verify the installation. Damaged objects may be downloaded again; installed applications and runtimes are retained. User, default system, and custom installations containing installed refs are supported. |

Nix cleanup uses `--gc --print-dead` for a read-only preview and never passes generation-deletion flags; see the [Nix garbage collection manual](https://nix.dev/manual/nix/2.21/command-ref/nix-collect-garbage). Flatpak uses `repair --dry-run` before offering the cleanup; see the [Flatpak repair reference](https://manpages.debian.org/unstable/flatpak/flatpak-repair.1.en.html). Cache removal can require downloading archives or rebuilding AUR packages again in future.

This helper does not enable a tray app or scheduled checks or remove installed package orphans automatically.

### Updates widget

The Mori bar's **Updates** module shows the number of pending updates and opens a popup with package lists, check errors, the last check time, and reboot hints. Move, recolor, or disable it in **Settings → Modules**. Existing saved bar layouts retain their order and gain the new module. The popup unloads its contents when closed; its background controller stays shared so moving the module does not duplicate checks.

Checks run shortly after startup and hourly by default. Choose **15 min**, **1 hour**, **3 hours**, or **Manual** in **Settings → Updates**; the interval saves with the other Mori settings. Disabling the module stops future scheduled checks. **Check now** (`C`) starts a read-only check. **Update** (`U`) opens Foot with `mori-update --refresh`, where password prompts, update confirmations, cleanup, service restarts, and reboots are handled. Foot waits for Enter after completion so you can review the output, then closes. It runs independently of the widget. The bar rechecks after the updater session completes. Press Up/Down to scroll or Escape to close.

Stow both `bin` and `quickshell`, and keep `~/.local/bin` on your graphical session's PATH. Foot is needed for the Update button; checks still work without it. The widget calls `mori-update --json`, which only checks packages and reboot hints: it never invokes sudo/doas, refreshes system indexes or legacy Nix channels, cleans caches, restarts services, or installs packages. Checks may contact repositories and populate download/metadata caches. Cached indexes are labeled, and Nix counts newer flake revisions rather than guaranteed package-version changes. Failed or unrecognized checks show an error/unknown count instead of reporting zero updates. Results save in `$XDG_CACHE_HOME/mori-update/status.json` (normally `~/.cache/mori-update/status.json`) and survive shell reloads.

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
