#!/bin/bash
# set -x # For Debugging
set -euo pipefail

# Arch Linux UEFI install script
# Usage:
# curl -sL https://git.io/vxwvx > install.sh
# Edit script as needed, (nano install.sh)
# chmod +x install.sh
# ./install.sh

###################
## Configuration ##
###################

# Partitioning
# If these partitions do not exist, either make them or set WIPE_EFI_DISK and/or WIPE_ROOT_DISK to true
EFI_PART='/dev/sda1'
ROOT_PART='/dev/sda2'

# These need to be true if containing disk is not GPT or corresponding partitions don't exist
# If EFI and ROOT are on same disk then either can be set to true (disk will only be wiped once)
# If the containing disks are being wiped then partition numbers specified above will be ignored
WIPE_EFI_DISK='false' # true: disk containing EFI_PART will be zapped and wiped
WIPE_ROOT_DISK='false' # true: disk containing ROOT_PART will be zapped and wiped

# These are irrelevant if containing disk is being wiped (since they would be wiped anyway)
WIPE_EFI_PART='false' # true: EFI partition will be wiped. Shouldn't be true if you want to keep other OS in EFI
WIPE_ROOT_PART='true' # true: ROOT partition will be wiped. Should normally be true

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
P_COLOR='false'

# User
USER_NAME='arch'
ROOT_PASSWORD='archlinux'
USER_PASSWORD='archlinux'

# Grpahics Drivers
NVIDIA='linux-headers nvidia-dkms lib32-nvidia-utils nvidia-settings'
VIRTUALBOX='virtualbox-guest-utils virtualbox-guest-modules-arch'
GRAPHICS=$VIRTUALBOX

# Xorg
#XORG='xorg-server xorg-apps xorg-xinit xorg-twm xorg-xclock xterm'
XORG='xorg'

# Desktop Env
PLASMA='plasma-desktop kinfocenter kde-gtk-config breeze-gtk user-manager kscreen powerdevil'
DESKTOP=$PLASMA

# Essential Packages
ESSENTIALS='konsole dolphin kate firefox'

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
#exec 1> >(tee "stdout.log")
#exec 2> >(tee "stderr.log")

# Show user config
printf "\nYour Configuration\n
==============================================
 EFI                   | %s
 ROOT                  | %s
 Wipe EFI Disk         | %s
 Wipe ROOT Disk        | %s
 Wipe EFI Partition    | %s
 Wipe ROOT Partition   | %s
 EFI Size              | %s
 ROOT Size             | %s
 
 Mirrorlist            | %s
 Timezone              | %s
 Locale                | %s
 Keymap                | %s
 Hostname              | %s
 Trim                  | %s
 
 Pacman Multilib       | %s
 Pacman Color          | %s 
 Username              | %s
 Graphics              | %s
 Xorg                  | %s
 Desktop               | %s
 Essentials            | %s
==============================================
  \n" "$EFI_PART" "$ROOT_PART" "$WIPE_EFI_DISK" "$WIPE_ROOT_DISK" \
"$WIPE_EFI_PART"  "$WIPE_ROOT_PART" "$EFI_PART_SIZE" "$ROOT_PART_SIZE" \
"$MIRROR" "$TIMEZONE" "$LOCALE" "$KEYMAP" "$HOSTNAME" "$TRIM" "$P_MULTILIB" \
"$P_COLOR" "$USER_NAME" "$GRAPHICS" "$XORG" "$DESKTOP" "$ESSENTIALS"
lsblk
echo
read -p "Is this correct? (y/n):  " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    printf 'Please change the settings at the start of the script.\n'
    exit 1
fi

# Check Network
echo -e "Testing Network\n"
if ! ping -c 3 www.archlinux.org; then
    echo "Network ping check failed. Cannot continue."
    exit 1
fi

# Check UEFI
echo -e "\nChecking if booted in UEFI mode\n"
if [[ ! -d /sys/firmware/efi ]]; then
    echo -e "\nNot booted in UEFI mode. Cannot continue\n"
    exit 1
fi 

