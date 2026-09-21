#!/system/bin/sh
# Helper script to restore authentic Bluetooth MAC address from /efs on Samsung Galaxy S6

# Ensure target bluetooth directory exists with proper permissions BEFORE writing bdaddr
mkdir -p /data/misc/bluetooth
chmod 0770 /data/misc/bluetooth
chown bluetooth:net_bt_stack /data/misc/bluetooth

MAC_SRC=""
if [ -f /efs/bluetooth/bt_addr ]; then
    MAC_SRC="/efs/bluetooth/bt_addr"
elif [ -f /efs/imei/bt.txt ]; then
    MAC_SRC="/efs/imei/bt.txt"
fi

if [ -n "$MAC_SRC" ]; then
    FILE_SIZE=$(wc -c < "$MAC_SRC" | tr -d ' ')
    if [ "$FILE_SIZE" -eq 6 ]; then
        BT_ADDR=$(xxd -p "$MAC_SRC" | tr -d '\r\n ' | tr '[:upper:]' '[:lower:]')
    else
        BT_ADDR=$(cat "$MAC_SRC" | tr -d '\r\n ' | tr '[:upper:]' '[:lower:]')
    fi

    FORMATTED_ADDR=""
    if [ ${#BT_ADDR} -eq 12 ]; then
        # Format 12 hex characters into XX:XX:XX:XX:XX:XX using standard POSIX sed
        FORMATTED_ADDR=$(echo "$BT_ADDR" | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1:\2:\3:\4:\5:\6/')
        # Write colon-delimited MAC back to /efs/bluetooth/bt_addr so native stack (btif_core) can parse it
        echo "$FORMATTED_ADDR" > /efs/bluetooth/bt_addr
    elif [ ${#BT_ADDR} -eq 17 ]; then
        FORMATTED_ADDR="$BT_ADDR"
    fi

    if [ -n "$FORMATTED_ADDR" ] && [ ${#FORMATTED_ADDR} -eq 17 ]; then
        echo "$FORMATTED_ADDR" > /data/misc/bluetooth/bdaddr
        chmod 0660 /data/misc/bluetooth/bdaddr
        chown bluetooth:net_bt_stack /data/misc/bluetooth/bdaddr
        chmod 0640 /efs/bluetooth/bt_addr
        chown bluetooth:net_bt_stack /efs/bluetooth/bt_addr
        echo "[BT] Bluetooth MAC ($FORMATTED_ADDR) restored from $MAC_SRC" > /dev/kmsg 2>/dev/null || true
    else
        echo "[BT] Warning: Invalid Bluetooth MAC format in $MAC_SRC ($BT_ADDR)" > /dev/kmsg 2>/dev/null || true
    fi
else
    echo "[BT] Warning: No Bluetooth MAC found in /efs, fallback to generated MAC" > /dev/kmsg 2>/dev/null || true
fi

