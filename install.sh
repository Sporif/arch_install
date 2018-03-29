#!/bin/bash
# set -x # Debugging
set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

###################
## Configuration ##
###################

# Partitioning
# If these partitions do not exist, either make them or set WIPE_EFI_DISK and/or WIPE_ROOT_DISK to true
# It is crucial that the correct partitions specified
EFI_PART='/dev/sda1'
ROOT_PART='/dev/sda2'

# These need to be 'true' if containing disk is not GPT or corresponding partitions don't exist
# If EFI and ROOT are on same disk then either can be set to true (disk will only be wiped once)
# If the containing disks are being wiped, but EFI and ROOT are on different disks, 
# then the partition numbers will be set to 1 (the numbers specified above will be ignored)
WIPE_EFI_DISK='false' # true: disk containing EFI_PART will be zapped and wiped
WIPE_ROOT_DISK='false' # true: disk containing ROOT_PART will be zapped and wiped

# These are irrelevant if containing disk is being wiped
WIPE_EFI_PART='false' # true: EFI partition will be wiped. Shouldn't be 'true' if you want to keep other OS in EFI
WIPE_ROOT_PART='true' # true: ROOT partition will be wiped. Should always be 'true'

# These are only used if containing disk is being wiped 
# If a partition is the first one, actual size will be 1MiB less (since it will start at 1MiB)
# Set to 100% to take remaining space 
# Make sure the sizes and paritioning make sense (i.e don't overlap, extend past disk size etc)
EFI_PART_SIZE=513MiB
ROOT_PART_SIZE=100%

# Config
MIRROR='GB'
TIMEZONE='Europe/London'
LOCALE='en_GB.UTF-8'
KEYMAP='us'
HOSTNAME='sporif-pc'
TRIM='true'

# Pacman 
P_MULTILIB='true'
P_COLOR='false'

# User
USER_NAME='sporif'
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

startup() {
    printf "\nYour Configuration\n
==============================================
 EFI                   | %s - %s
 ROOT                  | %s - %s
 
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
 Audio                 | %s
 Essentials            | %s
==============================================
  \n" "$EFI_PART" "$EFI_PART_SIZE" "$ROOT_PART" "$ROOT_PART_SIZE" \
    "$MIRROR" "$TIMEZONE" "$LOCALE" "$KEYMAP" "$HOSTNAME" "$TRIM" "$P_MULTILIB" \
    "$P_COLOR" "$USER_NAME" "$GRAPHICS" "$XORG" "$DESKTOP" "$AUDIO" "$ESSENTIALS"
    lsblk
    echo
    read -p "Is this correct? (y/n):  " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        printf 'Please change the settings at the start of the script.\n'
        exit
    else
        echo
        install
    fi
}

