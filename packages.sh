#!/bin/bash

######################################
# Arch Linux packages
# Download:         curl -sL https://git.io/vxyTi > packages.sh
# Edit script:      nano packages.sh
# Make executable:  chmod +x packages.sh
# Start it:         ./packages.sh
######################################

ABS="
android-tools
android-udev
ark
cantata
displaycal
dnscrypt-proxy
filelight
firefox
git
gsmartcontrol
gwenview
handbrake
htop
iotop
jdk8-openjdk
jre8-openjdk
kcalc
kdeconnect
libreoffice-fresh
mtpfs
ncdu
ntfs-3g
obs-studio
okular
openssh
papirus-icon-theme
partitionmanager
qbittorrent
screenfetch
speedtest-cli
steam
veracrypt
vlc
wine_gecko
wine-mono
wine-staging lib32-gnutls lib32-libldap
winetricks
wireguard-dkms
wireguard-tools
"

AUR="
discord
downgrade
duplicati2-beta
firefox-beta-bin
firefox-nightly
freefilesync
fsearch-git
latte-dock-git
lostfiles
waterfox-bin
"

sudo pacman -Syu
sudo pacman -S --noconfirm --needed $ABS

if [ ! -f /usr/bin/yay ]; then
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -sric --noconfirm --needed
    cd ../
    rm -rf yay-bin
fi

yay -S --noconfirm --needed $AUR
