#!/bin/bash
set -e

## CONFIGURATIONS ##

# Partitioning
DEVICE='/dev/sda'
EFI_PART=${DEVICE}1
ROOT_PART=${DEVICE}2
EFI_PART_SIZE=513MiB # actual size is 1MiB less
ROOT_PART_SIZE=100%
WIPE_DISK=false # true: DEVICE (or the one containg ROOT_PART) will be zapped and wiped
WIPE_EFI=false # true: EFI_PART will be wiped. false: Will not be wiped, errors out if not proper esp

# Config
MIRROR='GB'
TIMEZONE='Europe/London'
LOCALE='en_GB.UTF-8'
KEYMAP='us'
HOSTNAME='sporif-pc'
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
PLASMA='plasma-desktop kde-gtk-config breeze-gtk kscreen kinfocenter'
DESKTOP=$PLASMA

# Essential Packages
ESSENTIALS='konsole dolphin kate firefox'

## START OF SCRIPT ##

startup() {
    printf "\nYour Configuration\n
==============================================
 Device                | %s
 EFI                   | %s - %s
 ROOT                  | %s - %s
 Mirrorlist            | %s
 Timezone              | %s
 Locale                | %s
 Keymap                | %s
 Hostname              | %s
 Username              | %s
 Graphics              | %s
 Xorg                  | %s
 Desktop               | %s
 Audio                 | %s
 Essentials            | %s
==============================================
  \n" "$DEVICE" "$EFI_PART" "$EFI_PART_SIZE" "$ROOT_PART" "$ROOT_PART_SIZE" \
    "$MIRROR" "$TIMEZONE" "LOCALE" "$KEYMAP" "$HOSTNAME" "$USER_NAME" \
    "$GRAPHICS" "$XORG" "$DESKTOP" "$AUDIO" "$ESSENTIALS"
    lsblk
    echo
    read -p "Is this correct? (y/n):  " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        printf 'Please change the settings at the start of the script.\n'
        exit 1
    else
        echo
        install
    fi
}

install() {
    # Check Network
    ping -c 5 www.archlinux.org
    if [ $? -ne 0 ]; then
        echo "Network ping check failed. Cannot continue."
        exit
    fi
    
    # Make partitions
    sgdisk --zap-all $DEVICE
    wipefs -a $DEVICE
    parted -s $DEVICE \
    mklabel gpt \
    mkpart ESP fat32 1MiB $EFI_PART_SIZE \
    set ${EFI_PART:~0} boot on \
    mkpart primary ext4 $EFI_PART_SIZE $ROOT_PART_SIZE
    
    # Format partitions
    mkfs.vfat -F32 $EFI_PART
    mkfs.ext4 $ROOT_PART
    
    # Mount partitions
    mount $ROOT_PART /mnt
    mkdir -p /mnt/boot/efi
    mount $EFI_PART /mnt/boot/efi
    
    # Mirrorlist
    rm /etc/pacman.d/mirrorlist
    wget https://www.archlinux.org/mirrorlist/?country=$MIRROR -O /etc/pacman.d/mirrorlist
    sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist
    
    # Base system
    pacstrap /mnt base base-devel
    genfstab -U /mnt >> /mnt/etc/fstab
    
    # Config
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    arch-chroot /mnt hwclock --systohc --utc
    sed -i "s/^#$LOCALE/$LOCALE/" /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen
    echo LANG=$LOCALE > /mnt/etc/locale.conf
    echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf
    echo "$HOSTNAME" > /mnt/etc/hostname
    if [ -n "$(hdparm -I $DEVICE | grep TRIM)" ]; then 
        arch-chroot /mnt systemctl enable fstrim.timer
    fi
    
    # Pacman
    arch-chroot /mnt pacman-key --init
    arch-chroot /mnt pacman-key --populate archlinux
    sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
    arch-chroot /mnt pacman -Sy 
    
    # User
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash $USER_NAME
    sed -i "s/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" /mnt/etc/sudoers
    echo -e "\nDefaults rootpw" >> /mnt/etc/sudoers
    printf "$ROOT_PASSWORD\n$ROOT_PASSWORD" | arch-chroot /mnt passwd
    printf "$USER_PASSWORD\n$USER_PASSWORD" | arch-chroot /mnt passwd $USER_NAME
    
    # Graphics Drivers
    arch-chroot /mnt pacman -S --noconfirm $GRAPHICS
    if [[ $GRAPHICS == $VIRTUALBOX ]]; then
        arch-chroot /mnt systemctl enable vboxservice
    fi
    
    # Xorg
    arch-chroot /mnt pacman -S --noconfirm $XORG
    
    # Desktop Env
    arch-chroot /mnt pacman -S --noconfirm $DESKTOP
    [[ $DESKTOP == $PLASMA ]] && arch-chroot /mnt pacman -S --noconfirm sddm sddm-kcm & \
    arch-chroot /mnt systemctl enable sddm
    
    # Audio
    arch-chroot /mnt pacman -S --noconfirm pulseaudio pulseaudio-alsa pulseaudio-bluetooth
    [[ $DESKTOP == $PLASMA ]] && arch-chroot /mnt pacman -S --noconfirm plasma-pa kmix
    
    # Network
    arch-chroot /mnt pacman -S --noconfirm networkmanager
    arch-chroot /mnt systemctl enable NetworkManager
    [[ $DESKTOP == $PLASMA ]] && arch-chroot /mnt pacman -S --noconfirm plasma-nm
    
    # Bluetooth
    arch-chroot /mnt pacman -S --noconfirm bluez bluez-utils
    arch-chroot /mnt systemctl enable bluetooth
    [[ $DESKTOP == $PLASMA ]] && arch-chroot /mnt pacman -S --noconfirm bluedevil
    
    # Essential Packages
    arch-chroot /mnt pacman -S --noconfirm $ESSENTIALS
    
    # Boot manager
    ROOT_UUID="$(blkid -s UUID -o value "$ROOT_PART")"
    arch-chroot /mnt pacman -S --noconfirm refind-efi
    [[ ! -d "/mnt/boot/efi/EFI/refind" ]] arch-chroot /mnt refind-install
    if [[ $GRAPHICS == $VIRTUALBOX ]]; then
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
        exit 0
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