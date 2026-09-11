source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

#alias ssh="kitty +kitten ssh"
set -gx DMS_PRIVESC sudo

abbr -a S 'paru -S'
abbr -a Syu 'paru -Syu'
abbr -a Rns 'paru -Rns'
abbr -a Ss 'paru -Ss'
abbr -a Qi 'paru -Qi'
abbr -a Rn 'paru -Rn'
