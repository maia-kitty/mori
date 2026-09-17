#!/usr/bin/env python3
"""Interactive Mori deployment. No package downloads or repository rewrites."""
import argparse
import configparser
import datetime
import os
from pathlib import Path
import shutil
import subprocess
import sys

REPO = Path(__file__).resolve().parent
PACKAGES = {
    'bin': 'Desktop helper scripts', 'niri': 'Compositor (review monitor layout)',
    'quickshell': 'Mori desktop shell', 'systemd': 'Shell user service',
    'kitty': 'Terminal', 'fuzzel': 'Launcher', 'swaylock': 'Lock screen',
    'gtk': 'GTK appearance', 'qt': 'Qt appearance (local paths adjusted)',
    'fish': 'Fish (CachyOS-specific settings)', 'nvim': 'Neovim / LazyVim',
    'yazi': 'File manager', 'btop': 'System monitor', 'fastfetch': 'System information',
    'cava': 'Audio visualizer', 'kew': 'Music player', 'equibop': 'Discord client',
}


def ask(prompt, default=False):
    reply = input(prompt + (' [Y/n] ' if default else ' [y/N] ')).strip().lower()
    return reply in ('y', 'yes') or (not reply and default)


def discover_profiles(home):
    """Use profile metadata, including absolute paths and Flatpak locations."""
    roots = [home / '.zen', home / '.config/zen',
             home / '.var/app/app.zen_browser.zen/.zen',
             home / '.var/app/app.zen_browser.zen/config/zen']
    found = {}
    for root in roots:
        ini = root / 'profiles.ini'
        if not ini.is_file():
            continue
        parser = configparser.ConfigParser(interpolation=None)
        try:
            parser.read_string(ini.read_text())
            defaults = {parser[s].get('Default') for s in parser.sections()
                        if s.startswith('Install')}
            for section in parser.sections():
                if not section.startswith('Profile'):
                    continue
                item = parser[section]
                value = item.get('Path')
                if not value:
                    continue
                path = (root / value if item.get('IsRelative', '1') == '1'
                        else Path(value)).resolve()
                if path.is_dir():
                    label = item.get('Name', path.name)
                    if item.get('Default') == '1' or value in defaults:
                        label += ' (default)'
                    found[path] = label
        except (OSError, configparser.Error) as error:
            print(f'Cannot read {ini}: {error}')
    return list(found.items())


