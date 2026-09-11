# Mori

Mori is my personal collection of desktop configuration and dotfiles.

This is a personal project, not a general-purpose configuration framework. It is shaped around my own hardware, applications, workflow, and preferences, so parts of it may need adjustment before they work on another system.

## AI assistance

This repository was made with AI assistance. The AI helped write, modify, organize, and troubleshoot parts of the configuration. I review and use the resulting files, but the repository should still be treated as an actively evolving personal setup rather than polished or independently audited software.

## Layout

The repository is organized for GNU Stow. Each top-level directory is a package whose contents mirror paths relative to `$HOME`.

For example, the Quickshell package is located at:

```text
quickshell/.config/quickshell/mori/
```

To install that package:

```bash
cd ~/mori
stow -t ~ quickshell
```

Review the files and existing symlinks before stowing on a new machine. Stow will report conflicts when another package already owns the same destination.

### Login greeter

The `greetd` package configures the system login manager with `tuigreet` and
starts the `niri-session` Wayland session. It is intentionally a system-level
Stow package because greetd owns TTY1 and reads `/etc/greetd/config.toml`.

Install the required package, deploy the package to `/`, then apply its systemd
preset:

```bash
sudo pacman -S greetd greetd-tuigreet
cd ~/mori
sudo mv /etc/greetd/config.toml /etc/greetd/config.toml.dms-greeter.bak
sudo stow -t / greetd
sudo systemctl preset greetd.service
```

`greetd.service` is the service that autostarts the greeter; no separate
tuigreet service should be created. The preset enables greetd for future boots.
The existing config is backed up first because Stow will not replace a regular
file with its managed symlink. Reboot to test the new greeter rather than
restarting greetd from within the current graphical session.

## Notes

- Configuration is experimental and may change without preserving backwards compatibility.
- The Mori Quickshell bar currently includes the clock, KDE Connect, active application, network, volume, wallpaper, notifications, system tray, and power widgets.

The KDE Connect widget sits immediately to the right of the clock and requires
`kdeconnect` (including its `org.kde.kdeconnect` QML module). It selects a paired
phone, preferring a connected one, and shows battery/charging status, the count
of mirrored phone notifications, and cellular signal bars. Click it for details
and a **Send clipboard** button to send the desktop clipboard to the phone.
Enable Battery, Connectivity Report, Notifications, and Clipboard in KDE Connect;
unavailable reports show a dash. Signal strength is cellular (0–4), not Wi-Fi.

Only one process can provide `org.freedesktop.Notifications` in a desktop
session. If another shell such as DMS already owns it, Mori's notification
center remains inactive until that notification server stops.

The wallpaper picker requires `awww`. Mori starts `awww-daemon`, and selections
are sent to the selected output with `awww img`. The daemon caches each output's
last image and restores it automatically after Mori starts on the next login.

## CalDAV calendar

Click the date and time in the Quickshell bar to open the calendar and daily
agenda. The widget uses `vdirsyncer` for CalDAV synchronization and `khal` to
read the local calendars; account credentials are therefore never stored in
the Quickshell configuration.

Install both programs, then configure the account once:

```bash
khal configure
vdirsyncer discover
vdirsyncer sync
```

`khal configure` can create the vdirsyncer and khal configuration for a CalDAV
server. Prefer its password-command/keyring option over putting a password
directly in a configuration file. Reopen the popup after setup; it syncs when
opened, can be refreshed with the `↻` action, and refreshes every 15 minutes
while it remains open.
