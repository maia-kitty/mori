# Install Mori

[README](../README.md) · [Functions and shortcuts](functions.md)

## 1. Install dependencies

Use your distribution’s package manager to install GNU Stow and the [desktop dependencies](../README.md#desktop-dependencies). Package names vary by distribution. Install only the optional applications you want.

Install Symbols Nerd Font, adw-gtk3, and the Adwaita icons/cursor separately. Old Standard TT, IBM Plex Mono, and their font licenses are bundled. For Qt styling, install qt5ct and qt6ct-kde; Niri sets their platform-theme variables. Qt 5 uses its native palette, while Qt 6 and KDE apps use the bundled `Mori.colors` scheme. Rebuild qt6ct-kde after a Qt minor-version update if its theme plugin stops loading.

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

## 4. Start the desktop

Start a Niri session through your login manager or your usual session launcher. Its config starts `awww-daemon` and clipboard history automatically.

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

## SDDM

With SDDM installed, deploy its theme to the system root rather than your home directory:

```bash
sudo stow --simulate -v -t / sddm
sudo stow -t / sddm
sudo cp -r fonts/.local/share/fonts/old-standard-tt /usr/local/share/fonts/
sudo fc-cache -f /usr/local/share/fonts/old-standard-tt
```

Resolve existing conflicts and check other SDDM theme overrides before deploying. This selects the Mori theme; enabling SDDM as your login manager is a separate step.
