#!/usr/bin/env bash

# set -x # For debugging
set -euo pipefail

#######################################
# Arch Linux UEFI install
# Download:         curl -sL https://git.io/vxwvx > install.sh
# Edit script:      nano install.sh
# Make executable:  chmod +x install.sh
# Start it:         ./install.sh
#######################################

###############
## Configuration ##
###############

    ## PARTITIONING
    # If these partitions do not exist, either make them or set WIPE_EFI_DISK and/or WIPE_ROOT_DISK to true
    EFI_PART="/dev/sda1"
    ROOT_PART="/dev/sda2"

    # These need to be true if the containing disk(s) is not GPT or the partitions don't exist
    # If EFI and ROOT are on the same disk then either can be set to true to wipe it
    # If the containing disk(s) are being wiped then partition numbers specified above will be ignored
    WIPE_EFI_DISK="false" # true: the disk containing EFI_PART will be wiped
    WIPE_ROOT_DISK="false" # true: the disk containing ROOT_PART will be wiped

    # These are irrelevant if the containing disk is being wiped
    WIPE_EFI_PART="false" # Should not be true if you want to keep other OSs in EFI
    WIPE_ROOT_PART="true" # Should normally be true, unless there is data you want to keep, e.g. /home

    # These are only used if the containing disk is being wiped
    EFI_PART_SIZE="513MiB"
    ROOT_PART_SIZE="100%"

    # Root filesystem and mount flags
    ROOTFS="ext4"
    ROOTFLAGS="rw,noatime,data=ordered"

    ## SETTINGS
    MIRROR="GB"
    TIMEZONE="Europe/London"
    LOCALE="en_GB.UTF-8"
    KEYMAP="us"
    X11_KEYMAP="gb"
    HOSTNAME="arch-pc"
    USER_NAME="arch"
    ROOT_PASSWORD="arch"
    USER_PASSWORD="arch"

    ## PACKAGES
    # Base
    BASE_PKGS="base base-devel"
    # Boot Loader
    BOOTLOADER="refind-efi"
    # Xorg
    XORG="xorg"
    # Essentials
    ESSENTIALS="networkmanager pulseaudio pulseaudio-alsa pulseaudio-bluetooth bluez bluez-utils"
    # Graphics Drivers
    NVIDIA="linux-headers nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings"
    VIRTUALBOX="virtualbox-guest-utils virtualbox-guest-modules-arch"
    QEMU="spice-vdagent qemu-guest-agent xf86-video-qxl"
    GRAPHICS=$QEMU
    # Desktop Env
    PLASMA="plasma-desktop sddm sddm-kcm plasma-pa plasma-nm bluedevil kinfocenter kde-gtk-config breeze-gtk kdeplasma-addons
    kwalletmanager user-manager kaccounts-providers kscreen colord-kde powerdevil drkonqi
    konsole dolphin dolphin-plugins kate yakuake"
    DESKTOP=$PLASMA

#########
## Script ##
#########

# Colors
black=$(tput setaf 0)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
magenta=$(tput setaf 5)
cyan=$(tput setaf 6)
white=$(tput setaf 7)
bold=$(tput bold)
reset=$(tput sgr0)

# Logging
#exec 1> >(tee -i "stdout.log")
#exec 2> >(tee -i "stderr.log")

# Show user config
echo -e "\n${bold}Your configuration${reset}${bold}${yellow}
==============================================
           Partitioning:
 EFI                   | $EFI_PART
 ROOT                  | $ROOT_PART
 Wipe EFI Disk         | $WIPE_EFI_DISK
 Wipe ROOT Disk        | $WIPE_ROOT_DISK
 Wipe EFI Partition    | $WIPE_EFI_PART
 Wipe ROOT Partition   | $WIPE_ROOT_PART
 EFI Size              | $EFI_PART_SIZE
 ROOT Size             | $ROOT_PART_SIZE
 ROOT Filesystem       | $ROOTFS
 ROOT Mount flags      | $ROOTFLAGS

               Settings:
 Mirrorlist            | $MIRROR
 Timezone              | $TIMEZONE
 Locale                | $LOCALE
 Keymap                | $KEYMAP
 X11_Keymap            | $X11_KEYMAP
 Hostname              | $HOSTNAME
 Username              | $USER_NAME

               Packages:
 Base                  | $BASE_PKGS
 Boot Loader           | $BOOTLOADER
 Xorg                  | $XORG
 Essentials            | $ESSENTIALS
 Graphics              | $GRAPHICS
 Desktop               | $DESKTOP
==============================================${reset}\n"
echo -e "lsblk:\n"
lsblk
echo
read -p "Is this correct? (y/n):  " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n${red}Then change the settings at the start of the script${reset}\n"
    exit 1
fi

# Check Network
echo -e "\n${magenta}Testing Network${reset}\n"
if ! ping -c 3 www.archlinux.org; then
    echo -e "${red}Network ping check failed. Cannot continue${reset}\n"
    exit 1
