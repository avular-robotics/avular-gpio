#!/usr/bin/env bash

# Proget is a bit picky about the debian packages. For this reason we patch some common issues that cpack creates.
# The issues that we patch are:
# - The control file contains empty lines
# - The debian-binary file is missing
# - Check for essential control fields like Package and Version

set -euo pipefail

# Convert relative path to absolute path
deb="$(realpath "$1")"

if [ ! -f "$deb" ]; then
  echo "File $deb does not exist"
  exit 1
fi

if command -v lintian >/dev/null 2>&1; then
    lintian "$deb" || true
else
    echo "::warning::Lintian is not installed, skipping linting"
fi

# Patch the control file to remove empty lines
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Extract the debian package
pushd "$tmp" >/dev/null
ar x "$deb"
popd >/dev/null 

# Ensure debian-binary file exists
if [ ! -f "$tmp/debian-binary" ]; then
  echo "2.0" > "$tmp/debian-binary"
fi

control_archive="$(find "$tmp" -name "control.tar*")"
if [ -z "$control_archive" ]; then
  echo "Control archive not found in $deb"
  exit 1
fi
mkdir "$tmp/DEBIAN"
tar xf "$control_archive" -C "$tmp/DEBIAN"

data_archive="$(find "$tmp" -name "data.tar*")"
if [ -z "$data_archive" ]; then
  echo "Data archive not found in $deb"
  exit 1
fi

# Patch the control file
control_file="$tmp/DEBIAN/control"
if [ ! -f "$control_file" ]; then
  echo "Control file not found in $deb"
  exit 1
fi

# Remove empty lines from the control file
sed -i '/^$/d' "$control_file"

# Validate essential control fields
if ! grep -q "^Package:" "$control_file"; then
  echo "Error: Missing Package field in control file"
  exit 1
fi
if ! grep -q "^Version:" "$control_file"; then
  echo "Error: Missing Version field in control file"
  exit 1
fi

# Repack the control archive, potentially overwriting the existing one
tar -czf "$tmp/control-new.tar.gz" -C "$tmp/DEBIAN" .
mv "$tmp/control-new.tar.gz" "$tmp/control.tar.gz"

# Repack the debian package (order matters: debian-binary, control, data)
new_deb="${deb%.deb}-patched.deb"
ar rcs "$new_deb" \
  "$tmp/debian-binary" \
  "$tmp/control.tar.gz" \
  "$data_archive"
mv "$new_deb" "$deb"

echo "Patched $deb successfully"
