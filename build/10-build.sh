#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Main Build Script
###############################################################################
# This script follows the @ublue-os/bluefin pattern for build scripts.
# It uses set -eoux pipefail for strict error handling and debugging.
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

# Enable nullglob for all glob operations to prevent failures on empty matches
shopt -s nullglob

echo "::group:: Copy Bluefin Config from Common"

# Copy just files from @projectbluefin/common (includes 00-entry.just which imports 60-custom.just)
mkdir -p /usr/share/ublue-os/just/
shopt -s nullglob
cp -r /ctx/oci/common/bluefin/usr/share/ublue-os/just/* /usr/share/ublue-os/just/
shopt -u nullglob

echo "::endgroup::"

echo "::group:: Copy Custom Files"

# Copy Brewfiles to standard location
mkdir -p /usr/share/ublue-os/homebrew/
cp /ctx/custom/brew/*.Brewfile /usr/share/ublue-os/homebrew/

# Consolidate Just Files
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >> /usr/share/ublue-os/just/60-custom.just

# Copy Flatpak preinstall files
mkdir -p /etc/flatpak/preinstall.d/
cp /ctx/custom/flatpaks/*.preinstall /etc/flatpak/preinstall.d/

# Overlay system files onto root
cp -r /ctx/custom/system_files/* /

# Overlay brew system files onto root
cp -r /ctx/oci/brew/* /

echo "::endgroup::"

echo "::group:: Install Niri and dependencies"

dnf5 install -y --setopt=install_weak_deps=False\
  niri \
  xdg-desktop-portal-gnome \
  xdg-desktop-portal-gtk \
  gnome-keyring \
  xwayland-satellite

echo "::endgroup::"

echo "::group:: Install utilities and other packages"

copr_install_isolated "avengemedia/danklinux" \
  cliphist \
  dgop \
  quickshell \
  dms-greeter \
  danksearch \
  ghostty \
  matugen

copr_install_isolated "avengemedia/dms" dms

dnf5 config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
dnf5 config-manager setopt tailscale-stable.enabled=0
dnf5 -y install --enablerepo='tailscale-stable' tailscale
dnf5 -y install \
  cava \
  default-fonts-core-emoji \
  google-noto-color-emoji-fonts \
  google-noto-emoji-fonts \
  glibc-all-langpacks \
  default-fonts \
  flatpak \
  fish \
  qt6ct \
  qt6-qtmultimedia \
  zsh

echo "::endgroup::"

echo "::group:: System Configuration"

# Enable/disable systemd services
systemctl enable podman.socket
systemctl enable greetd.service
systemctl enable tailscaled.service
systemctl enable brew-setup.service
systemctl --global add-wants niri.service dms

# Example: systemctl mask unwanted-service

echo "::endgroup::"

# Restore default glob behavior
shopt -u nullglob

echo "Custom build complete!"
