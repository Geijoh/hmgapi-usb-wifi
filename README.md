# hmgapi-usb-wifi-rtl8811au

An [HMG-API](https://github.com/Open-HMG/HMG-API) mod that runs the wireless CarPlay hotspot on a
USB Wi-Fi adapter (TP-Link Archer T2U Nano or Nano AC600, RTL8811AU) for head units whose
built-in Wi-Fi doesn't work. It is an add-on for
[`wireless-carplay-aa`](https://github.com/Open-HMG/hmgapi-wireless-cp-aa).

The mod is in [`usb-wifi-rtl8811au/`](usb-wifi-rtl8811au/README.md): which cars, what was tested
on them, the driver and how to rebuild it, and how it is kept off units that have Wi-Fi.

Status: pre-release. Cars: Kia Niro EV (`SG2EV`, USA 260507) and Hyundai Santa Fe (`TM23`, USA
260903). Wireless CarPlay does not yet complete on the Santa Fe.

By dibble9012 (Kyle Dibble-Dabney), from HMG-API PR #104; Santa Fe support by Geijoh. AGPL-3.0.

Check a change off the car: `HMGAPI_SDK=<unpacked HMG-API mod SDK> usb-wifi-rtl8811au/test.sh`.
CI runs HMG-API's mod workflow, pinned to the SDK in `hmgapi-sdk.json`.
