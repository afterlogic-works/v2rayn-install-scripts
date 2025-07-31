#!/bin/bash
set -e

DEB_URL="https://github.com/2dust/v2rayN/releases/download/7.12.7/v2rayN-linux-64.deb"
DEB_FILE="/tmp/v2rayN-linux-64.deb"

echo "Downloading .deb file..."
curl -L -o "$DEB_FILE" "$DEB_URL"

echo "Installing the program..."
sudo dpkg -i "$DEB_FILE" || sudo apt-get install -f -y

echo "Removing the .deb file..."
rm "$DEB_FILE"

echo "Starting v2rayN to generate config..."
v2rayN &
sleep 2
pkill -f v2rayN

echo "Configuring parameters..."
FILE="$HOME/.local/share/v2rayN/guiConfigs/guiNConfig.json"
BACKUP="$FILE.bak"

if [ ! -f "$FILE" ]; then
  echo "Settings file not found: $FILE"
  exit 1
fi

cp "$FILE" "$BACKUP"

if ! sed -i \
  -e 's/"DoubleClick2Activate": false/"DoubleClick2Activate": true/' \
  -e 's/"SysProxyType": 0/"SysProxyType": 2/' "$FILE"; then
  echo "Error: failed to modify parameters. Restoring backup."
  mv "$BACKUP" "$FILE"
  exit 1
fi

rm "$BACKUP"
echo "Settings applied successfully."
echo "Done!"
