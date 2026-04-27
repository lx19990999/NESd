#!/usr/bin/env bash

set -eux

repo_root=$(git rev-parse --show-toplevel)
app_root="$repo_root/packages/nesd"
keystore_path="/tmp/upload-keystore.jks"
key_properties_path="$app_root/android/key.properties"

if [ -z "${KEY_STORE_BASE64:-}" ]; then
  echo "ANDROID_KEY_STORE secret is empty" >&2
  exit 1
fi

if [ -z "${KEY_PROPERTIES:-}" ]; then
  echo "ANDROID_KEY_PROPERTIES secret is empty" >&2
  exit 1
fi

echo "$KEY_STORE_BASE64" | base64 --decode > "$keystore_path"

{
  printf '%b\n' "$KEY_PROPERTIES" | tr -d '\r' | sed '/^storeFile[[:space:]]*=/d'
  printf 'storeFile=%s\n' "$keystore_path"
} > "$key_properties_path"

for key in keyAlias keyPassword storePassword storeFile; do
  if ! grep -q "^${key}=" "$key_properties_path"; then
    echo "Generated key.properties is missing required property: ${key}" >&2
    echo "Current key.properties contents:" >&2
    cat "$key_properties_path" >&2
    exit 1
  fi
done
