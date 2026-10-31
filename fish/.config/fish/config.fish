source /usr/share/cachyos-fish-config/cachyos-config.fish

# -g keeps these out of fish_variables, so no home path ends up in the repo
fish_add_path -g ~/.opencode/bin ~/.local/bin ~/.cargo/bin /opt/rocm/bin

abbr -a S 'paru -S'
abbr -a Syu 'paru -Syu'
abbr -a Rns 'paru -Rns'
abbr -a Ss 'paru -Ss'
abbr -a Qi 'paru -Qi'
abbr -a Rn 'paru -Rn'
