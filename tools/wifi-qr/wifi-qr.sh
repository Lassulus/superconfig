#!/usr/bin/env bash
QR_CODE=$(zbarcam --raw --oneshot)
SSID=$(echo "$QR_CODE" | awk -F 'S:' '{print $2}' | awk -F ';' '{print $1}')
PW=$(echo "$QR_CODE" | awk -F 'P:' '{print $2}' | awk -F ';' '{print $1}')
nmcli dev wifi rescan
nmcli dev wifi connect "$SSID" password "$PW"