# System clock
echo -e "\nSetting System clock\n"
timedatectl set-ntp true
timedatectl set-timezone $TIMEZONE
timedatectl status

# Make partitions
SAME_DEVICE='false'
EFI_DISK=${EFI_PART%?}
ROOT_DISK=${ROOT_PART%?}

if [[ $EFI_DISK == "$ROOT_DISK" ]]; then
    SAME_DEVICE='true'
fi

if [[ $SAME_DEVICE == "true" && $WIPE_EFI_DISK == 'true' || $WIPE_ROOT_DISK == 'true' ]]; then
    echo -e "Wiping $EFI_DISK\n"
    sgdisk --zap-all $EFI_DISK
    wipefs -a $EFI_DISK
    EFI_PART=${EFI_DISK}1
    ROOT_PART=${ROOT_DISK}2
    
    echo -e "\nPartitioning $EFI_DISK\n"
    parted -s $EFI_DISK \
    mklabel gpt \
    mkpart ESP fat32 1MiB $EFI_PART_SIZE \
    set ${EFI_PART:~0} boot on \
    mkpart primary ext4 $EFI_PART_SIZE $ROOT_PART_SIZE
fi

if [[ $WIPE_EFI_DISK == 'true' && $SAME_DEVICE != 'true' ]]; then
    echo -e "Wiping $EFI_DISK\n"
    sgdisk --zap-all $EFI_DISK
    wipefs -a $EFI_DISK
    EFI_PART=${EFI_DISK}1
    
    echo -e "\nPartitioning $EFI_DISK\n"
    parted -s $EFI_DISK \
    mklabel gpt \
    mkpart ESP fat32 1MiB $EFI_PART_SIZE \
    set ${EFI_PART:~0} boot on
fi

if [[ $WIPE_ROOT_DISK == 'true' && $SAME_DEVICE != 'true' ]]; then
    echo -e "Wiping $ROOT_DISK\n"
    sgdisk --zap-all $ROOT_DISK
    wipefs -a $ROOT_DISK
    ROOT_PART=${ROOT_DISK}1
    
    echo -e "\nPartitioning $ROOT_DISK\n"
    parted -s $ROOT_DISK \
    mklabel gpt \
    mkpart primary ext4 1MiB $ROOT_PART_SIZE
fi

# Format partitions
if [[ $WIPE_EFI_PART == 'true' || $WIPE_EFI_DISK == 'true' || $SAME_DEVICE == 'true' ]]; then
    echo -e "\nFormatting $EFI_PART for EFI\n"
    wipefs $EFI_PART
    mkfs.vfat -F32 $EFI_PART
fi

if [[ $WIPE_ROOT_PART == 'true' || $WIPE_EFI_DISK == 'true' || $SAME_DEVICE == 'true' ]]; then 
    echo -e "\nFormatting $ROOT_PART for ROOT\n"
    wipefs $ROOT_PART
    mkfs.ext4 $ROOT_PART
fi

# Mount partitions
echo -e "\nMounting $ROOT_PART as ROOT\n"
mount $ROOT_PART /mnt
mkdir -p /mnt/boot/efi
echo -e "\Mounting $EFI_PART as EFI\n"
mount $EFI_PART /mnt/boot/efi

# Mirrorlist
echo -e "\nSetting Mirrorlist: $MIRROR\n"
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup 
wget "https://www.archlinux.org/mirrorlist/?country=${MIRROR}&use_mirror_status=on" -O /etc/pacman.d/mirrorlist
sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist

# Base system
echo -e "\nInstalling base system\n"
pacstrap /mnt base base-devel
genfstab -U /mnt >> /mnt/etc/fstab

# Config
echo -e "\nSetting misc settings\n"
arch-chroot /mnt ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
arch-chroot /mnt hwclock --systohc --utc
sed -i "s/^#$LOCALE/$LOCALE/" /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=$LOCALE" > /mnt/etc/locale.conf
echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf
echo "$HOSTNAME" > /mnt/etc/hostname
[[ $TRIM == 'true' ]] && arch-chroot /mnt systemctl enable fstrim.timer

