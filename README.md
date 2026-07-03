# mac80211-mcs-patch

Kernel patch that fixes WiFi stuck at 54 Mbps when your card has fewer spatial streams than the AP's basic MCS set requires.

**Update:** Kernel version 7.0.13 and above already fixed this problem. See [this commit](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=002868623c9ad77f736f1b026ec793cb2c054d25) for details.

## The Problem

Some access points (e.g. Xfinity XB8, other 4x4 MIMO routers) include 3 or 4 spatial stream MCS indexes in their basic HT-MCS set. Linux's `mac80211` checks if your card supports **all** basic MCS rates — if it doesn't (e.g. a 2x2 card like MediaTek MT7922), HT is disabled entirely and you're stuck at 802.11a/g rates (54 Mbps max).

```
$ dmesg | grep HT
wlan0: required MCSes not supported, disabling HT
```

The card works fine using its own 2-stream rates for data — `mac80211` is just being overly strict about an AP misconfiguration you can't control.

## The Fix

A one-line patch to `ieee80211_verify_sta_ht_mcs_support()` in `net/mac80211/mlme.c` that skips the basic MCS set validation.

**Before:** 54 Mbps, no HT
**After:** ~960 Mbps, HE-MCS 9, 80MHz, 2 NSS

## Install (Arch Linux)

Requires `linux-headers` and `base-devel`:

```bash
git clone https://github.com/WoodyWoodster/mac80211-mcs-patch.git
cd mac80211-mcs-patch
sudo ./install.sh
```

This copies the script and patch to `/usr/local/share/mac80211-mcs-patch/`, installs a pacman hook for auto-rebuild on kernel updates, and builds the module for your current kernel.

Load it now (drops WiFi for ~2 seconds):

```bash
sudo bash -c 'rmmod mt7921e mt7921_common mt792x_lib mt76_connac_lib mt76 mac80211 && modprobe mac80211 && modprobe mt7921e'
```

Or just reboot.

## Install (Other Distros)

```bash
git clone https://github.com/WoodyWoodster/mac80211-mcs-patch.git
cd mac80211-mcs-patch
sudo ./rebuild-mac80211.sh
```

The rebuild script downloads the matching kernel source, applies the patch, builds, and installs the module. You'll need to re-run it after kernel updates (or set up your own hook).

## Do I Need This?

```bash
dmesg | grep "required MCSes not supported"
```

If that shows `disabling HT`, this patch is for you.

## Tested With

- **Card:** MediaTek MT7922 (mt7921e) — 2x2 WiFi 6E
- **AP:** Xfinity XB8 — 4x4 MIMO
- **Kernel:** 6.19.x

Should help any 1x1/2x2 card paired with a 3x3/4x4 AP that sets aggressive basic MCS rates. The patch is in generic `mac80211`, not driver-specific.

## Files

```
skip-basic-mcs-check.patch  # The kernel patch
rebuild-mac80211.sh          # Downloads source, patches, builds, installs
install.sh                   # Arch Linux installer (copies files + pacman hook)
91-mac80211-patch.hook       # Pacman hook for auto-rebuild on kernel updates
```

## License

MIT