fi

# Check UEFI
echo -e "\n${magenta}Checking if booted in UEFI mode${reset}\n"
if [[ ! -d /sys/firmware/efi ]]; then
    echo -e "\n${red}Not booted in UEFI mode. Cannot continue${reset}\n"
    exit 1
fi 

# System clock
echo -e "${magenta}Setting System clock${reset}\n"
timedatectl set-ntp true
timedatectl set-timezone $TIMEZONE
timedatectl status

# Make partitions
EFI_DISK=/dev/$(lsblk -no PKNAME ${EFI_PART})
ROOT_DISK=/dev/$(lsblk -no PKNAME ${ROOT_PART})

if [[ $EFI_DISK = "$ROOT_DISK" ]]; then
    SAME_DEVICE='true'
fi

if [[ $SAME_DEVICE = "true" && $WIPE_EFI_DISK = 'true' || $WIPE_ROOT_DISK = 'true' ]]; then
    echo -e "\n${cyan}Wiping $EFI_DISK${reset}\n"
    wipefs --all --force $EFI_DISK
    partprobe $EFI_DISK
    EFI_PART=${EFI_DISK}1
    ROOT_PART=${ROOT_DISK}2
    WIPE_EFI_DISK='true'
    WIPE_ROOT_DISK='true'

    echo -e "\n${cyan}Partitioning $EFI_DISK${reset}\n"
    parted -s $EFI_DISK \
    mklabel gpt \
    mkpart ESP fat32 1MiB $EFI_PART_SIZE \
    set ${EFI_PART:~0} esp on \
    mkpart primary ${ROOTFS} $EFI_PART_SIZE $ROOT_PART_SIZE
    partprobe $EFI_DISK
fi

if [[ $WIPE_EFI_DISK = 'true' && $SAME_DEVICE != 'true' ]]; then
    echo -e "${cyan}Wiping $EFI_DISK${reset}\n"
    wipefs --all --force $EFI_DISK
    partprobe $EFI_DISK
    EFI_PART=${EFI_DISK}1

    echo -e "\n${cyan}Partitioning $EFI_DISK${reset}\n"
    parted -s $EFI_DISK \
    mklabel gpt \
    mkpart ESP fat32 1MiB $EFI_PART_SIZE \
    set ${EFI_PART:~0} esp on
    partprobe $EFI_DISK
fi

if [[ $WIPE_ROOT_DISK = 'true' && $SAME_DEVICE != 'true' ]]; then
    echo -e "${cyan}Wiping $ROOT_DISK${reset}\n"
    wipefs --all --force $ROOT_DISK
    partprobe $ROOT_DISK
    ROOT_PART=${ROOT_DISK}1

    echo -e "\n${cyan}Partitioning $ROOT_DISK${reset}\n"
    parted -s $ROOT_DISK \
    mklabel gpt \
    mkpart primary ${ROOTFS} 1MiB $ROOT_PART_SIZE
    partprobe $ROOT_DISK
fi

# Format partitions
if [[ $WIPE_EFI_PART = 'true' || $WIPE_EFI_DISK = 'true' ]]; then
    echo -e "\n${cyan}Formatting $EFI_PART for EFI${reset}\n"
    wipefs --all --force $EFI_PART
    mkfs.vfat -F 32 $EFI_PART
fi

if [[ $WIPE_ROOT_PART = 'true' || $WIPE_ROOT_DISK = 'true' ]]; then 
    echo -e "\n${cyan}Formatting $ROOT_PART for ROOT${reset}\n"
    wipefs --all --force $ROOT_PART
    mkfs.${ROOTFS} $ROOT_PART
fi

# Mount partitions
MOUNT="/mnt"
echo -e "${cyan}Mounting $ROOT_PART as ROOT${reset}\n"
mkdir -p "${MOUNT}"
mount $ROOT_PART "${MOUNT}"
mkdir -p "${MOUNT}"/boot/efi
echo -e "${cyan}Mounting $EFI_PART as EFI${reset}\n"
mount $EFI_PART "${MOUNT}"/boot/efi

# Mirrorlist
echo -e "${cyan}Setting Mirrorlist: $MIRROR${reset}\n"
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup 
wget "https://www.archlinux.org/mirrorlist/?country=${MIRROR}&use_mirror_status=on" -O /etc/pacman.d/mirrorlist
sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist

# Base system
echo -e "${cyan}Installing base system${reset}\n"
pacstrap "${MOUNT}" $BASE_PKGS
EFI_UUID="$(blkid -s UUID -o value "$EFI_PART")"
cat  << EOF > "${MOUNT}"/etc/fstab
UUID=$EFI_UUID    /boot/efi        auto       rw,noatime,nofail,x-systemd.device-timeout=1,noauto,x-systemd.automount     0    2
EOF

