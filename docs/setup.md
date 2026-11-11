# Install Mori

[README](../README.md) · [Functions and shortcuts](functions.md)

## 1. Install dependencies

Use your distribution’s package manager to install GNU Stow and the [desktop dependencies](../README.md#desktop-dependencies). Package names vary by distribution. Install only the optional applications you want.

Install Symbols Nerd Font, adw-gtk3, and the Adwaita icons/cursor separately. Literata, IBM Plex Mono, and their font licenses are bundled. For Qt styling, install qt5ct and qt6ct-kde; Niri sets their platform-theme variables. Qt 5 uses its native palette, while Qt 6 and KDE apps use the bundled `Mori.colors` scheme. Rebuild qt6ct-kde after a Qt minor-version update if its theme plugin stops loading.

For standalone Wi-Fi, install `iw` and `wpa_supplicant` with `wpa_cli`, give your user access to its control socket, and enable `update_config=1` if new networks should survive restarts. The popup supports open and WPA-Personal networks.

Optional integrations need their own setup: pair your phone in KDE Connect, and configure khal/vdirsyncer accounts for calendar events. Arch update checks need `checkupdates` from `pacman-contrib`.

## 2. Clone and review

```bash
git clone https://github.com/maia-kitty/mori.git
cd mori
```

Back up conflicting dotfiles. Before linking:

- Edit `niri/.config/niri/mori/outputs.kdl` for your monitors; the bundled layout uses DP-1 and a rotated HDMI-A-1.
- Review `niri/.config/niri/mori/binds.kdl` for application shortcuts.
- If using Fish, review its CachyOS config source and Arch-specific `paru` abbreviations in `fish/.config/fish/config.fish`.

## 3. Link the packages

Preview first, resolve conflicts, then install:

```bash
stow --simulate -v -t ~ fonts bin niri quickshell systemd foot fuzzel swaylock
stow -t ~ fonts bin niri quickshell systemd foot fuzzel swaylock
fc-cache -f ~/.local/share/fonts
```

On systems without systemd, leave `systemd` out of both commands. Keep the checkout in place: Stow creates symlinks into it.

Install additional home packages the same way, for example:

```bash
stow --simulate -v -t ~ gtk qt fish nvim yazi btop
stow -t ~ gtk qt fish nvim yazi btop
```

Ensure `~/.local/bin` is on your graphical session’s PATH. The bar and Niri shortcuts use the bundled helpers there.

Foot and Fuzzel include files that `mori-theme` writes to `~/.local/state/mori/`. Niri creates them at startup; outside Niri, run `mori-theme` once. See [light and dark mode](functions.md#light-and-dark-mode).

## 4. Start the desktop

Start a Niri session through your login manager or your usual session launcher. Its config starts the wallpaper backend (`mori-wallpaper start`) and clipboard history automatically.

For the bar on systemd:

```bash
systemctl --user daemon-reload
systemctl --user enable mori-quickshell.service
```

In an active Niri session:

```bash
systemctl --user start mori-quickshell.service
```

The service requires an active `graphical-session.target` and uses `/usr/bin/qs`. For a manual launch or a system without systemd:

```bash
qs --no-duplicate -c mori
```

Add that command to your session startup if you want automatic launch without the service. Open **Settings** with **Mod+Period** to adjust the shell.

`mori-session` does all of this for you on any distribution: run it from a TTY (or let the login screen below run it) and it starts `niri-session` on systemd, or a D-Bus session with Niri and the bar elsewhere, after loading your login shell's environment.

## Updating the dotfiles

Review incoming changes, pull from the checkout, and relink packages when new files are added:

```bash
git pull
stow -R -t ~ bin quickshell
```

Include any other installed packages that changed. Local edits may need to be resolved before pulling. Restart the bar to load QML changes (`systemctl --user restart mori-quickshell.service` when using the service).

## Zen Browser

Launch Zen once to create a profile. Find its root directory in `about:profiles`, close Zen, and link the theme into that profile:

```bash
mkdir -p /path/to/zen/profile/chrome
ln -s "$PWD/zen/userChrome.css" /path/to/zen/profile/chrome/userChrome.css
```

Replace the example profile path with yours and back up any existing `userChrome.css` first. Copying the CSS instead is also an option. Enable `toolkit.legacyUserProfileCustomizations.stylesheets` in `about:config` and restart Zen.

## Login screen (mori-greeter)

Mori's own login screen, mori-greeter, runs on greetd and uses Kiri, the same fog engine as mori-lock: your last wallpaper under settled fog, the last user filled in (Tab to type another), and logging in clears the fog before Niri starts. It needs greetd, `jq`, and Literata in the system fonts (see SDDM below). Suspend, restart and power off icons sit in the bottom right corner (click or Tab + Enter, twice to confirm); they run a copy of `mori-power`.

The login screen runs as greetd's own user (`greeter`, or `_greeter` on Void), which cannot read your home directory, so `mori-greeter-install` copies its files instead of using Stow. It finds that user, keeps the terminal your distribution's greetd config uses, copies Literata to `/usr/local/share/fonts`, and tells you how to enable the service on your init system. Logging in runs a copy of `mori-session`:

```bash
mori-greeter-install --preview   # try it in your session: any password but "wrong" works, Escape quits
mori-greeter-install             # copy to /usr/share/mori-greeter and /etc/greetd (asks for sudo)
sudo systemctl disable sddm && sudo systemctl enable greetd    # systemd
sudo rm /var/service/sddm; sudo ln -s /etc/sv/greetd /var/service/   # runit (Void)
```

Run `mori-greeter-install` again after pulling changes to the login screen. Mori keeps `/var/lib/mori-greeter` up to date with your light/dark mode, clock format, and wallpapers. To go back, swap the two services: `sudo systemctl disable greetd && sudo systemctl enable sddm`.

## SDDM

With SDDM installed, deploy its theme to the system root rather than your home directory:

```bash
sudo stow --simulate -v -t / sddm
sudo stow -t / sddm
sudo cp -r fonts/.local/share/fonts/literata /usr/local/share/fonts/
sudo fc-cache -f /usr/local/share/fonts/literata
```

Resolve existing conflicts and check other SDDM theme overrides before deploying. This selects the Mori theme; enabling SDDM as your login manager is a separate step.
