#!/usr/bin/env bash
# WinRescue ISO builder. Run on a Debian/Ubuntu x86_64 machine (or Docker) as root.
# Output: ./WinRescue.iso
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Run as root:  sudo ./build.sh"; exit 1; }
if ! command -v lb >/dev/null; then
  command -v apt-get >/dev/null || { echo "Need Debian/Ubuntu (or use Docker, see README.md)"; exit 1; }
  apt-get update && apt-get install -y live-build debootstrap xorriso squashfs-tools ca-certificates
fi

WORK="$HERE/work"; rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"

lb config \
  --distribution bookworm --architectures amd64 \
  --archive-areas "main contrib non-free non-free-firmware" \
  --binary-images iso-hybrid --bootloaders "syslinux,grub-efi" \
  --debian-installer none --memtest none \
  --iso-volume WINRESCUE --iso-application "WinRescue" --iso-publisher "WinRescue" \
  --bootappend-live "boot=live components quiet loglevel=3" \
  --apt-indices false --apt-recommends false

mkdir -p config/package-lists config/includes.chroot config/hooks/normal
cat > config/package-lists/winrescue.list.chroot <<'EOF'
live-boot live-config systemd-sysv linux-image-amd64 initramfs-tools
xserver-xorg-core xserver-xorg-video-all xserver-xorg-input-libinput xinit x11-xserver-utils openbox
python3 python3-gi gir1.2-gtk-3.0 fonts-dejavu-core adwaita-icon-theme
gdisk parted util-linux dosfstools ntfs-3g libhivex-bin efibootmgr e2fsprogs
firmware-linux-free firmware-linux-nonfree firmware-misc-nonfree firmware-amd-graphics
bash coreutils findutils gawk sed grep mount udev kmod procps
EOF

cp -a "$HERE/overlay/." config/includes.chroot/

cat > config/hooks/normal/0100-winrescue.hook.chroot <<'EOF'
#!/bin/sh
set -e
chmod +x /usr/local/bin/wr-core /usr/local/bin/wr-session
systemctl enable winrescue.service
systemctl mask getty@tty1.service
EOF
chmod +x config/hooks/normal/0100-winrescue.hook.chroot

lb build 2>&1 | tee "$HERE/build.log"

ISO="$(ls -1 ./*.iso | head -n1)"
cp "$ISO" "$HERE/WinRescue.iso"
( cd "$HERE" && sha256sum WinRescue.iso | tee WinRescue.iso.sha256 )
echo "Done -> $HERE/WinRescue.iso"
