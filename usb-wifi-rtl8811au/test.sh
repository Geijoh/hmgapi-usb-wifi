#!/bin/sh
# Off-car test on the patch engine (HMGAPI_SDK=<unpacked SDK> usb-wifi-rtl8811au/test.sh). For each car:
# the driver goes in over that car's expected stock file only, the service is planned, removing the mod
# gives the stock bytes back, and a unit whose Wi-Fi chip HMG-API has seen is refused.
set -e
cd "$(dirname "$0")/.."
. "${HMGAPI_SDK:?set HMGAPI_SDK to the unpacked HMG-API mod SDK}/test/lib.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
sum() { python3 -c 'import hashlib,sys; print(hashlib.md5(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }

car() {  # car <set> <product> <one-bin folder> <board platform>
  echo "== $1"
  export HMGAPI_PRODUCT=$2 HMGAPI_ONEBIN=$3
  R=$T/$1/root
  mkdir -p $R/data/hmgapi/mods $R/data/hmgapi/settings $R/system/wifi
  printf 'ro.board.platform=%s\n' "$4" > $R/props.txt
  : > $R/settings.txt
  cp -r usb-wifi-rtl8811au $R/data/hmgapi/mods/; rm $R/data/hmgapi/mods/usb-wifi-rtl8811au/test.sh
  python3 - "$R/data/hmgapi/mods/usb-wifi-rtl8811au/mod.json" <<'P'
import json,sys
d=json.load(open(sys.argv[1])); d.pop("requires"); json.dump(d,open(sys.argv[1],"w"))
P
  echo "not the expected stock driver" > $R/system/wifi/bcmdhd.ko
  ORIG=$(sum $R/system/wifi/bcmdhd.ko)
  eng apply; has "unknown stock driver refused" "$ORIG" "$out"
  check "... and left alone" "$ORIG" "$(sum $R/system/wifi/bcmdhd.ko)"
  # a unit whose chip HMG-API has seen on SDIO is not for this mod, whatever its driver file is
  mkdir -p $R/sys/bus/sdio/devices/mmc1:0001:1
  eng plan; has "refused on a unit with a Wi-Fi chip" "not for units with hmgapi.wifi" "$out"
  rmdir $R/sys/bus/sdio/devices/mmc1:0001:1
  python3 - "$R/data/hmgapi/settings/hmgapi.json" "$ORIG" <<'P'
import json,sys
json.dump({"overrides":{"accept_baseline":[{"path":"/system/wifi/bcmdhd.ko","md5":sys.argv[2]}]}},open(sys.argv[1],"w"))
P
  eng plan; has "service planned" "usb-wifi-rtl8811au/usbguard as root, at boot" "$out"
  eng apply; check "apply" 0 $rc
  check "driver in place" "$(sum usb-wifi-rtl8811au/files/$1/bcmdhd-rtl8811au.ko)" "$(sum $R/system/wifi/bcmdhd.ko)"
  eng restore; check "restore" 0 $rc
  check "stock bytes back" "$ORIG" "$(sum $R/system/wifi/bcmdhd.ko)"
}

car sg2ev SG2EV.USA.0000.V015.012.260507 sg2ev_us tcc803x
car tm23 TM23.USA.0000.V016.010.260903 tm23_us tcc897x
exit $fail
