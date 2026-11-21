#!/system/bin/sh
# The stock CarPlay app power-cycles the USB port when a wired session doesn't start
# (resetUSB), which would drop the Wi-Fi adapter and the hotspot. While the adapter is
# on the port, keep the kernel's port power control off. Init also turns it on during
# boot, so check the actual value every 0.2 s rather than only setting it once.
#
# Santa Fe (TM23) only: the car's wired Android Auto stack probes every new USB device with
# Android Open Accessory vendor requests (52, 53) about 1.5 s after it attaches. The adapter's
# control endpoint then stops answering, and the driver can't start or reload. While the
# adapter is present, make the bus directory root-only so that probe can't open it (usbfs
# open fails); put it back to 755 when the adapter is gone, so USB drives and wired CarPlay
# work again. The Niro is left alone: it hasn't been seen to need this.
P=${USBGUARD_PARAM:-/sys/module/tcc_dwc_otg/parameters/vbus_control_enable}
V=${USBGUARD_VID:-2357}
D=${USBGUARD_PID:-011e}
DEVS=${USBGUARD_DEVS:-/sys/bus/usb/devices}
B=${USBGUARD_BUSDIR:-/dev/bus/usb/001}
BLOCK=
case "${USBGUARD_BLOCK-$(getprop ro.product.name 2>/dev/null)}" in 1|*tm23*) BLOCK=1;; esac
[ -n "$BLOCK" ] && trap 'chmod 755 "$B"; exit' TERM INT
while true; do
  want=1
  for d in $DEVS/*; do
    if [ -f $d/idVendor ] && [ "$(cat $d/idVendor)" = "$V" ] && [ "$(cat $d/idProduct)" = "$D" ]; then want=0; fi
  done
  if [ "$(cat $P)" != "$want" ]; then
    echo $want > $P
    echo "$(date) adapter guard: vbus_control_enable=$want"
  fi
  if [ -n "$BLOCK" ]; then
    if [ $want = 0 ]; then mode=700; else mode=755; fi
    case "$(ls -ld $B)" in drwx------*) cur=700;; *) cur=755;; esac
    if [ $cur != $mode ]; then
      chmod $mode $B
      echo "$(date) adapter guard: $B mode=$mode"
    fi
  fi
  sleep 0.2
done