install() {
    # Check Network
    if ! ping -c 3 www.archlinux.org; then
        echo 'Network ping check failed. Cannot continue.'
        exit 1
    fi
    
    # Check UEFI
    if [[ ! -d /sys/firmware/efi ]]; then
        echo 'Not booted in UEFI mode. Cannot continue.'
        exit 1
    fi
    
    # System clock
    timedatectl set-ntp true
    timedatectl set-timezone $TIMEZONE
    timedatectl status
    
    # Make partitions
    EFI_DISK=${EFI_PART%?}
    ROOT_DISK=${ROOT_PART%?}
    
    if [[ $EFI_DISK == "$ROOT_DISK" && $WIPE_EFI_DISK == 'true' || $WIPE_ROOT_DISK == 'true' ]]; then
        sgdisk --zap-all $EFI_DISK
        wipefs -a $EFI_DISK
        parted -s $EFI_DISK \
        mklabel gpt \
        mkpart ESP fat32 1MiB $EFI_PART_SIZE \
        set ${EFI_PART:~0} boot on \
        mkpart primary ext4 $EFI_PART_SIZE $ROOT_PART_SIZE
        SAME_DEVICE='true'
    fi
    
    if [[ $WIPE_EFI_DISK == 'true' && $SAME_DEVICE != 'true' ]]; then
        sgdisk --zap-all $EFI_DISK
        wipefs -a $EFI_DISK
        EFI_PART=${EFI_DISK}1
        
        parted -s $EFI_DISK \
        mklabel gpt \
        mkpart ESP fat32 1MiB $EFI_PART_SIZE \
        set ${EFI_PART:~0} boot on
    fi
    if [[ $WIPE_ROOT_DISK == 'true' && $SAME_DEVICE != 'true' ]]; then
        sgdisk --zap-all $ROOT_DISK
        wipefs -a $ROOT_DISK
        ROOT_PART=${ROOT_DISK}1
        
        parted -s $ROOT_DISK \
        mklabel gpt \
        mkpart primary ext4 1MiB $ROOT_PART_SIZE
    fi
    
    # Format partitions
    if [[ $WIPE_EFI_PART == 'true' ]]; then
        wipefs $EFI_PART
        mkfs.vfat -F32 $EFI_PART
    fi
    if [[ $WIPE_ROOT_PART == 'true' ]]; then 
        wipefs $ROOT_PART
        mkfs.ext4 $ROOT_PART
    fi
    
    # Mount partitions
    mount $ROOT_PART /mnt
    mkdir -p /mnt/boot/efi
    mount $EFI_PART /mnt/boot/efi
    
    # Mirrorlist
    mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup 
    wget "https://www.archlinux.org/mirrorlist/?country=${MIRROR}&use_mirror_status=on" -O /etc/pacman.d/mirrorlist
    sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist
    pacman -Syy
    
    # Base system
    pacstrap /mnt base base-devel
    genfstab -U /mnt >> /mnt/etc/fstab
    
    # Config
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    arch-chroot /mnt hwclock --systohc --utc
    sed -i "s/^#$LOCALE/$LOCALE/" /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen
    echo "LANG=$LOCALE" > /mnt/etc/locale.conf
    echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf
    echo "$HOSTNAME" > /mnt/etc/hostname
    [[ $TRIM == 'true' ]] && arch-chroot /mnt systemctl enable fstrim.timer
    
    # Pacman
    [[ $P_MULTILIB == 'true' ]] && sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
    [[ $P_COLOR == 'true' ]] && sed -i 's/#Color/Color/' /mnt/etc/pacman.conf
    arch-chroot /mnt pacman -Syu --noconfirm
    
    # User
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash $USER_NAME
    echo -e "%wheel ALL=(ALL) ALL\nDefaults rootpw" > /etc/sudoers.d/99_wheel 
    echo "$USER_NAME:$USER_PASSWORD" | chpasswd --root /mnt
    echo "root:$ROOT_PASSWORD" | chpasswd --root /mnt
    
    # Graphics Drivers
    arch-chroot /mnt pacman -S --noconfirm $GRAPHICS
    [[ $GRAPHICS == "$VIRTUALBOX" ]] && arch-chroot /mnt systemctl enable vboxservice
    
    # Xorg
    arch-chroot /mnt pacman -S --noconfirm $XORG
    
    # Desktop Env
    arch-chroot /mnt pacman -S --noconfirm $DESKTOP
    if [[ $DESKTOP == "$PLASMA" ]]; then
        arch-chroot /mnt pacman -S --noconfirm sddm sddm-kcm
        arch-chroot /mnt systemctl enable sddm
    fi
    
    # Audio
    arch-chroot /mnt pacman -S --noconfirm pulseaudio pulseaudio-alsa pulseaudio-bluetooth
    [[ $DESKTOP == "$PLASMA" ]] && arch-chroot /mnt pacman -S --noconfirm plasma-pa
    
    # Network
    arch-chroot /mnt pacman -S --noconfirm networkmanager
    arch-chroot /mnt systemctl enable NetworkManager
    [[ $DESKTOP == "$PLASMA" ]] && arch-chroot /mnt pacman -S --noconfirm plasma-nm
    
    # Bluetooth
    arch-chroot /mnt pacman -S --noconfirm bluez bluez-utils
    arch-chroot /mnt systemctl enable bluetooth
    [[ $DESKTOP == "$PLASMA" ]] && arch-chroot /mnt pacman -S --noconfirm bluedevil
    
    # Essential Packages
    arch-chroot /mnt pacman -S --noconfirm $ESSENTIALS
    
    # Boot manager/loader
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
}

_reboot() {
    printf "\n
======================
 Install finished...
======================\n"
    read -p "Reboot? (y/n):  " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        printf 'Done!\n'
        exit
    else
        echo 'Unmounting /mnt'
        umount -R /mnt
        echo 'Restarting in 3 seconds...'
        sleep 3
        reboot
    fi
}

# Is root running.
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\n\nYou must run this as root!\n\n"
    exit 1
fi

startup
_reboot