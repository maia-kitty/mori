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
| Mod+Shift+D | Toggle light/dark mode |
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

## Light and dark mode

`mori-theme toggle` (or **Mod+Shift+D**, or the sun/moon icon in the bar) switches the whole desktop between Everforest dark and light; `mori-theme dark`, `mori-theme light` and `mori-theme get` also work. Running `mori-theme` with no argument re-applies the saved mode; at login Niri runs `mori-theme init`, which only does that when a state file is missing. The mode is stored in `~/.local/state/mori/mode`. While the bar is running, the switch crossfades: every monitor briefly freezes on a screenshot while the apps repaint underneath, then the screenshot fades out.

**Settings → Appearance** sets the mode and can switch automatically: **Sunrise & sunset** (from a latitude and longitude in whole degrees, saved only in `mori-settings.json`) or **Fixed times** (15-minute steps; Shift+←→ moves by an hour or 10°). The bar checks the schedule every 30 seconds. A manual switch lasts until the next scheduled change; changing the schedule applies it immediately.

Each mode remembers its own wallpaper per monitor. Choose both in the wallpaper picker or **Settings → Appearance** (**Dark** / **Light**); a mode you never chose for keeps the current wallpaper when you switch. Saved in `~/.local/state/mori/wallpapers-dark` and `wallpapers-light`.

| App | How it follows |
| --- | --- |
| Bar, popups, settings | Immediately (Quickshell watches the mode file) |
| Niri borders, focus ring, recent windows | Immediately (optional include of `mori/colors-light.kdl`) |
| Foot | Open windows switch by signal; new windows start in the current mode |
| Neovim | Follows Foot's background, live where the terminal reports changes |
| Fish, Yazi, Fastfetch, Cava | Use terminal colors, so they follow Foot |
| libadwaita apps, Zen, Equibop, Obsidian, Zed | Through the `color-scheme` portal setting (gsettings) |
| GTK3 apps such as Nemo, GTK file pickers | Immediately (the `Mori-dark` / `Mori-light` themes in `gtk/.local/share/themes` carry the colors) |
| Qt apps (qt5ct, qt6ct) | About 3 s later (qt6ct rereads its config folder when it changes) |
| KDE apps such as Gwenview | Next launch (they set their own palette from `kdeglobals` at startup) |
| Fuzzel, lock screen | Next launch (Swaylock, the fallback, too) |
| btop | Immediately (live config is edited and btop reloads it) |
| kew | Next launch, when the Mori theme is selected |

Zen needs its theme set to **Auto**, Discord's **Appearance** to **Sync with computer**, Obsidian's base color scheme to **Adapt to system**, and Zed's theme mode to System. SDDM stays dark. Foot windows opened before `[colors-light]` was added to foot.ini switch to Foot's default colors until they're reopened.

## Lock screen (mori-lock)

**Mod+Alt+L** or **Lock** in the power menu (both run `mori-lock`) take a screenshot of each monitor, lock the session, and let the screenshot dissolve into fog and soft boxes in its own colors. The effect is **Kiri**, Mori's fog engine (`KiriEffect.qml`, `shaders/kiri.frag`), which the login screen uses too. The clock and password field show on the monitor you were using; click another monitor to move them. The right password plays the fog backwards and unlocks. `qs -c mori ipc call bar lockPreview` shows it without locking (Escape closes).

If the bar isn't running, `mori-lock` uses Swaylock. If the session lock doesn't take within two seconds, the lock screen starts Swaylock itself; if the bar restarts while locked, it locks again at once.

## Shell settings

Open **Settings** from the bar or with **Mod+Period**. A sidebar lists the pages. **↑↓** moves through it (the page follows), **Enter** goes into the page, and **Escape** goes back one level (page → tabs → sidebar → close). Appearance and Power open on their tab row: **←→** picks a tab and **Enter** shows it; **↓** (or Enter on the shown tab) goes into it. Inside a page, **↑↓** picks a row, **←→** highlights a choice and **Enter** applies it; sliders and steppers (volume, pointer speed, schedule times) change right away. **↑** on the first row goes back to the tabs. **Tab** moves between parts of a page, and **Ctrl+Enter** applies Input, Displays and Power menu changes. **Delete** clears a power command (automatic) or the keyboard layout (system); on the Bluetooth tab **P** toggles power and **S** scans.

