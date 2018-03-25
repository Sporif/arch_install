#!/bin/bash

###################
## Configuration ##
###################

VERSION="BETA1"
#
# title="Install Wizard"
# backtitle="Archlinux Installer $VERSION"

# Distribution
DISTRO='Archlinux'

# Install disk location.
DISK='/dev/sda'
BOOT_PART=${DISK}1
ROOT_PART=${DISK}2
    
# Partitioning
# Boot 100M or more
BOOT_PART_SIZE=500M
# Root 20G or 100%
ROOT_PART_SIZE=100%

# Encrypt disk but leave boot parition (Yes/No).
ENCRYPTION='No'

# Download mirror location, use your country code.
MIRROR='GB'

# Keymap.
KEYMAP='us'

# Locale.
LOCALE='en_GB.UTF-8'

# Hostname.
HOSTNAME='sporif-pc'

# Timezone.
TIMEZONE='Europe/London'

# Main user to create (sudo permissions).
USER='sporif'

# Graphics drivers
INTEL="i915"
NVIDIA="nouveau"
AMD="radeon"
VIRTUALBOX='virtualbox-guest-utils virtualbox-guest-modules-arch'
GRAPHICS=$VIRTUALBOX

# Xorg packages
#XORG='xorg-server xorg-apps xorg-xinit xorg-twm xorg-xclock xterm'
XORG='xorg'

# Desktop Enviroment
PLASMA='plasma-desktop'
DESKTOP=$PLASMA

# Audio packages
AUDIO='pulseaudio pulseaudio-alsa'

# Essential Applications
ESSENTIALS='konsole dolphin kate firefox'

startup() {
    printf "\nChecking your Configuration... \n
==============================================
 Script Version        | $VERSION
----------------------------------------------
 Distribution          | %s
 Disk                  | %s
 Boot partition size   | %s
 Root partition size   | %s
 Encryption            | %s
 Mirrorlist            | %s
 Keymap                | %s
 Hostname              | %s
 Timezone              | %s
 User                  | %s
 Graphics              | %s
 Xorg                  | %s
 Desktop               | %s
 Audio                 | %s
 Essentials            | %s
==============================================
  \n" "$DISTRO" "$DISK" "$BOOT_PART_SIZE" "$ROOT_PART_SIZE" "$ENCRYPTION" "$MIRROR" "$KEYMAP" \
  "$HOSTNAME" "$TIMEZONE" "$USER" "$GRAPHICS" "$XORG" "$DESKTOP" "$AUDIO" "$ESSENTIALS"
    lsblk
    echo
    read -p "Is this correct? (y/n):  " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        printf 'Please fix your Configuration at the start of the script.\n'
        exit 1
    else
        echo
        setup
    fi
}

setup() {
    parition
    format_partition
    mount_partition
    mirrorlist_update
    set_keymap
    install_base
    _chroot
}

setup_systemclock() {
    echo
    echo "Update the system clock..."
    echo
    timedatectl set-ntp true
    echo
    echo "Done!"
}

parition() {
    echo "Partitioning for EFI..."
    parted -s "$DISK" \
    mklabel gpt \
    mkpart ESP fat32 1M $BOOT_PART_SIZE \
    set 1 boot on \
    mkpart primary ext4 $BOOT_PART_SIZE $ROOT_PART_SIZE \
    echo "Done!"
}

format_partition() {
    echo
    echo "Formatting partitions..."
    echo
    mkfs.vfat -F32 $BOOT_PART
    mkfs.ext4 $ROOT_PART
    echo 'Done!'
}

mount_partition() {
  echo
  echo "Mounting disks..."
  echo
  mount $ROOT_PART /mnt
  mkdir -p /mnt/boot/efi
  mount $BOOT_PART /mnt/boot/efi
  echo
  echo "Partition mount successful!"
}

mirrorlist_update() {
  echo
  echo 'Updating mirrorlist...'
  rm /etc/pacman.d/mirrorlist
  wget https://www.archlinux.org/mirrorlist/?country=$MIRROR -O /etc/pacman.d/mirrorlist
  sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist
  echo 'Done!'
}

set_keymap() {
  echo
  echo 'Setting keymap...'
  echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
  echo
  echo "Done!"
}

install_base() {
  echo
  echo 'Installing base...'
  pacstrap /mnt base base-devel
  genfstab -U /mnt >> /mnt/etc/fstab
  echo
  echo "Done!"
}

