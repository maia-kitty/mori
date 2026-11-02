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
| Mod+F1 / Mod+F2 / Mod+F3 | Volume down / volume up / mute |
| Volume and brightness keys | Volume down / mute / up, brightness down / up |

Volume and brightness shortcuts show a short level indicator at the bottom of the main monitor.

## Shell settings

Open **Settings** from the bar or with **Mod+Period**:

- **Bar & widgets:** **Widgets** controls visibility, left/center/right order, and compact modes; **Colors** controls widget accent colors. Click the tabs or press **Tab** to switch views.
- **Time & date:** clock format, seconds, and date order; time format also applies to calendar events.
- **Input:** keyboard layout, mouse/touchpad acceleration, tapping, natural scrolling, and disable-while-typing. An empty keyboard layout follows the system.
- **Displays:** monitor layout and output settings, with timed confirmation and rollback.
- **Power menu** and **Updates:** see below.

Bar, widget, clock, and update interval settings save immediately. Input, display, and power changes use **Apply**; closing settings discards pending edits. Shell settings live in `~/.config/quickshell/mori-settings.json` (under `$XDG_CONFIG_HOME` when set); input and display settings update Niri’s configuration.

The bar uses the main monitor only, with one widget layout.

## Desktop widgets

| Widget | Function |
| --- | --- |
| Network | Wi-Fi connections and active NetworkManager VPN controls |
| Volume / brightness | Audio output/input devices, application volume, and laptop backlight controls |
| Battery | Battery status and power profiles |
| Media | Media player controls |
| Calendar | Calendar view, with optional khal events and vdirsyncer sync |
| Wallpapers | Folder picker and per-output wallpaper selection through awww |
| Notifications | Notification popups, a stored-notification count, and the newest 500 history entries for the current shell session |
| KDE Connect | Paired phone status and clipboard sending; shows “Unavailable” when its QML module is missing |
| Updates | Per-source update counts, errors, last check time, and reboot hints |

Incoming notification popups leave open menus in place. The count beside the bell shows stored history entries, hides when empty, and decreases when entries are removed or cleared.

Notification history shows each arrival's date and time using the configured clock formats.

The volume popup has **Playback** and **Microphone** tabs (**Tab** switches between them). The device picker expands only when switching devices; **Enter** opens it or selects a device, and **Escape** collapses it before closing the popup. **Up/Down** moves through device choices or playback apps, **Left/Right** adjusts volume, and **M** toggles mute for the focused device or app. Playback apps appear as compact name-and-slider rows.

In the network popup, use **Up/Down** to select Ethernet, an active VPN, or Wi-Fi; **Enter** connects and **D** disconnects the selected connection.

Press **Tab** or click the **Network / Bluetooth** tabs to switch views. Bluetooth provides adapter power, scanning, pairing, connection controls, and device battery levels when available. Use **Up/Down** to select a device, **Enter** to pair or connect, and **D** to disconnect. Scanning stops when the Bluetooth view closes.

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

The updater now lives in its own repository, [upkeep](https://github.com/maia-kitty/upkeep). Install it with `ln -s /path/to/upkeep/upkeep ~/.local/bin/upkeep` and see its README for usage.

## Updates widget

The Mori bar's **Updates** module shows the number of pending updates and opens a popup with per-source update counts, check errors, the last check time, and reboot hints. Move, recolor, or disable it in **Settings → Bar & widgets**, in the **Widgets** or **Colors** tab. Existing saved bar layouts retain their order and gain the new module. The popup unloads its contents when closed; its background controller stays shared so moving the module does not duplicate checks.

Checks run shortly after startup and hourly by default. Choose **15 min**, **1 hour**, **3 hours**, or **Manual** in **Settings → Updates**; the interval saves with the other Mori settings. Disabling the module stops future scheduled checks. **Check now** (`C`) starts a read-only check. **Update** (`U`) opens Foot with `upkeep --refresh`, where password prompts, update confirmations, cleanup, service restarts, and reboots are handled. Foot waits for Enter after completion so you can review the output, then closes. It runs independently of the widget. The bar rechecks after the updater session completes. Press Up/Down to scroll or Escape to close.

Install [upkeep](https://github.com/maia-kitty/upkeep), stow `quickshell`, and keep `~/.local/bin` on your graphical session's PATH. Foot is needed for the Update button; checks still work without it. The widget calls `upkeep --json`, which only checks packages and reboot hints: it never invokes sudo/doas, refreshes system indexes or legacy Nix channels, cleans caches, restarts services, or installs packages. Checks may contact repositories and populate download/metadata caches. Cached indexes are labeled, and Nix counts newer flake revisions rather than guaranteed package-version changes. Failed or unrecognized checks show an error/unknown count instead of reporting zero updates. Results save in `$XDG_CACHE_HOME/upkeep/status.json` (normally `~/.cache/upkeep/status.json`) and survive shell reloads.
