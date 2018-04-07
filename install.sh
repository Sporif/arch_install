#!/bin/bash
# set -x # For Debugging
set -euo pipefail

######################################
# Arch Linux UEFI install
# Download:         curl -sL https://git.io/vxwvx > install.sh
# Edit script:      nano install.sh
# Make executable:  chmod +x install.sh
# Start it:         ./install.sh
######################################

###################
## Configuration ##
###################

# Partitioning
# If these partitions do not exist, either make them or set WIPE_EFI_DISK and/or WIPE_ROOT_DISK to true
EFI_PART='/dev/sda1'
ROOT_PART='/dev/sda2'

# These need to be true if the containing disk(s) is not GPT or the partitions don't exist
# If EFI and ROOT are on same disk then either can be set to true to wipe it
# If the containing disk(s) are being wiped then partition numbers specified above will be ignored
WIPE_EFI_DISK='false' # true: disk containing EFI_PART will be zapped and wiped
WIPE_ROOT_DISK='false' # true: disk containing ROOT_PART will be zapped and wiped

# These are irrelevant if containing disk is being wiped
WIPE_EFI_PART='false' # Shouldn't be true if you want to keep other OSs in EFI
WIPE_ROOT_PART='true' # Should normally be true, unless there's data you want to keep, e.g. /home

# These are only used if containing disk is being wiped 
EFI_PART_SIZE=513MiB
ROOT_PART_SIZE=100%

# Config
MIRROR='GB'
TIMEZONE='Europe/London'
LOCALE='en_GB.UTF-8'
KEYMAP='us'
HOSTNAME='arch-pc'
TRIM='true'

# Pacman 
P_MULTILIB='true'
P_COLOR='true'

# User
USER_NAME='arch'
ROOT_PASSWORD='arch'
USER_PASSWORD='arch'

# Grpahics Drivers
NVIDIA='linux-headers nvidia-dkms lib32-nvidia-utils nvidia-settings'
VIRTUALBOX='virtualbox-guest-utils virtualbox-guest-modules-arch'
GRAPHICS=$VIRTUALBOX

# Xorg
XORG='xorg-server xorg-apps'

# Desktop Env
PLASMA='plasma-desktop sddm sddm-kcm plasma-pa plasma-nm bluedevil kinfocenter kde-gtk-config breeze-gtk \
kdeplasma-addons kwalletmanager user-manager kscreen colord-kde powerdevil konsole dolphin kate'
DESKTOP=$PLASMA

############
## Script ##
############

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
echo -e "\n${bold}Your Configuration${reset}${bold}${yellow}
==============================================
 EFI                   | $EFI_PART
 ROOT                  | $ROOT_PART
 Wipe EFI Disk         | $WIPE_EFI_DISK
 Wipe ROOT Disk        | $WIPE_ROOT_DISK
 Wipe EFI Partition    | $WIPE_EFI_PART
 Wipe ROOT Partition   | $WIPE_ROOT_PART
 EFI Size              | $EFI_PART_SIZE
 ROOT Size             | $ROOT_PART_SIZE
 
 Mirrorlist            | $MIRROR
 Timezone              | $TIMEZONE
 Locale                | $LOCALE
 Keymap                | $KEYMAP
 Hostname              | $HOSTNAME
 Trim                  | $TRIM
 
 Pacman Multilib       | $P_MULTILIB
 Pacman Color          | $P_COLOR 
 Username              | $USER_NAME
 Graphics              | $GRAPHICS
 Xorg                  | $XORG
 Desktop               | $DESKTOP
==============================================${reset}\n"
lsblk
echo
read -p "Is this correct? (y/n):  " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n${red}Please change the settings at the start of the script${reset}\n"
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
EFI_DISK=${EFI_PART%?}
ROOT_DISK=${ROOT_PART%?}

if [[ $EFI_DISK == "$ROOT_DISK" ]]; then
    SAME_DEVICE='true'
fi

if [[ $SAME_DEVICE == "true" && $WIPE_EFI_DISK == 'true' || $WIPE_ROOT_DISK == 'true' ]]; then
    echo -e "\n${cyan}Wiping $EFI_DISK${reset}\n"
    sgdisk --zap-all $EFI_DISK
    wipefs -a $EFI_DISK
    EFI_PART=${EFI_DISK}1
    ROOT_PART=${ROOT_DISK}2
    WIPE_EFI_DISK='true'
    WIPE_ROOT_DISK='true'
    
    echo -e "\n${cyan}Partitioning $EFI_DISK${reset}\n"
    parted -s $EFI_DISK \
    mklabel gpt \
    mkpart ESP fat32 1MiB $EFI_PART_SIZE \
    set ${EFI_PART:~0} boot on \
    mkpart primary ext4 $EFI_PART_SIZE $ROOT_PART_SIZE
fi

if [[ $WIPE_EFI_DISK == 'true' && $SAME_DEVICE != 'true' ]]; then
    echo -e "${cyan}Wiping $EFI_DISK${reset}\n"
    sgdisk --zap-all $EFI_DISK
    wipefs -a $EFI_DISK
    EFI_PART=${EFI_DISK}1
    
    echo -e "\n${cyan}Partitioning $EFI_DISK${reset}\n"
    parted -s $EFI_DISK \
    mklabel gpt \
    mkpart ESP fat32 1MiB $EFI_PART_SIZE \
    set ${EFI_PART:~0} boot on
fi

