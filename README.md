# hmgapi-usb-wifi

An [HMG-API](https://github.com/Open-HMG/HMG-API) mod that runs the wireless CarPlay hotspot on a
USB Wi-Fi adapter (TP-Link Archer T2U Nano or Nano AC600, RTL8811AU) for head units whose
built-in Wi-Fi doesn't work. It is an add-on for
[`wireless-carplay-aa`](https://github.com/Open-HMG/hmgapi-wireless-cp-aa).

The mod is in [`usb-wifi/`](usb-wifi/README.md): which cars, what was tested
on them, the driver and how to rebuild it, and what keeps it off units that have Wi-Fi (a gate on the Santa Fe; on the Niro, the owner checks).

Status: pre-release, no release published yet. Cars: Kia Niro EV (`SG2EV`, USA 260507) and
Hyundai Santa Fe (`TM23`, USA 260903). Wireless CarPlay works on the Santa Fe, with a hook that
skips DiPO's `resetUSB()` (see the mod's README).

By dibble9012 (Kyle Dibble-Dabney), from HMG-API PR #104; Santa Fe support by Geijoh. AGPL-3.0.

## Downloads

Each [release](https://github.com/Geijoh/hmgapi-usb-wifi/releases) is built by GitHub Actions
from a version tag, signed with the author key, and has:

| File | For |
|---|---|
| `usb-wifi-<version>.zip` | The signed mod. HMG-API's USB-stick update (`HMGAPI/updates/`) and `adb`. |
| `usb-wifi-<version>-nemesis.zip` | NEMESIS Manager: unzip onto the top level of a USB stick. |
| `usb-wifi-<version>-nemesis-package.zip` | The NEMESIS package itself (id `hmgapi.usb-wifi`), for the Package Store and `nemesis install`. |
| `SHA256SUMS` | Checksums of the three zips. |

## Installing

Install [HMG-API](https://github.com/Open-HMG/HMG-API/wiki/Installing-HMG-API) and
`wireless-carplay-aa` first. This mod needs HMG-API 1.1.0-rc.3 or newer and `wireless-carplay-aa`
2.1.0 or newer. Read [the mod's README](usb-wifi/README.md) before plugging the adapter in: ADB
over USB has to be off, and the adapter has to be pulled before it goes back on.

- **USB stick**: put `usb-wifi-<version>.zip` in `HMGAPI/updates/` on the stick, then HMG-API app →
  Check USB updates → the mod → Apply changes.
- **NEMESIS**: unzip `usb-wifi-<version>-nemesis.zip` onto the top level of a USB stick and confirm
  the install in NEMESIS Manager.
- **adb**: `adb push` the zip, then `hmgapid engine install <zip>`, `plan`, `apply`.

[Installing and removing mods](https://github.com/Open-HMG/HMG-API/wiki/Installing-and-removing-mods)
has the steps. An update must be signed with the same author key as the installed version, so a
test build signed with another key installs only after it is removed. Every release here is
signed with author key `f4b5f7f3-08d9-83e9-8d77-d3f993232500` (Geijoh).

The mod was `usb-wifi-rtl8811au` in HMG-API PR #104 and in test builds. Its id changed to
`usb-wifi`, so remove an old `usb-wifi-rtl8811au` (or `usb-wifi-rtl8811au-tm23`) before installing
this one.

## Development

Check a change off the car: `HMGAPI_SDK=<unpacked HMG-API mod SDK> usb-wifi/test.sh`.
CI runs HMG-API's mod workflow on every push and pull request, pinned to the SDK in
`hmgapi-sdk.json`. The pin is in three places (`hmgapi-sdk.json`, `ci.yml`, `release.yml`);
`.github/check-pin.py` fails CI when they differ, so move them together.

## Releases (maintainers)

Versions follow HMG-API's
[docs/releasing.md](https://github.com/Open-HMG/HMG-API/blob/main/docs/releasing.md). A
pre-release (`v1.0.0-rc.2`) is a GitHub pre-release, never "Latest", and isn't added to HMG-API's
catalogue.

Setup (done): the author key is `f4b5f7f3-08d9-83e9-8d77-d3f993232500`. Its public half is
`.github/mod-key.pub`; the private half is the `release` environment's `MOD_KEY` secret (limited to
`v*` tags) and the maintainer's backup. Losing the private key means updates can't be signed, and
an update signed with another key does not install over the old one. Until the first release is
published the key can still be replaced: `java -cp $HMGAPI_SDK/lib/hmgapi-engine.jar
hmgapi.engine.Signing keygen <absolute path>` writes the key and its `.pub`; commit the `.pub` and
set `MOD_KEY` to `base64 < <key>`.

Each release:

1. Set `version` in `usb-wifi/mod.json` (and `hmgapi` if the mod needs a newer HMG-API).
   Release notes go in `.github/release-notes/v<version>.md`; without that file the draft gets
   GitHub's generated notes.
2. Push the tag `v<version>`. The release workflow (`.github/workflows/release.yml`) refuses a tag
   that isn't `mod.json`'s version, runs CI, signs the mod with `MOD_KEY`, and makes a **draft**
   release with the three zips and `SHA256SUMS`. The run's summary has the line HMG-API pins a
   pre-release with (`tools/release-mods.txt`), or for a final the `tools/catalog.py add` command.
3. Publish the draft.

`.github/release.sh <tag> <author key>` does the build and signing on a computer, with
`HMGAPI_SDK` set to the unpacked SDK. If the repository moves, change `REPO` in it.
