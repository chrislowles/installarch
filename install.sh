#!/bin/bash

# Bash Strict Mode
set -euo pipefail
IFS=$'\n\t'

# Check if the script is being run as root
if [[ $EUID -ne 0 ]]; then
	echo "SYSTEM: This script must be run as root"
	exit 1
fi

if [ ! -f "/etc/arch-release" ]; then
	echo "SYSTEM: This script is only intended to run on Arch Linux"
	exit 1
fi

echo "GPG: Killing gpg-agent processes and emptying out pacmans gnupg directory"
sleep 2
killall gpg-agent
rm -rf /etc/pacman.d/gnupg/*

echo "PACMAN/GPG: Initializing and populating pacmans keyring"
sleep 2
pacman-key --init || { echo "PACMAN/GPG: Failed to initialize pacmans keyring"; exit 1; }
pacman-key --populate archlinux || { echo "PACMAN/GPG: Failed to populate pacmans keyring"; exit 1; }

echo "PACMAN: Disabling download timeout on pkgs"
sleep 1
if ! perl -pi -e '$_ .= qq(DisableDownloadTimeout\n) if /# Misc options/' /etc/pacman.conf; then
	echo "PACMAN: Failed to disable download timeout"
	exit 1
fi

echo "PACMAN: Enabling parallel downloads and setting the max to 25"
sleep 1
if ! sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 25/' /etc/pacman.conf; then
	echo "PACMAN: Failed to enable parallel downloads"
	exit 1
fi

echo "PACMAN: Enabling color in the terminal"
sleep 1
if ! sed -i 's/#Color/Color/' /etc/pacman.conf; then
	echo "PACMAN: Failed to enable color in the terminal"
	exit 1
fi

echo "PACMAN: Adding xterm to the blocklist"
sleep 1
if ! sed -i 's/#IgnorePkg   =/IgnorePkg=xterm/' /etc/pacman.conf; then
	echo "PACMAN: Failed to add xterm to the blocklist"
	exit 1
fi

# if ! read -p "SYSTEM: Username: " un && sed -i "s/#username/$un/" creds.json && sed -i "s/#username/$un/" config.json; then
# 	sed -i "s/$un/#username/" creds.json
# 	sed -i "s/$un/#username/" config.json
# 	echo "Failed to update username in creds.json and config.json, reverted username in file back to dummy."
# 	sleep 1
# 	exit 1
# fi

# if ! read -s -p "SYSTEM: Password (Input hidden for security): " pd && sed -i "s/#password/$pd/" creds.json; then
# 	sed -i "s/$pd/#password/" creds.json
# 	echo "Failed to update password in creds.json, reverted password in file back to dummy."
# 	sleep 1
# 	exit 1
# fi

echo "PACMAN: Updating internal database and checking for updates specific to archlinux-keyring, archinstall, reflector, python and python-setuptools"
sleep 2
if ! pacman -Syy --needed archlinux-keyring archinstall reflector python python-setuptools jq; then
	echo "PACMAN: Failed to update internal database and packages specific to archlinux-keyring, archinstall, reflector, python, python-setuptools and jq"
	exit 1
fi

# if ! read -s -p "SYSTEM: Password (Input hidden for security): " pd && sed -i "s/#password/$pd/" creds.json; then
# 	sed -i "s/$pd/#password/" creds.json
# 	echo "Failed to update password in creds.json, reverted password in file back to dummy."
# 	sleep 1
# 	exit 1
# fi

yayPkgsParse () {
	# WIP testing right now
	configAsIs="config.json"
	read -e -p "SYSTEM: Optional AUR Pkgs (leave empty to skip): " -i "yay-bin protonup-qt-bin itch-setup-bin heroic-games-launcher-bin xbox-xcloud xboxdrv shutter-encoder boatswain" aur_pkgs
	configData=$(cat "$configAsIs")
	modifiedConfig=$(jq --arg items "$aur_pkgs" '.packages += ($items | split(" "))' <<< "$configData")
	echo "$modifiedConfig" > configToBe.json
	mv configToBe.json "$configAsIs"
}

if ! yayPkgsParse; then
	echo "SYSTEM: AUR packages import failed";
	exit 1
fi

echo "SYSTEM: We're about to execute the archinstall screen with the config, don't forget to add a user with sudo access"
sleep 6

echo "SYSTEM: Installing with partly generated config..."
sleep 3
#  --creds creds.json
if ! archinstall --config config.json; then
	echo "SYSTEM: Failed to install"
	exit 1
fi

echo "APPLYING GTK THEMES TO GTK FLATPAK APPS: itsfoss.com/flatpak-app-apply-theme"
sleep 2

echo "Done!... hopefully | More to do at github.com/chrishazfun/installarch under extra.sh if you want :)"