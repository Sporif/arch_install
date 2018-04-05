#!/bin/bash

# ABS:
pkgs="
android-tools
android-udev
ark
cantata
displaycal
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
kdiff3
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
wine-staging
winetricks
wireguard-dkms
wireguard-tools
"
for pkg in $pkgs; do 
    pacman -S --noconfirm --needed $pkg
done

# AUR:
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -sric
cd ../
rm -rf yay-bin

pkgs="
discord
dnscrypt-proxy-go
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
for pkg in $pkgs; do 
    yay -S --noconfirm $pkg
done