class Installer:
    def __init__(self, home, dry_run):
        self.home = home
        self.dry_run = dry_run
        stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
        self.backup_root = home / '.local/state/mori/backups' / stamp
        self.backup_count = 0
        self.failed = False

    def backup(self, path):
        self.backup_count += 1
        dest = self.backup_root / f'{self.backup_count}-{path.name}'
        print(f'Backup: {path} -> {dest}')
        if not self.dry_run:
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(path), str(dest))

    def prepare(self, dest, source=None, content=None):
        # Avoid writing through an unrelated directory symlink.
        for parent in dest.parents:
            if parent.is_symlink() and not parent.resolve().is_relative_to(REPO):
                print(f'Skipped: parent {parent} links outside Mori.')
                self.failed = True
                return False
        exists = dest.exists() or dest.is_symlink()
        if exists and source is not None and dest.is_symlink() and dest.resolve() == source.resolve():
            return True
        if exists and content is not None and not dest.is_symlink() and dest.is_file():
            if dest.read_text() == content:
                return True
        if exists:
            print(f'Existing destination: {dest}')
            if not ask('Back it up and replace it?'):
                return False
            self.backup(dest)
        return True

    def unfold_parents(self, dest):
        # Older Stow deployments may link an entire directory into the repo.
        # Unfold it before replacing a local settings file, preserving sibling links.
        for parent in reversed(dest.parents):
            if parent.is_symlink() and parent.resolve().is_relative_to(REPO):
                source_dir = parent.resolve()
                print(f'Unfold directory link: {parent}')
                if not self.dry_run:
                    children = list(source_dir.iterdir())
                    parent.unlink()
                    parent.mkdir()
                    for child in children:
                        (parent / child.name).symlink_to(child)

    def link(self, source, dest):
        self.unfold_parents(dest)
        if not self.prepare(dest, source=source):
            return
        print(f'Link: {dest} -> {source}')
        if not self.dry_run and not (dest.is_symlink() and dest.resolve() == source.resolve()):
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.symlink_to(source)

    def write_local(self, dest, content):
        self.unfold_parents(dest)
        if not self.prepare(dest, content=content):
            return
        print(f'Local copy: {dest}')
        if not self.dry_run:
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(content)

    def stow(self, package):
        base = REPO / package
        conflicts = []
        for source in sorted(base.rglob('*')):
            if not source.is_file():
                continue
            dest = self.home / source.relative_to(base)
            # Existing links into this package are already managed by Stow.
            if (dest.exists() or dest.is_symlink()) and dest.resolve() != source.resolve():
                conflicts.append(dest)
            for parent in dest.parents:
                if parent == self.home:
                    break
                if parent.is_symlink() and not parent.resolve().is_relative_to(REPO):
                    print(f'Skipping {package}: parent {parent} links outside Mori.')
                    self.failed = True
                    return
                if parent.exists() and not parent.is_dir():
                    conflicts.append(parent)
        conflicts = list(dict.fromkeys(conflicts))
        if conflicts:
            print(f'Conflicts for {package}:')
            for dest in conflicts:
                print(f'  {dest}')
            if not ask(f'Back up these paths and install {package}?'):
                print(f'Skipped {package}.')
                return
            for dest in conflicts:
                self.unfold_parents(dest)
                self.backup(dest)
        command = ['stow', '--no-folding', '--dir', str(REPO), '--target', str(self.home), package]
        print(f'Stow: {package} -> {self.home}')
        # With simulated backups, real Stow would still see the conflicts.
        if self.dry_run and conflicts:
            print('Preview only; Stow will run after the approved backups.')
            return
        if self.dry_run:
            command.insert(1, '--simulate')
        subprocess.run(command, check=True)

    def qt(self):
        # Keep path-dependent settings as local copies; shared palette files stay linked.
        for source in sorted((REPO / 'qt').rglob('*')):
            if not source.is_file():
                continue
            dest = self.home / source.relative_to(REPO / 'qt')
            content = source.read_text()
            if '/home/martin/' in content:
                self.write_local(dest, content.replace('/home/martin/', str(self.home) + '/'))
            else:
                self.link(source, dest)

    def zen(self):
        profiles = discover_profiles(self.home)
        for index, (path, label) in enumerate(profiles, 1):
            print(f'{index}. {label}: {path}')
        choice = input('Zen profile number, full profile path, or Enter to skip: ').strip()
        if not choice:
            return
        if choice.isdigit() and 1 <= int(choice) <= len(profiles):
            profile = profiles[int(choice) - 1][0]
        else:
            profile = Path(choice).expanduser().resolve()
        if not profile.is_dir() or not (profile / 'prefs.js').is_file():
            print('Not an initialized browser profile. Open Zen once, then retry.')
            self.failed = True
            return
        print('Close Zen before installing the profile theme.')
        if not ask('Continue with this profile?'):
            return
        dest = profile / 'chrome/userChrome.css'
        if ask('Use a symlink to keep the theme in sync with Mori?', True):
            self.link(REPO / 'zen/userChrome.css', dest)
        else:
            self.write_local(dest, (REPO / 'zen/userChrome.css').read_text())
        print('In Zen about:config, enable toolkit.legacyUserProfileCustomizations.stylesheets, then restart Zen.')

    def sddm(self):
        print('SDDM installs to / and requires sudo. It does not enable the login manager.')
        subprocess.run(['sudo', 'stow', '--simulate', '--verbose', '--dir', str(REPO),
                        '--target', '/', 'sddm'], check=True)
        if not self.dry_run and ask('Apply the previewed SDDM links?'):
            subprocess.run(['sudo', 'stow', '--dir', str(REPO), '--target', '/', 'sddm'], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true', help='Preview without changing files or services')
    parser.add_argument('--target', type=Path, default=Path.home(), help='Home directory to deploy into')
    args = parser.parse_args()
    if os.geteuid() == 0:
        parser.error('Run as your normal user; only SDDM uses sudo.')
    home = args.target.expanduser().resolve()
    if not home.is_dir():
        parser.error('Target home directory must exist.')
    if not shutil.which('stow'):
        parser.error('Install GNU Stow first.')
    installer = Installer(home, args.dry_run)
    print('Mori installer' + (' — preview only' if args.dry_run else ''))
    print(f'Repository: {REPO}\nTarget: {home}')
    print('Review Niri monitor settings and Fish machine-specific paths before using them.')
    print('Desktop dependencies are listed in README.md; this installer does not download software.')
    for index, (package, description) in enumerate(PACKAGES.items(), 1):
        print(f'{index:2}. {package:10} {description}')
    selection = input('Choose package numbers separated by spaces, "all", or Enter for none: ').strip()
    names = list(PACKAGES)
    if selection == 'all':
        selected = names
    else:
        try:
            numbers = [int(value) for value in selection.split()]
            if any(number < 1 or number > len(names) for number in numbers):
                raise ValueError
            selected = list(dict.fromkeys(names[number - 1] for number in numbers))
        except ValueError:
            parser.error('Choose valid package numbers or "all".')
    print('Selected: ' + (', '.join(selected) or 'none'))
    if selected and ask('Deploy these packages?', True):
        for package in selected:
            try:
                installer.qt() if package == 'qt' else installer.stow(package)
            except (OSError, subprocess.CalledProcessError) as error:
                print(f'Failed {package}: {error}')
                installer.failed = True
    if ask('Install the Zen Browser theme?'):
        installer.zen()
    if home == Path.home().resolve():
        if ask('Preview/install the SDDM login theme?'):
            installer.sddm()
        service = home / '.config/systemd/user/mori-quickshell.service'
        if service.is_file() and ask('Enable Mori to start with the graphical session?'):
            print('Enable mori-quickshell.service (takes effect with the graphical session).')
            if not args.dry_run:
                subprocess.run(['systemctl', '--user', 'daemon-reload'], check=True)
                subprocess.run(['systemctl', '--user', 'enable', 'mori-quickshell.service'], check=True)
    print('Preview complete.' if args.dry_run else 'Installation finished. Review any skipped or failed items above.')
    print('Keep this checkout in place: installed symlinks point into it.')
    return int(installer.failed)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (EOFError, KeyboardInterrupt):
        print('\nCancelled.')
        sys.exit(130)
    except (OSError, subprocess.CalledProcessError) as error:
        print(f'Installation failed: {error}', file=sys.stderr)
        sys.exit(1)