if [[ $WIPE_ROOT_DISK == 'true' && $SAME_DEVICE != 'true' ]]; then
    echo -e "${cyan}Wiping $ROOT_DISK${reset}\n"
    sgdisk --zap-all $ROOT_DISK
    wipefs -a $ROOT_DISK
    ROOT_PART=${ROOT_DISK}1
    
    echo -e "\n${cyan}Partitioning $ROOT_DISK${reset}\n"
    parted -s $ROOT_DISK \
    mklabel gpt \
    mkpart primary ext4 1MiB $ROOT_PART_SIZE
fi

# Format partitions
if [[ $WIPE_EFI_PART == 'true' || $WIPE_EFI_DISK == 'true' ]]; then
    echo -e "\n${cyan}Formatting $EFI_PART for EFI${reset}\n"
    wipefs $EFI_PART
    mkfs.vfat -F32 $EFI_PART
fi

if [[ $WIPE_ROOT_PART == 'true' || $WIPE_ROOT_DISK == 'true' ]]; then 
    echo -e "\n${cyan}Formatting $ROOT_PART for ROOT${reset}\n"
    wipefs $ROOT_PART
    mkfs.ext4 $ROOT_PART
fi

# Mount partitions
echo -e "${cyan}Mounting $ROOT_PART as ROOT${reset}\n"
mount $ROOT_PART /mnt
mkdir -p /mnt/boot/efi
echo -e "${cyan}Mounting $EFI_PART as EFI${reset}\n"
mount $EFI_PART /mnt/boot/efi

# Mirrorlist
echo -e "${cyan}Setting Mirrorlist: $MIRROR${reset}\n"
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup 
wget "https://www.archlinux.org/mirrorlist/?country=${MIRROR}&use_mirror_status=on" -O /etc/pacman.d/mirrorlist
sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist

# Base system
echo -e "${cyan}Installing base system${reset}\n"
pacstrap /mnt base base-devel
genfstab -U /mnt >> /mnt/etc/fstab

# Config
echo -e "\n${cyan}Setting misc settings${reset}\n"
arch-chroot /mnt ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
arch-chroot /mnt hwclock --systohc --utc
sed -i "s/^#$LOCALE/$LOCALE/" /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=$LOCALE" > /mnt/etc/locale.conf
echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf
echo "$HOSTNAME" > /mnt/etc/hostname
[[ $TRIM == 'true' ]] && arch-chroot /mnt systemctl enable fstrim.timer

# Pacman
echo -e "\n${cyan}Setting up Pacman${reset}\n"
[[ $P_MULTILIB == 'true' ]] && sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
[[ $P_COLOR == 'true' ]] && sed -i 's/#Color/Color/' /mnt/etc/pacman.conf
arch-chroot /mnt pacman -Syu --noconfirm

# User
echo -e "\n${cyan}Setting up user: $USER_NAME${reset}\n"
arch-chroot /mnt useradd -m -G wheel -s /bin/bash $USER_NAME
echo -e "%wheel ALL=(ALL) ALL\nDefaults rootpw" > /mnt/etc/sudoers.d/99_wheel 
echo "$USER_NAME:$USER_PASSWORD" | chpasswd --root /mnt
echo "root:$ROOT_PASSWORD" | chpasswd --root /mnt

# Package Installs
echo -e "${bold}${green}Start of packages installation${reset}\n"
pac-chroot() {
    arch-chroot /mnt pacman -S --noconfirm --needed "$@"
} 

# Boot Manager/loader
echo -e "${green}Installing Boot Manager: Refind${reset}\n"
ROOT_UUID="$(blkid -s UUID -o value "$ROOT_PART")"
pac-chroot refind-efi
[[ ! -f "/mnt/boot/efi/EFI/refind/refind_x64.efi" ]] && arch-chroot /mnt refind-install
if [[ $GRAPHICS == "$VIRTUALBOX" ]]; then
    echo '\EFI\refind\refind_x64.efi' > /mnt/boot/efi/startup.nsh
fi
cat << EOF > /mnt/boot/refind_linux.conf
"Boot using default options"     "root=UUID=$ROOT_UUID rw add_efi_memmap intel_idle.max_cstate=0"
"Boot using fallback initramfs"  "root=UUID=$ROOT_UUID rw add_efi_memmap intel_idle.max_cstate=0 initrd=/boot/initramfs-linux-fallback.img"
"Boot to terminal"               "root=UUID=$ROOT_UUID rw add_efi_memmap intel_idle.max_cstate=0 systemd.unit=multi-user.target"
EOF

# Graphics Drivers
echo -e "\n${green}Installing Graphics Drivers${reset}\n"
pac-chroot $GRAPHICS
[[ $GRAPHICS == "$VIRTUALBOX" ]] && arch-chroot /mnt systemctl enable vboxservice

# Xorg
echo -e "\n${green}Installing Xorg${reset}\n"
pac-chroot $XORG

# Audio
echo -e "\n${green}Installing Audio${reset}\n"
pac-chroot pulseaudio pulseaudio-alsa pulseaudio-bluetooth

# Network
echo -e "\n${green}Installing Network${reset}\n"
pac-chroot networkmanager
arch-chroot /mnt systemctl enable NetworkManager

# Bluetooth
echo -e "\n${green}Installing Bluetooth${reset}\n"
pac-chroot bluez bluez-utils
arch-chroot /mnt systemctl enable bluetooth

# Desktop Env
echo -e "\n${green}Installing Desktop Environment${reset}\n"
pac-chroot $DESKTOP
if [[ $DESKTOP == "$PLASMA" ]]; then
    arch-chroot /mnt systemctl enable sddm
fi

echo -e "${bold}${green}
======================
 Install finished...
======================${reset}\n"