# Pacman
echo -e "\nSetting up Pacman\n"
[[ $P_MULTILIB == 'true' ]] && sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
[[ $P_COLOR == 'true' ]] && sed -i 's/#Color/Color/' /mnt/etc/pacman.conf
arch-chroot /mnt pacman -Syu --noconfirm

# User
echo -e "\nSetting up user: $USER_NAME\n"
arch-chroot /mnt useradd -m -G wheel -s /bin/bash $USER_NAME
echo -e "%wheel ALL=(ALL) ALL\nDefaults rootpw" > /mnt/etc/sudoers.d/99_wheel 
echo "$USER_NAME:$USER_PASSWORD" | chpasswd --root /mnt
echo "root:$ROOT_PASSWORD" | chpasswd --root /mnt

echo -e "\nStart of packages installation\n"

# Graphics Drivers
echo -e "Installing Graphics Drivers\n"
arch-chroot /mnt pacman -S --noconfirm $GRAPHICS
[[ $GRAPHICS == "$VIRTUALBOX" ]] && arch-chroot /mnt systemctl enable vboxservice

# Xorg
echo -e "\nInstalling Xorg\n"
arch-chroot /mnt pacman -S --noconfirm $XORG

# Desktop Env
echo -e "\nInstalling Desktop Environment\n"
arch-chroot /mnt pacman -S --noconfirm $DESKTOP
if [[ $DESKTOP == "$PLASMA" ]]; then
    arch-chroot /mnt pacman -S --noconfirm sddm sddm-kcm
    arch-chroot /mnt systemctl enable sddm
fi

# Audio
echo -e "\nInstalling Audio\n"
arch-chroot /mnt pacman -S --noconfirm pulseaudio pulseaudio-alsa pulseaudio-bluetooth
[[ $DESKTOP == "$PLASMA" ]] && arch-chroot /mnt pacman -S --noconfirm plasma-pa

# Network
echo -e "\nInstalling Network\n"
arch-chroot /mnt pacman -S --noconfirm networkmanager
arch-chroot /mnt systemctl enable NetworkManager
[[ $DESKTOP == "$PLASMA" ]] && arch-chroot /mnt pacman -S --noconfirm plasma-nm

# Bluetooth
echo -e "\nInstalling Bluetooth\n"
arch-chroot /mnt pacman -S --noconfirm bluez bluez-utils
arch-chroot /mnt systemctl enable bluetooth
[[ $DESKTOP == "$PLASMA" ]] && arch-chroot /mnt pacman -S --noconfirm bluedevil

# Essential Packages
echo -e "\nInstalling Essential Packages\n"
arch-chroot /mnt pacman -S --noconfirm $ESSENTIALS

# Boot Manager/loader
echo -e "\nInstalling Boot Manager: Refind\n"
ROOT_UUID="$(blkid -s UUID -o value "$ROOT_PART")"
arch-chroot /mnt pacman -S --noconfirm refind-efi
[[ ! -f "/mnt/boot/efi/EFI/refind/refind_x64.efi" ]] && arch-chroot /mnt refind-install
if [[ $GRAPHICS == "$VIRTUALBOX" ]]; then
    echo '\EFI\refind\refind_x64.efi' > /mnt/boot/efi/startup.nsh
fi
cat << EOF > /mnt/boot/refind_linux.conf
"Boot using default options"     "root=UUID=$ROOT_UUID rw add_efi_memmap"
"Boot using fallback initramfs"  "root=UUID=$ROOT_UUID rw add_efi_memmap initrd=/boot/initramfs-linux-fallback.img"
"Boot to terminal"               "root=UUID=$ROOT_UUID rw add_efi_memmap systemd.unit=multi-user.target"
EOF

printf "\n
======================
 Install finished...
======================\n"
read -p "Reboot? (y/n):  " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    printf 'Done!\n'
else
    echo 'Unmounting /mnt'
    umount -R /mnt
    echo 'Restarting in 3 seconds...'
    sleep 3
    reboot
fi