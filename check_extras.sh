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

GRAPHICS=$VIRTUALBOX
if [ -n "$(lspci | grep -i nvidia)" ]; then
    GRAPHICS=$NVIDIA
fi

DESKTOP=$PLASMA

should_be_installed="$(echo "$BASE $BOOTLOADER $ESSENTIALS $GRAPHICS $DESKTOP $ABS $AUR $AUR_HELPER" | tr " " "\n" | sort)" 
should_be_installed_ABS="$(echo "$BASE $BOOTLOADER $ESSENTIALS $GRAPHICS $DESKTOP $ABS" | tr " " "\n" | sort)" 
should_be_installed_AUR="$(echo "$AUR $AUR_HELPER" | tr " " "\n" | sort)"

echo -e "\nChecking for installed packages not in install.sh or packages.sh"
echo "======================================================="
echo "$(echo "$should_be_installed" | wc -l) packages should be explicitly installed"
echo "$(pacman -Qeq | wc -l) packages actually explicitly installed"
echo

ABS_NATIVE=$(pacman -Qenq | sort)
ABS_FOREIGN=$(pacman -Qemq | sort)

EXTRA_ABS=$(comm -23 <(echo "$ABS_NATIVE") <(echo "$should_be_installed_ABS"))
EXTRA_AUR=$(comm -23 <(echo "$ABS_FOREIGN") <(echo "$should_be_installed_AUR"))
MISSING_ABS=$(comm -13 <(echo "$ABS_NATIVE") <(echo "$should_be_installed_ABS"))
MISSING_AUR=$(comm -13 <(echo "$ABS_FOREIGN") <(echo "$should_be_installed_AUR"))

echo "$(echo $EXTRA_ABS | tr " " "\n" | egrep -v "(^[ ]*$|^#)" | wc -l) extra ABS packages installed:"
echo "======================================================="
echo $EXTRA_ABS | tr " " "\n"
echo

echo "$(echo $EXTRA_AUR | tr " " "\n" | egrep -v "(^[ ]*$|^#)" | wc -l) extra AUR packages installed:"
echo "======================================================="
echo $EXTRA_AUR | tr " " "\n"
echo

echo "$(echo $MISSING_ABS | tr " " "\n" | egrep -v "(^[ ]*$|^#)" | wc -l) ABS packages missing:"
echo "======================================================="
echo $MISSING_ABS | tr " " "\n"
echo

echo "$(echo $MISSING_AUR | tr " " "\n" | egrep -v "(^[ ]*$|^#)" | wc -l) AUR packages missing:"
echo "======================================================="
echo $MISSING_AUR | tr " " "\n"
echo
