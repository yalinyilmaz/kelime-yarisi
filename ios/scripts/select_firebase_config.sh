#!/bin/sh
set -eu

case "${APP_FLAVOR:-}" in
  dev) expected_project="kelime-yarisi-yalin" ;;
  prod) expected_project="kelime-yarisi-prod" ;;
  *) echo "error: Unknown Firebase flavor: ${APP_FLAVOR:-unset}" >&2; exit 1 ;;
esac

config="$SRCROOT/config/$APP_FLAVOR/GoogleService-Info.plist"
if [ ! -f "$config" ]; then
  echo "error: Missing Firebase config: $config" >&2
  exit 1
fi

project=$(/usr/libexec/PlistBuddy -c 'Print :PROJECT_ID' "$config")
bundle=$(/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$config")
if [ "$project" != "$expected_project" ] || [ "$bundle" != "$PRODUCT_BUNDLE_IDENTIFIER" ]; then
  echo "error: Firebase config does not match $APP_FLAVOR / $PRODUCT_BUNDLE_IDENTIFIER" >&2
  exit 1
fi

destination="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
mkdir -p "$destination"
cp "$config" "$destination/GoogleService-Info.plist"
