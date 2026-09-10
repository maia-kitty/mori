# Mori

Mori is my personal collection of desktop configuration and dotfiles.

This is a personal project, not a general-purpose configuration framework. It is shaped around my own hardware, applications, workflow, and preferences, so parts of it may need adjustment before they work on another system.

The visual theming is built around the Everforest Medium color scheme.

## AI assistance

This repository was made with AI assistance. The AI helped write, modify, organize, and troubleshoot parts of the configuration. I review and use the resulting files, but the repository should still be treated as an actively evolving personal setup rather than polished or independently audited software.

## Layout

The repository is organized for GNU Stow. Each top-level directory is a package whose contents mirror paths relative to `$HOME`.

For example, the Quickshell package is located at:

To install that package:

```bash
cd ~/mori
stow -t ~ quickshell
```

Review the files and existing symlinks before stowing on a new machine. Stow will report conflicts when another package already owns the same destination.

## Notes

- Configuration is experimental and may change without preserving backwards compatibility.
- The Mori Quickshell bar currently includes the clock, active application, network, volume, wallpaper, notifications, system tray, and power widgets.
