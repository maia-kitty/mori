# Mori functions

[README](../README.md) · [Installation](setup.md)

## Shortcuts

`Mod` is Super in a normal Niri desktop session. These bindings are in `niri/.config/niri/mori/binds.kdl`.

| Shortcut | Action |
| --- | --- |
| Mod+T / Mod+Space | Terminal / application launcher |
| Mod+Period | Mori settings |
| Mod+V / Mod+M | Clipboard history / btop |
| Mod+X / Mod+Y / Mod+N | Power menu / wallpapers / notifications |
| Mod+Z / Mod+Shift+N | Zen Browser / Obsidian |
| Mod+Alt+L / Mod+Shift+E | Lock / quit Niri |
| Mod+Tab / Alt+Tab | Overview / recent windows |
| Mod+Q / Mod+F / Mod+Shift+F | Close / maximize column / fullscreen |
| Mod+Left/Right / Mod+Up/Down | Focus column / workspace |
| Mod+Ctrl+arrows | Move column or move it between workspaces |
| Mod+Shift+arrows | Move column to another monitor |
| Mod+Shift+T | Toggle floating |
| Mod+R / Mod+Shift+R | Cycle column width / window height |
| Print / Ctrl+Print / Alt+Print | Screenshot selection / screen / window |
| Mod+F2 / Mod+F3 / Mod+F4 | Volume down / mute / volume up |

## Shell settings

Open **Settings** from the bar or with **Mod+Period**:

- **Modules:** choose, arrange, and recolor bar widgets.
- **Appearance:** customize the shell’s appearance.
- **Time & date:** clock format, seconds, and date order; time format also applies to calendar events.
- **Input:** keyboard layout, mouse/touchpad acceleration, tapping, natural scrolling, and disable-while-typing. An empty keyboard layout follows the system.
- **Displays:** monitor layout and output settings, with timed confirmation and rollback.
- **Power menu** and **Updates:** see below.

Module, appearance, clock, and update interval settings save immediately. Input, display, and power changes use **Apply**; closing settings discards pending edits. Shell settings live in `~/.config/quickshell/mori-settings.json` (under `$XDG_CONFIG_HOME` when set); input and display settings update Niri’s configuration.

## Desktop widgets

| Widget | Function |
| --- | --- |
| Network | Wi-Fi connections and active NetworkManager VPN controls |
| Volume / brightness | Audio and laptop backlight controls |
| Battery | Battery status and power profiles |
| Media | Media player controls |
| Calendar | Calendar view, with optional khal events and vdirsyncer sync |
| Wallpapers | Folder picker and per-output wallpaper selection through awww |
| Notifications | Notification popups and the newest 500 history entries for the current shell session |
| KDE Connect | Paired phone status and clipboard sending; shows “Unavailable” when its QML module is missing |
| Updates | Per-source update counts, errors, last check time, and reboot hints |

In the network popup, use **Up/Down** to select Ethernet, an active VPN, or Wi-Fi; **Enter** connects and **D** disconnects the selected connection.

## Power menu

The power menu uses the `mori-power` helper from the `bin` package; keep `~/.local/bin` on your graphical session's PATH. It selects `systemctl` on a running systemd system, or elogind's `loginctl` when its power commands and login manager are available. On other setups it uses the installed `reboot` and `poweroff` commands, and `zzz` or `pm-suspend` for suspend. This supports runit, OpenRC, dinit, and SysV setups through their available power tools. Missing actions are dimmed and disabled, and command failures appear in the popup.

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

## Updates

`mori-update` is an interactive terminal helper in the `bin` package, requiring Python 3.9+. After installing the `bin` package, run:

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

## Updates widget

The Mori bar's **Updates** module shows the number of pending updates and opens a popup with per-source update counts, check errors, the last check time, and reboot hints. Move, recolor, or disable it in **Settings → Modules**. Existing saved bar layouts retain their order and gain the new module. The popup unloads its contents when closed; its background controller stays shared so moving the module does not duplicate checks.

Checks run shortly after startup and hourly by default. Choose **15 min**, **1 hour**, **3 hours**, or **Manual** in **Settings → Updates**; the interval saves with the other Mori settings. Disabling the module stops future scheduled checks. **Check now** (`C`) starts a read-only check. **Update** (`U`) opens Foot with `mori-update --refresh`, where password prompts, update confirmations, cleanup, service restarts, and reboots are handled. Foot waits for Enter after completion so you can review the output, then closes. It runs independently of the widget. The bar rechecks after the updater session completes. Press Up/Down to scroll or Escape to close.

Stow both `bin` and `quickshell`, and keep `~/.local/bin` on your graphical session's PATH. Foot is needed for the Update button; checks still work without it. The widget calls `mori-update --json`, which only checks packages and reboot hints: it never invokes sudo/doas, refreshes system indexes or legacy Nix channels, cleans caches, restarts services, or installs packages. Checks may contact repositories and populate download/metadata caches. Cached indexes are labeled, and Nix counts newer flake revisions rather than guaranteed package-version changes. Failed or unrecognized checks show an error/unknown count instead of reporting zero updates. Results save in `$XDG_CACHE_HOME/mori-update/status.json` (normally `~/.cache/mori-update/status.json`) and survive shell reloads.

