#!/bin/bash

# List installed packages not in install.sh or packages.sh

if [ ! -f install.sh ]; then 
    echo "install.sh not found in current directory"
    exit 1
fi

if [ ! -f packages.sh ]; then 
    echo "packages.sh not found in current directory"
    exit 1
fi

# install.sh
BASE="$(pacman -Sqg base base-devel xorg | sort -u)"
BOOTLOADER="$(sed -n '/BOOTLOADER="/,/"/{//b;p}' install.sh)"
ESSENTIALS="$(sed -n '/ESSENTIALS="/,/"/{//b;p}' install.sh)"
NVIDIA="$(sed -n '/NVIDIA="/,/"/{//b;p}' install.sh)"
VIRTUALBOX="$(sed -n '/VIRTUALBOX="/,/"/{//b;p}' install.sh)"
PLASMA="$(sed -n '/PLASMA="/,/"/{//b;p}' install.sh)"

# packages.sh
ABS="$(sed -n '/ABS="/,/"/{//b;p}' packages.sh)"
WINE_OPT_DEPS="$(sed -n '/WINE_OPT_DEPS="/,/"/{//b;p}' packages.sh)"
AUR="$(sed -n '/AUR="/,/"/{//b;p}' packages.sh)"
AUR_HELPER="yay-bin"


if [ -z "$(lspci | grep NVIDIA)" ]; then
    echo -e "Defaulting to virtual box\n"
fi

should_be_installed="$(echo "$BASE $BOOTLOADER $ESSENTIALS $NVIDIA $PLASMA $ABS $AUR $AUR_HELPER" | tr " " "\n" | sort)" 
#echo "$should_be_installed"

echo -e "\nChecking for installed packages not in install.sh or packages.sh"
echo "======================================================="
echo "$(echo "$should_be_installed" | wc -l) packages should be explicitly installed"
echo "$(pacman -Qeq | wc -l) packages explicitly installed"
echo

echo "$(comm -23 <(pacman -Qeq | sort) <(echo "$should_be_installed") | wc -l) extra packages installed:"
echo "======================================================="
comm -23 <(pacman -Qeq | sort) <(echo "$should_be_installed")
echo

echo "$(comm -13 <(pacman -Qeq | sort) <(echo "$should_be_installed") | wc -l) packages missing:"
echo "======================================================="
comm -13 <(pacman -Qeq | sort) <(echo "$should_be_installed")
echo
