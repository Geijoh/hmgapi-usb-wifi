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
#
# The probe has also come 0.27 s after the adapter got its address (plugged in again just after
# a port power cycle), before the 0.2 s loop had looked. So a second loop waits for a new device
# node in the bus directory (inotify, toolbox's notify) and closes the directory at once if the
# adapter is on the bus: about 0.02 s on the car. The 0.2 s loop opens it again, and still
# closes it should the wait ever miss a plug-in.
P=${USBGUARD_PARAM:-/sys/module/tcc_dwc_otg/parameters/vbus_control_enable}
V=${USBGUARD_VID:-2357}
D=${USBGUARD_PID:-011e}
DEVS=${USBGUARD_DEVS:-/sys/bus/usb/devices}
B=${USBGUARD_BUSDIR:-/dev/bus/usb/001}
NOTIFY="notify -c 1 -m 256"   # returns at the first new entry (IN_CREATE)
[ -n "$USBGUARD_NOTIFY" ] && NOTIFY=$USBGUARD_NOTIFY
BLOCK=
case "${USBGUARD_BLOCK-$(getprop ro.product.name 2>/dev/null)}" in 1|*tm23*) BLOCK=1;; esac

there() {  # the adapter is on the bus (no forks: this also runs between a plug-in and the car's probe)
  for d in $DEVS/*; do
    [ -f $d/idVendor ] || continue
    read v < $d/idVendor; read p < $d/idProduct
    [ "$v" = "$V" ] && [ "$p" = "$D" ] && return 0
  done
  return 1
}

if [ -n "$BLOCK" ]; then
  # ends if notify can't watch the directory: the loop below is then the only guard, as before
  ( while $NOTIFY $B > /dev/null 2>&1; do
      if there; then
        chmod 700 $B
        echo "$(date) adapter guard: $B mode=700 (at plug-in)"
      fi
    done
    echo "$(date) adapter guard: the wait for a plug-in ended (notify failed), only the 0.2 s loop guards now" ) &
  W=$!
  trap 'kill $W 2>/dev/null; chmod 755 "$B"; exit' TERM INT
fi
while true; do
  if there; then want=0; else want=1; fi
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
