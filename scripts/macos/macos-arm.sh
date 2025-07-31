set -e

DMG_URL="https://github.com/2dust/v2rayN/releases/download/7.12.7/v2rayN-macos-arm64.dmg"
DMG_FILE="/tmp/v2rayN-macos-64.dmg"
MOUNT_POINT="/Volumes/v2rayN Installer"
APP_PATH="/Applications/v2rayN.app"
CONFIG_DIR="$HOME/Library/Application Support/v2rayN/guiConfigs"
CONFIG_FILE="$CONFIG_DIR/guiNConfig.json"
BACKUP="$CONFIG_FILE.bak"

echo "Downloading DMG..."
curl -L -o "$DMG_FILE" "$DMG_URL"

echo "Mounting DMG..."
hdiutil attach "$DMG_FILE" -mountpoint "$MOUNT_POINT" -nobrowse -quiet

echo "Copying to /Applications..."
cp -R "$MOUNT_POINT/v2rayN.app" /Applications/

sleep 2
echo "Unmounting DMG..."
for i in {1..5}; do
  if hdiutil detach "$MOUNT_POINT" -quiet; then
    echo "DMG unmounted"
    break
  else
    echo "Volume is busy, waiting and retrying..."
    sleep 10
  fi
done

sleep 2
echo "Removing DMG..."
for i in {1..10}; do
  if rm "$DMG_FILE"; then
    echo "DMG removed"
    break
  else
    echo "File is busy, waiting..."
    sleep 10
  fi
done

echo "Removing Apple quarantine..."
xattr -dr com.apple.quarantine "$APP_PATH"

### Launching the app to generate configs
echo "Starting v2rayN to generate configs..."
open -a "$APP_PATH"
echo "Waiting for configs to appear..."

# Wait until the config file appears (up to 60 seconds)
for i in {1..12}; do
  if [ -f "$CONFIG_FILE" ]; then
    echo "Config file found"
    break
  else
    echo "Waiting for file $CONFIG_FILE..."
    sleep 5
  fi
done

### Closing the app
echo "Closing v2rayN..."
# Try to quit via AppleScript (can use killall if it doesn’t work)
osascript -e 'quit app "v2rayN"'
sleep 3
killall v2rayN 2>/dev/null || true

### Modifying the config
echo "Applying settings..."
cp "$CONFIG_FILE" "$BACKUP"

if ! sed -i '' -e 's/"DoubleClick2Activate": false/"DoubleClick2Activate": true/' \
               -e 's/"SysProxyType": 0/"SysProxyType": 2/' "$CONFIG_FILE"; then
  echo "Error: failed to modify parameters. Restoring backup."
  mv "$BACKUP" "$CONFIG_FILE"
  exit 1
fi

echo "Settings applied successfully."
echo "Done!"
