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
colordiff
deadbeef
devtools
displaycal
dnscrypt-proxy
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
lib32-alsa-lib
lib32-alsa-plugins
lib32-giflib
lib32-gnutls
lib32-gst-plugins-base-libs
lib32-gtk3
lib32-libjpeg-turbo
lib32-libldap
lib32-libpng
lib32-libpulse
lib32-libva
lib32-libxcomposite
lib32-libxinerama
lib32-libxslt
lib32-mpg123
lib32-ncurses
lib32-openal
lib32-sdl2
lib32-v4l-utils
lib32-vulkan-icd-loader
"

AUR="
bootiso
checkrestart
cylon
discord
downgrade
duplicati2-beta
firefox-beta-bin
firefox-nightly
fsearch-git
kf5-servicemenus-copypath
kf5-servicemenus-md5sha1calc
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

echo -e "Doing full update first:\n"
sudo pacman -Syu
echo -e "\n\nInstalling ABS packages:\n"
sudo pacman -S --noconfirm --needed $ABS
sudo pacman -S --noconfirm --needed $WINE_OPT_DEPS
echo -e "\n\n"

if [ ! -f /usr/bin/yay ]; then
    echo -e "Installing yay:\n"
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin && \
    makepkg -sric --noconfirm --needed && \
    cd ../ && \
    rm -rf yay-bin
else
    echo -e "/usr/bin/yay already found"
fi

if [ -f /usr/bin/yay ]; then
    echo -e "\nInstalling AUR packages:\n"
    yay -S --noconfirm --needed $AUR
else
    echo -e "\nERROR: /usr/bin/yay not found, can't install AUR packages"
fi
