# USB Wi-Fi for wireless CarPlay (RTL8811AU)

For a head unit where `wireless-carplay-aa` gets as far as the hotspot, but the built-in Wi-Fi
never comes up: `failed to power up DHD generic adapter`, nothing on `mmc1`, no `wlan0`, or no
Wi-Fi chip fitted at all. It moves the hotspot to a USB adapter in the head unit's one USB port:
a TP-Link Archer T2U Nano or Nano AC600 (RTL8811AU, USB ID `2357:011e`).

The mod, the driver patch and the `usbguard` service are by dibble9012 (Kyle Dibble-Dabney),
from [HMG-API PR #104](https://github.com/Open-HMG/HMG-API/pull/104). The Santa Fe (`TM23`)
support, the per-car driver builds and the gates below were added by Geijoh.

## Cars

| Car | Firmware | Driver | Tested |
|---|---|---|---|
| Kia Niro EV (`SG2EV`), USA | 260507 | `files/sg2ev` | On the car by dibble9012 (HMG-API #104): hotspot and CarPlay sessions of up to 7.5 minutes, with an iPhone. Nobody else has run it. |
| Hyundai Santa Fe (`TM23`), USA | `TM23.USA.0000.V016.010.260903` | `files/tm23` | On the car by one owner: wireless CarPlay works, but only with a hook that skips DiPO's `resetUSB()` (see below). |

A driver built for one car is not safe on the other (different kernel config, different struct
layouts), so each car has its own file and its own stock checksum. The mod picks the one for the
unit's product and refuses any other.

**TM23, what was tried on the car** (no Wi-Fi chip fitted; adapter plugged in; the failed runs on
wireless mod 2.2.0-rc.5, the working one on 2.2.0-rc.9):

- The driver loads and the adapter is recognised. The hotspot comes up on 5 GHz channel 149; a
  phone and a watch join it.
- Bluetooth pairing, iAP2 and the "join this network" message to the iPhone work, and the iPhone
  joins the CarPlay hotspot.
- **Wireless CarPlay works**, with `resetUSB()` skipped. The owner checked audio and media, calls,
  a session of more than 10 minutes, and a cold start with the phone reconnecting.
- Without the skip, the session does not finish. About 6 seconds after `startCarPlaySession`
  (three runs: 6.9, 6.0 and 6.0 s), the stock CarPlay app calls `resetUSB()`, which sends the
  micom the `SYS_VBUS_OFF_ON_C` command and power-cycles the USB port, which drops the adapter and
  the hotspot. `usbguard` can't stop that on a TM23: it sets the kernel's `vbus_control_enable`,
  and this reset goes through the micom instead. Skipping the call takes a hook point for
  `resetUSB()` in HMG-API ([issue #372](https://github.com/Open-HMG/HMG-API/issues/372)).
- Audio delay and Android Auto: not tested.
- The hotspot name sent to the iPhone is the CarPlay entry in `/data/misc/wifi/softap.conf`, but the
  wireless mod started the hotspot with the other entry's name. Until that is fixed in
  `wireless-carplay-aa`, set both entries to the same name and password.

## Using it

1. Install `wireless-carplay-aa`, apply, restart, switch on the unit's own hotspot once, and look
   at the Car Report's `wifi` line. `seen` means a Wi-Fi chip answered: the unit has working
   Wi-Fi and doesn't need this mod (on a Santa Fe it refuses to install; on a Niro it can't tell,
   see "Gates"). `stock hotspot`, `unpowered` or `none` means no chip answered: install this mod,
   apply, and restart.
2. Turn ADB over USB off. The port only powers the adapter in host mode.
3. Plug in the adapter and connect the iPhone over Bluetooth. Don't plug in anything else: the
   port is shared, so wired CarPlay and USB drives need the adapter out.
4. Leave the manual hotspot toggle alone. It replaces the CarPlay network with the manual hotspot.
5. Pull the adapter before turning ADB back on. While the adapter is in, port power stays on.

Removing the mod puts the stock `bcmdhd.ko` back.

## What it changes

- **`/system/wifi/bcmdhd.ko`**: the Realtek driver, under the Broadcom driver's name, so the stock
  Wi-Fi HAL loads and unloads it. It is added only over the expected stock file (below).
- **`usbguard` service**: while the adapter is present, it sets the kernel's
  `vbus_control_enable` (`/sys/module/tcc_dwc_otg/parameters/`) to 0, so a `resetUSB()` that goes
  through that parameter can't cut power to the port. When the adapter is absent, it sets it to 1.

## Gates: stock driver, and units whose Wi-Fi works

The mod replaces the Broadcom driver, so:

- **Stock checksum.** `patches/<car>/stock` holds the md5 of that car's stock `bcmdhd.ko`
  (SG2EV `144b5cf07482a7ea44ee82e3b82d0774`, TM23 `758c1a59de2e31623d96ad413e8eb5df`). HMG-API
  adds the driver only over that file and keeps its own backup; any other `bcmdhd.ko` is refused
  and left alone. Removing the mod restores the stock bytes exactly. `test.sh` runs both off the
  car for each car, on the patch engine.
- **Model, region and firmware.** `mod.json` lists exactly the two cars above. A unit with another
  model, region or firmware isn't offered the mod.
- **A unit that has Wi-Fi: Santa Fe.** Its entry carries `"features": ["!hmgapi.wifi"]`, so
  HMG-API refuses the mod ("not for units with hmgapi.wifi") once it has seen the unit's Wi-Fi
  chip on SDIO. The Santa Fe has no stock hotspot feature (HMG-API writes its own file), which
  is why `hmgapi.wifi` only appears when a chip really answers there; the unit this was built on
  shows that in `hmgapi engine status`. `test.sh` checks the refusal with a fake SDIO device. It
  has not been tried on a Santa Fe that has a chip. Limit: a chip that has never been powered
  isn't on SDIO, hence step 1 above.
- **A unit that has Wi-Fi: Niro EV.** No such gate, because it can't work. The Niro has the
  hotspot feature in its own software, and HMG-API counts that plus the Broadcom driver files as
  `hmgapi.wifi` (the report's `wifi: stock hotspot`) even when no chip answers. Of the seven
  Niro EV US 260507 Car Reports on HMG-API #12, one says `wifi_chip: false` and six say `true`,
  and the one from HMG-API 1.1.0-rc.4 says `stock hotspot`, which is not a chip seen. A
  `!hmgapi.wifi` gate would refuse all of them, including the car this mod was made on. So on a
  Niro the owner has to check (step 1): this mod does not stop itself.

## The driver

`morrownr/8821au-20210708` with `tools/driver-changes.patch`. `tools/build-driver.sh <car> <out.ko>`
rebuilds `files/<car>/bcmdhd-rtl8811au.ko` from public sources:

| Input | Pinned to |
|---|---|
| Kernel tree | `C457/android_kernel_telechips_tcc897x` at `3402d473aed6a2b82c5d08e0ceafc4a54701a4a0` |
| Driver | `morrownr/8821au-20210708` at `1a819991f5b75e64dfcf922b96a6681f367cbba0` |
| Kernel config | `tools/<car>/kernel.config` (SG2EV also `tools/sg2ev/prep.sh`) |
| Patch | `tools/driver-changes.patch` |
| Toolchain | Docker `ubuntu:16.04` (arm64), `gcc-4.9-arm-linux-gnueabi` from apt |

**Reproducibility.** On 2026-11-18 the real script, downloading its sources, rebuilt both files
byte for byte: `files/sg2ev` `11be86663f4897131d4179f35d028efe` and `files/tm23`
`f0e5c792c2e204c5165ef78e75aa84f3`. The Ubuntu image is pinned by tag and the compiler by apt's
current package, not by digest, so a later rebuild can differ without anything being wrong.

**What it is not.** No source for either car's exact kernel is public. The module is built
against a community 3.18.24 tree for the older TCC897X, so it is not a build of the car's
kernel, and a mismatch can crash the unit.

- **SG2EV:** `tools/sg2ev/kernel.config` is the car's config resolved against that tree (LPAE,
  64-bit physical and DMA addresses). dibble9012 reports it checked against the car: every symbol it
  needs exported, and 548 of the 549 kernel types shared with the stock driver's debug info with
  the same layout (`linux_mib` differs, and the driver doesn't use it).
- **TM23:** a plain 32-bit kernel. `tools/tm23/kernel.config` is the tree's own
  `wp_daudioplus_kia_us_defconfig` plus `CONFIG_BRIDGE_NETFILTER`, resolved with
  `make olddefconfig`. A first TM23 build made with the SG2EV config had the wrong `struct urb`,
  `scatterlist`, `resource` and `task_struct` layouts: the access point came up, and then the
  unit hit a kernel `BUG()` in the page cache and reset. `tools/check-layout.py` found it. For
  the shipped build, against the car's own modules and kernel symbol table: `vermagic` is
  `3.18.24-tcc SMP preempt mod_unload ARMv7 p2v8`; all 194 kernel symbols it needs are in the unit's
  kernel; and of 845 struct and union types in the driver's debug info, 481 are shared with the
  stock `bcmdhd.ko`, 235 with `ehci-tcc.ko`, 234 with `ohci-tcc.ko` and 386 with `tcc_cdrom.ko`,
  and every shared one has the same size and member offsets (including `urb`, `sk_buff`,
  `scatterlist`, `net_device`, `resource`, `task_struct`). It needs an unstripped build: the
  driver's Makefile passes `--strip-debug`, so build with `EXTRA_LDFLAGS=` for the check.

The layout check compares struct sizes and member offsets only. It doesn't cover enums, inline
functions or behaviour. A new car or firmware needs its own config, build and the same checks.

What the patch and build add: the module is named `bcmdhd` and takes the HAL's `iface_name`,
`firmware_path`, `nvram_path` and `clm_path` parameters; `mac_address_read` in sysfs, which the
HAL reads into `wifi.info.macaddress`; the stock hostapd's `add_ie` private command, which carries
the Apple device IE (added to beacons, probe responses and association responses); and the
driver's own US channel plan (the kernel's `world_regdom` drops channels 149 to 165 and there is
no CRDA, so hostapd refused the hotspot's channel 149). These were made for the SG2EV and its
hostapd; on the TM23 the hotspot comes up on channel 149 with them.

## WPA2 (a manual step)

On the SG2EV test car the CarPlay network was set to WPA1 with TKIP and had to be changed to WPA2
by editing the auth type in `/data/misc/wifi/softap.conf` by hand (the int after the two SSIDs: 1
is `WPA_PSK`, 4 is `WPA2_PSK`), then restarting. It wasn't tested whether CarPlay also works on
WPA1. This mod doesn't make that edit and removing it doesn't undo it, so keep a copy of the
file. The TM23 unit checked was already on WPA2.

## Known limits

- SG2EV: one car, one firmware, one adapter; sessions of up to 7.5 minutes. Long drives, cold
  starts, calls and audio quality aren't tested. `usbguard` hadn't blocked a real reset yet: in the
  session after its timing fix CarPlay started before the stock app's timer ran out. If a reset
  gets through, the adapter comes back in about 2.5 seconds and the phone rejoins.
- TM23: one car, one firmware, one adapter, one owner. CarPlay works only with `resetUSB()`
  skipped (see "what was tried on the car"). Audio delay and Android Auto aren't tested.
- The SG2EV mod uses the wireless mod's EV6 patch set, not one made for the Niro.