# Settings
echo -e "\n${cyan}Setting misc settings${reset}\n"
arch-chroot "${MOUNT}" ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
arch-chroot "${MOUNT}" hwclock --systohc --utc
sed -i "s/^#$LOCALE/$LOCALE/" "${MOUNT}"/etc/locale.gen
sed -i "s/^#en_US.UTF-8/en_US.UTF-8/" "${MOUNT}"/etc/locale.gen
arch-chroot "${MOUNT}" locale-gen
echo "LANG=$LOCALE" > "${MOUNT}"/etc/locale.conf
echo "KEYMAP=$KEYMAP" > "${MOUNT}"/etc/vconsole.conf
echo "$HOSTNAME" > "${MOUNT}"/etc/hostname
cat << EOF >> "${MOUNT}"/etc/hosts
127.0.0.1       localhost
::1             localhost
127.0.0.1       ${HOSTNAME}.localdomain    $HOSTNAME
EOF
arch-chroot "${MOUNT}" systemctl enable fstrim.timer

# Pacman
echo -e "\n${cyan}Setting up Pacman${reset}\n"
sed -i "/\[multilib\]/,/Include/"'s/^#//' "${MOUNT}"/etc/pacman.conf
sed -i 's/#Color/Color/' "${MOUNT}"/etc/pacman.conf
arch-chroot "${MOUNT}" pacman -Syu --noconfirm

# User
echo -e "\n${cyan}Setting up user: $USER_NAME${reset}\n"
arch-chroot "${MOUNT}" useradd -m -G wheel -s /bin/bash $USER_NAME
echo -e "%wheel ALL=(ALL) ALL\nDefaults rootpw" > "${MOUNT}"/etc/sudoers.d/99_wheel 
echo "$USER_NAME:$USER_PASSWORD" | chpasswd --root "${MOUNT}"
echo "root:$ROOT_PASSWORD" | chpasswd --root "${MOUNT}"

# Package Installs
echo -e "${bold}${green}Start of packages installation${reset}\n"
pac-chroot() {
    arch-chroot "${MOUNT}" pacman -S --noconfirm --needed "$@"
}

# Boot Loader
echo -e "${green}Installing Boot Manager: Refind${reset}\n"
pac-chroot $BOOTLOADER
[[ ! -f "${MOUNT}/boot/efi/EFI/refind/refind_x64.efi" ]] && arch-chroot "${MOUNT}" refind-install
[[ $GRAPHICS = "$VIRTUALBOX" ]] || [[ $GRAPHICS = "$QEMU" ]] && arch-chroot "${MOUNT}" refind-install --usedefault $EFI_PART
ROOT_UUID="$(blkid -s UUID -o value "$ROOT_PART")"
BASE_BOOT_FLAGS="root=UUID=$ROOT_UUID rw intel_idle.max_cstate=0 rootflags=${ROOTFLAGS}"
cat << EOF > "${MOUNT}"/boot/refind_linux.conf
"Boot using default options"                     "${BASE_BOOT_FLAGS}"
"Boot using fallback initramfs"                 "${BASE_BOOT_FLAGS} initrd=/boot/initramfs-linux-fallback.img"
"Boot to terminal - multi-user.target"     "${BASE_BOOT_FLAGS} systemd.unit=multi-user.target"
"Boot to terminal - rescue.target"           "${BASE_BOOT_FLAGS} systemd.unit=rescue.target"
"Boot to terminal - emergency.target"   "${BASE_BOOT_FLAGS} systemd.unit=emergency.target"
"Boot to terminal - /bin/bash"                  "${BASE_BOOT_FLAGS} init=/bin/bash"
EOF

# Xorg
echo -e "\n${green}Installing Xorg${reset}\n"
pac-chroot $XORG
cat << EOF > /etc/X11/xorg.conf.d/60-keyboard-layout.conf
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "${X11_KEYMAP}"
EndSection
EOF

# Essentials
echo -e "\n${green}Installing Essentials${reset}\n"
pac-chroot $ESSENTIALS
arch-chroot "${MOUNT}" systemctl enable NetworkManager bluetooth

# Graphics Drivers
echo -e "\n${green}Installing Graphics Drivers${reset}\n"
pac-chroot $GRAPHICS
[[ $GRAPHICS = "$VIRTUALBOX" ]] && arch-chroot "${MOUNT}" systemctl enable qemu-ga
[[ $GRAPHICS = "$VIRTUALBOX" ]] && arch-chroot "${MOUNT}" systemctl enable vboxservice

# Desktop Environment
echo -e "\n${green}Installing Desktop Environment${reset}\n"
pac-chroot $DESKTOP
[[ $DESKTOP = "$PLASMA" ]] && arch-chroot "${MOUNT}" systemctl enable sddm

echo -e "${bold}${green}
==================
 Install finished
==================${reset}\n"