_chroot() {
  echo
  echo 'Copying script to chroot...'
  PathToMe="${0}"
  MyName="${0##*/}"
  cp "$PathToMe" "/mnt/root/$MyName"
  chmod +x "/mnt/root/$MyName"
  echo
  echo "Done!"
  echo
  echo 'Entering chroot...'
  arch-chroot /mnt "/root/$MyName" setupchroot
}

set_timezone() {
  echo
  echo 'Setting timezone...'
  ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
  hwclock --systohc --utc
  echo
  echo 'Done!'
}

set_locale() {
  echo
  echo 'Setting locale...'
  sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen
  locale-gen
  echo LANG=$LOCALE > /etc/locale.conf
  export LANG=$LOCALE
  echo
  echo "Done!"
}

set_hostname() {
  echo
  echo 'Setting hostname...'
  echo "$HOSTNAME" > /etc/hostname
  echo
  echo "Done!"
}

setup_pacman() {
  echo
  echo 'Initializing pacman...'
  pacman-key --init
  pacman-key --populate archlinux
  sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
  echo
  echo "Done!"
}

setup_user() {
  echo
  echo 'Adding sudoers user...'
  useradd -m -G wheel,storage,power -s /bin/bash $USER
  sed -i "s/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" /etc/sudoers
  echo "\nDefaults rootpw" >> /etc/sudoers
  echo
  echo "Adding root password.."
  passwd
  echo
  echo "Adding user password.."
  passwd $USER
  echo
  echo "Done!"
}

install_network() {
  echo
  echo 'Installing network...'
  pacman -Sy --noconfirm networkmanager
  systemctl enable NetworkManager.service
  echo
  echo "Done!"
}

install_graphics() {
  echo
  echo 'Installing graphics...'
  pacman -Sy --noconfirm $GRAPHICS
  if [[ $GRAPHICS == $VIRTUALBOX ]]; then
    systemctl enable vboxservice.service
  fi
  echo
  echo "Done!"
}

install_xorg() {
    echo
    echo 'Installing xorg...'
    pacman -Sy --noconfirm $XORG
    echo
    echo "Done!"
}

install_desktop() {
  echo
  echo "Installing Desktop Environment..."
  pacman -Sy --noconfirm $DESKTOP
  if [[ $DESKTOP == $PLASMA ]]; then
    pacman -Sy --noconfirm sddm
    echo -e '[Theme]\nCurrent=breeze' > /etc/sddm.conf
    systemctl enable sddm.service
  fi
  echo
  echo "Done!"
}

install_audio() {
    echo
    echo 'Installing audio...'
    pacman -Sy --noconfirm $AUDIO
    echo
    echo "Done!"
}

install_essentials() {
    echo 
    echo "Installing essential applications..."
    pacman -Sy --noconfirm $ESSENTIALS
    echo
    echo "Done!"
}

install_boot() {
  echo
  echo 'Installing refind...'
  get_uuid="$(blkid -s UUID -o value "$ROOT_PART")"
  pacman -Sy --noconfirm refind-efi
  refind-install
  if [[ $GRAPHICS == $VIRTUALBOX ]]; then
    echo '\EFI\refind\refind_x64.efi' > /boot/efi/startup.nsh
  fi
  cat << EOF > /boot/refind_linux.conf
"Boot using default options"     "root=UUID=${get_uuid} rw add_efi_memmap"
"Boot using fallback initramfs"  "root=UUID=${get_uuid} rw add_efi_memmap initrd=/boot/initramfs-linux-fallback.img"
"Boot to terminal"               "root=UUID=${get_uuid} rw add_efi_memmap systemd.unit=multi-user.target"
EOF
  echo
  echo "Done!"
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
      echo
      echo "Restarting in 3 seconds..."
      sleep 3
      reboot
  fi
}

# Is root running.
if [ "$(id -u)" -ne 0 ]; then
  echo -e "\n\nRun as root!\n\n"
  exit -1
fi

# Check if chroot before startup.
if [[ $1 == setupchroot ]]; then
  echo "Starting chroot setup..."
  set_timezone
  set_locale
  set_hostname
  setup_pacman
  setup_user
  install_network
  install_graphics
  install_xorg
  install_desktop
  install_audio
  install_essentials
  install_boot
  exit 0
else
  startup
fi

_reboot