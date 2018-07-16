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
bridge-utils
colordiff
deadbeef
displaycal
dnsmasq
dnscrypt-proxy
ebtables
expac
filelight
firefox
git
glances
gsmartcontrol
gwenview
handbrake
htop
iotop
jdk8-openjdk
jre8-openjdk
kcalc
kdeconnect
latte-dock
libreoffice-fresh
libva-vdpau-driver
libvirt
lostfiles
ncdu
neofetch
nethogs
noto-fonts
ntfs-3g
obs-studio
okular
openssh
ovmf
pacman-contrib
pacutils
papirus-icon-theme
partitionmanager
pkgstats
qbittorrent
qemu
reflector
rsync
spectacle
speedtest-cli
sshfs
steam
systemdgenie
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
lib32-libpulse
lib32-openal
lib32-vulkan-icd-loader
"

AUR="
checkrestart
cylon
discord
downgrade
duplicati2-beta
firefox-beta-bin
firefox-nightly
freefilesync
fsearch-git
kf5-servicemenus-md5sha1calc
masterpassword-gui
pacolog
pkgbrowser
plasma5-applets-kde-arch-update-notifier-git
plasma5-applets-volumewin7mixer
qmasterpassword
qtwebflix-git
simple-mtpfs
spectre-meltdown-checker
vivaldi
vivaldi-codecs-ffmpeg-extra-bin
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
