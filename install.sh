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
LOCALE='LANG=en_GB.UTF-8'

# Hostname.
HOSTNAME='sporif-pc'

# Timezone.
TIMEZONE='Europe/London'

# Main user to create (sudo permissions).
USER='sporif'

# Graphics drivers
#GRAPHICS="i915"
#GRAPHICS="nouveau"
#GRAPHICS="radeon"
GRAPHICS="virtualbox-guest-utils virtualbox-guest-modules-arch"

# Display Enviroment
DISPLAY='plasma'

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
 Display               | %s
 Essential Apps        | %s
==============================================
  \n" "$DISTRO" "$DISK" "$BOOT_PART_SIZE" "$ROOT_PART_SIZE" "$ENCRYPTION" "$MIRROR" \
  "$KEYMAP" "$HOSTNAME" "$TIMEZONE" "$USER" "$GRAPHICS" "$DISPLAY" "$ESSENTIALS"
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
    BOOT_PART=${DISK}1
    ROOT_PART=${DISK}2
    mkfs.vfat -F32 $BOOT_PART
    mkfs.ext4 $ROOT_PART
    echo 'Done!'
}

mount_partition() {
  echo
  echo "Mounting disks..."
  echo
  mount ROOT_PART /mnt
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
  echo -e "KEYMAP=$KEYMAP" > /etc/vconsole.conf
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
  cp install.sh /mnt/root/install.sh
  chmod +x /mnt/root/install.sh
  echo
  echo "Done!"
  echo
  echo 'Entering chroot...'
  arch-chroot /mnt /root/install.sh setupchroot
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
  echo
  echo "Done!"
}

set_hostname() {
  echo
  echo 'Setting hostname...'
  echo -e "$HOSTNAME" >> /etc/hostname
  echo
  echo "Done!"
}

setup_pacman() {
  echo
  echo 'Initialize pacman...'
  pacman-key --init
  pacman-key --populate archlinux
  sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
  echo
  echo "Done!"
}

setup_user() {
  echo
  echo 'Add sudoers user...'
  useradd -m -G wheel,storage,power -s /bin/bash $USER
  sed -i "s/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" /etc/sudoers
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
  pacman -Sy --noconfirm "$GRAPHICS"
  if [[ $GRAPHICS == "virtualbox-guest-modules-arch virtualbox-guest-utils" ]]
  then
    systemctl enable vboxservice.service
  fi
  echo
  echo "Done!"
}

install_xorg() {
    echo
    echo 'Installing graphics...'
    pacman -Sy --noconfirm xorg-server xorg-apps xorg-xinit xorg-twm xorg-xclock xterm
    echo
    echo "Done!"
}

install_desktop() {
  echo
  echo "Installing $DISPLAY..."
  pacman -Sy --noconfirm $DISPLAY
  if [[ $DISPLAY == plasma ]]
  then
    pacman -Sy --noconfirm sddm
    systemctl enable sddm.service
  fi
  echo
  echo "Done!"
}

install_essentials() {
    echo 
    echo "Installing essential applications..."
    pacman -Sy --noconfirm "$ESSENTIALS"
}

install_boot() {
  echo
  echo 'Installing boot...'
  get_uuid="$(blkid -s UUID -o value "$ROOT_PART")"
  mkinitcpio -p linux
  pacman -Sy --noconfirm refind-efi
  refind-install --usedefault $BOOT_PART --alldrivers
  cat << EOF > /path/to/your/file
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
  if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
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
if [ "$(id -u)" -ne 0 ]
then
  echo -e "\n\nRun as root!\n\n"
  exit -1
fi

# Check if chroot before startup.
if [[ $1 == setupchroot ]]
then
  echo "Starting chroot setup..."
  set_timezone
  set_locale
  set_hostname
  setup_pacman
  setup_user
  install_network
  install_graphics
  install_desktop
  install_essentials
  install_boot
  exit 0
else
  startup
fi

_reboot