- **Appearance:** three tabs. **Wallpaper** is the same chooser as the bar's popup plus the wallpaper **Folder** path (**F** or click to edit, Enter saves, `~/…` works): monitor, and a **Dark** and **Light** wallpaper for each (**M** switches between them). The current mode's choice applies right away; the other is used when you switch. **Light & dark** has the mode and automatic switching (see [light and dark mode](#light-and-dark-mode)). **Widget colors** sets each widget's accent color.
- **Bar:** widget visibility, left/center/right order, and compact modes.
- **Notifications:** Do Not Disturb; it is saved, so it survives restarts.
- **Time & date:** clock format, seconds, and date order; time format also applies to calendar events.
- **Network:** the same panel as the network popup (Ethernet, VPN, Wi-Fi, and Bluetooth on its own tab); it works whether or not the Network widget is on the bar. Wi-Fi passwords are asked in the shell's own prompt.
- **Sound:** output and input device, volume, and mute (per-app volumes stay in the volume popup).
- **Displays:** monitor layout and output settings, with timed confirmation and rollback.
- **Input:** keyboard layout, mouse/touchpad acceleration, tapping, natural scrolling, and disable-while-typing. An empty keyboard layout follows the system.
- **Power:** the **Profile** tab picks power saver, balanced, or performance through power-profiles-daemon (also in the battery popup); **Menu commands** is described [below](#power-menu).
- **Updates:** see below.
- **About:** links, and a cat doodle in the corner: a Halloween version Oct 15–31, Christmas Dec 1–26, Valentine's Feb 13–14, and a birthday hat on July 24. The drawings are split into one mask per color (`assets/split-cat.py`) and painted with the theme colors, so they follow light and dark mode.

Bar, widget, clock, and update settings save immediately. Input, display, and power changes use **Apply**; closing settings discards pending edits. Shell settings live in `~/.config/quickshell/mori-settings.json` (under `$XDG_CONFIG_HOME` when set); input and display settings update Niri’s configuration.

The bar uses the main monitor only, with one widget layout. `qs -c mori ipc call bar openSettings <page>` opens Settings on a page (`wallpaper`, `theme` and `appearance` for Appearance's three tabs, `modules` for Bar, `notifications`, `clock`, `network`, `sound`, `displays`, `input`, `profile` and `power` for Power's two tabs, `updates`, `about`). Settings reopens on the page you last used.

## Desktop widgets

| Widget | Function |
| --- | --- |
| Network | Wi-Fi connections and active NetworkManager VPN controls |
| Volume / brightness | Audio output/input devices, application volume, and laptop backlight controls |
| Battery | Battery status and power profiles |
| Media | Media player controls |
| Calendar | Calendar view, with optional khal events and vdirsyncer sync |
| Wallpapers | Per-output wallpaper selection through awww, with a separate wallpaper for dark and light mode, browsing inside the wallpaper folder (set it in **Settings → Appearance**) |
| Light/dark mode | Sun or moon icon for the current mode; click to switch (see [light and dark mode](#light-and-dark-mode)) |
| Notifications | Notification popups, a stored-notification count, and the newest 500 history entries for the current shell session |
| KDE Connect | Paired phone status and clipboard sending; shows “Unavailable” when its QML module is missing |
| Updates | Per-source update counts, errors, last check time, and reboot hints |

Incoming notification popups leave open menus in place. The count beside the bell shows stored history entries, hides when empty, and decreases when entries are removed or cleared.

Notification history shows each arrival's date and time using the configured clock formats.

Clicking a notification runs the app's default action (for example opening that chat) and focuses its window; other actions show as buttons under the text. A notification stays open for the app until you remove it from the history, so its actions keep working there. When an app updates a notification (a download's progress, a new song), the popup updates in place and history keeps each version. Popups wait while the pointer is on them. In the history, **Up/Down** selects, **Enter** opens, **R** removes, **C** clears all and **D** toggles Do Not Disturb.

The volume popup has **Playback** and **Microphone** tabs (**Tab** switches between them). The device picker expands only when switching devices; **Enter** opens it or selects a device, and **Escape** collapses it before closing the popup. **Up/Down** moves through device choices or playback apps, **Left/Right** adjusts volume, and **M** toggles mute for the focused device or app. Playback apps appear as compact name-and-slider rows.

In the network popup, use **Up/Down** to select Ethernet, an active VPN, or Wi-Fi; **Enter** connects and **D** disconnects the selected connection.

The popup opens on its **Network / Bluetooth** tabs: **←→** picks one, **Enter** shows it, **↓** goes into the list, and **↑** at the top or **Escape** comes back to the tabs (Escape there closes). **Tab** or a click also switches views. On the Bluetooth view **P** toggles power and **S** scans. Bluetooth provides adapter power, scanning, pairing, connection controls, and device battery levels when available. Use **Up/Down** to select a device, **Enter** to pair or connect, and **D** to disconnect. Scanning stops when the Bluetooth view closes.

## Power menu

The power menu uses the `mori-power` helper from the `bin` package; keep `~/.local/bin` on your graphical session's PATH. It selects `systemctl` on a running systemd system, or elogind's `loginctl` when its power commands and login manager are available. On other setups it uses the installed `reboot` and `poweroff` commands, and `zzz` or `pm-suspend` for suspend. This supports runit, OpenRC, dinit, and SysV setups through their available power tools. Missing actions are dimmed and disabled, and command failures appear in the popup.

On Void with elogind, no command overrides are needed. Elogind power actions require a correctly configured session and polkit permissions; see the [Void power-management handbook](https://docs.voidlinux.org/config/power-management.html). Native commands run as your user and may need an authorized wrapper. Mori does not automatically invoke sudo, doas, or pkexec, and does not retry another backend after an action fails.

To override individual actions, open **Settings → Power → Menu commands**, enter commands such as `loginctl --no-ask-password suspend` or your authorized wrapper, and click **Apply** (Ctrl+Enter). Leave a field blank, or choose **Use automatic** (**Delete**), to restore automatic selection for that action. Quote paths and arguments containing spaces. Closing settings discards unapplied edits.

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

Replace those examples with your installed commands or executable wrapper paths. Omit any action to keep automatic selection for it. Each stored override is a nonempty array of nonempty strings: the executable followed by its arguments. The settings editor handles quoting and converts commands to these arrays. Arguments are passed literally; shell expressions and aliases are not evaluated. Terminal password prompts do not work in the menu, so configure wrappers with suitable authorization beforehand. Overrides are read each time the menu opens and when an action runs, and survive pulls and changes to other settings. Lock uses Mori's lock screen (Swaylock when the bar isn't running) and logout uses Niri.

Run `mori-power --resolve` to inspect the selected commands without executing a power action. Starting the shell directly with `qs --no-duplicate -c mori` also works without systemd; init-specific session startup is separate from the power menu.

## Updates

The updater now lives in its own repository, [upkeep](https://github.com/maia-kitty/upkeep). Install it with `ln -s /path/to/upkeep/upkeep ~/.local/bin/upkeep` and see its README for usage.

## Updates widget

The Mori bar's **Updates** module shows the number of pending updates and opens a popup with per-source update counts, check errors, the last check time, and reboot hints. Move, recolor, or disable it in **Settings → Bar**, or recolor it in **Settings → Appearance → Widget colors**. Existing saved bar layouts retain their order and gain the new module. The popup unloads its contents when closed; its background controller stays shared so moving the module does not duplicate checks.

Checks run shortly after startup and hourly by default. Choose **15 min**, **1 hour**, **3 hours**, or **Manual** in **Settings → Updates**; the interval saves with the other Mori settings. The same page lists the update sources upkeep found on this computer (system, AUR, Flatpak, Nix, firmware) with an **Off/On** switch each: switched-off sources are neither checked nor updated from the bar. With System off on Arch, AUR updates are still counted but not installed. Disabling the module stops future scheduled checks. **Check now** (`C`) starts a read-only check. **Update** (`U`) opens Foot (or your default terminal through `xdg-terminal-exec`) with `upkeep --refresh`, where password prompts, update confirmations, cleanup, service restarts, and reboots are handled. Foot waits for Enter after completion so you can review the output, then closes. It runs independently of the widget. The bar rechecks after the updater session completes. Press Up/Down to scroll or Escape to close.

Install [upkeep](https://github.com/maia-kitty/upkeep), stow `quickshell`, and keep `~/.local/bin` on your graphical session's PATH. Foot or `xdg-terminal-exec` is needed for the Update button; checks still work without it. The widget calls `upkeep --json`, which only checks packages and reboot hints: it never invokes sudo/doas, refreshes system indexes or legacy Nix channels, cleans caches, restarts services, or installs packages. Checks may contact repositories and populate download/metadata caches. Cached indexes are labeled, and Nix counts newer flake revisions rather than guaranteed package-version changes. Failed or unrecognized checks show an error/unknown count instead of reporting zero updates. Results save in `$XDG_CACHE_HOME/upkeep/status.json` (normally `~/.cache/upkeep/status.json`) and survive shell reloads.
