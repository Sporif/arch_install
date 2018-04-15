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
bash-completion
cantata
displaycal
dnscrypt-proxy
expac
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
ncdu
ntfs-3g
obs-studio
okular
openssh
papirus-icon-theme
partitionmanager
pkgstats
qbittorrent
screenfetch
simple-mtpfs
speedtest-cli
steam
veracrypt
vlc
wget
wine_gecko
wine-mono
wine-staging
winetricks
wireguard-dkms
wireguard-tools
"

WINE_OPT_DEPS="
lib32-gnutls
lib32-libldap
lib32-openal
lib32-libpulse
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
sudo pacman -S --noconfirm --needed --asdeps $WINE_OPT_DEPS

if [ ! -f /usr/bin/yay ]; then
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -sric --noconfirm --needed
    cd ../
    rm -rf yay-bin
fi

yay -S --noconfirm --needed $AUR
