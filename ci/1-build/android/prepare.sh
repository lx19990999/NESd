#!/usr/bin/env bash

set -eux

repo_root=$(git rev-parse --show-toplevel)
app_root="$repo_root/packages/nesd"
keystore_path="/tmp/upload-keystore.jks"

echo "$KEY_STORE_BASE64" | base64 --decode > "$keystore_path"

{
  printf '%s\n' "$KEY_PROPERTIES" | sed '/^storeFile[[:space:]]*=/d'
  printf 'storeFile=%s\n' "$keystore_path"
} > "$app_root/android/key.properties"
