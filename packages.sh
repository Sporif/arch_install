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
arch-install-scripts
ark
bash-completion
deadbeef
displaycal
dnsmasq
dnscrypt-proxy
ebtables
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
libvirt
ncdu
noto-fonts
ntfs-3g
obs-studio
okular
openssh
ovmf
papirus-icon-theme
partitionmanager
pkgstats
qbittorrent
qemu
reflector
rsync
screenfetch
speedtest-cli
sshfs
steam
ttf-liberation
ttf-dejavu
veracrypt
virt-manager
vlc
wget
wine-staging
wine_gecko
wine-mono
winetricks
wireguard-dkms
wireguard-tools
"

WINE_OPT_DEPS="
lib32-gnutls
lib32-libldap
lib32-openal
lib32-libpulse
lib32-vulkan-icd-loader
"

AUR="
cylon
discord
downgrade
duplicati2-beta
firefox-beta-bin
firefox-nightly
freefilesync
fsearch-git
kf5-servicemenus-md5sha1calc
latte-dock-git
lostfiles
masterpassword-gui
pacmanlogger-git
pacolog
plasma5-applets-volumewin7mixer
qtwebflix-git
simple-mtpfs
waterfox-kde-bin
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
