#!/bin/bash

set -e

download_guix_to() {
  to_folder="$1"
  if [ -z "$to_folder" ] ; then
    echo "Error $to_folder does not exist!"
    exit 1
  fi
  current_bin_url=$(curl -L https://guix.gnu.org/en/download | grep -oP 'href="[^"]+"' | sed 's/href="//;s/"$//' | grep 'guix-binary' | grep 'x86.64' | grep -v sig)
  echo "current_bin_url = $current_bin_url"
  wget -c -O "$to_folder/guix-binary-x86_64-linux.tar.xz" "$current_bin_url"
  tar --extract --verbose --file="$to_folder/guix-binary-x86_64-linux.tar.xz" --directory="$to_folder" --strip-components=0
}

bin_path() {
  find "$GUIX_PROFILE" -type f -path '*bin*' -name "$1" | head -n 1
}

GUIX_PROFILE=/opt/guix
if ! [[ -e "$GUIX_PROFILE" ]]; then
  echo "Error, create $GUIX_PROFILE and give us ownership!"
  exit 1
fi

export PATH="$GUIX_PROFILE/bin":"$PATH"

if ! which guix >/dev/null 2>&1 ; then
  #maybe_dir=$(dirname "$(bin_path 'guix')" )
  #if ! [[ -z "$maybe_dir" ]] && [[ -e "$maybe_dir" ]] ; then
  #  export PATH="$PATH":"$maybe_dir"
  #fi
  export PATH="$PATH":$(find "$GUIX_PROFILE/gnu/store" -maxdepth 2 -type d -name bin | tr '\n' ':')
fi
if ! which guix >/dev/null 2>&1 ; then
  download_guix_to "$GUIX_PROFILE"
fi

export INFOPATH="$GUIX_PROFILE/share/info:$INFOPATH"
export GUIX_LOCPATH="$GUIX_PROFILE/lib/locale"

guix_interp=$(find "$GUIX_PROFILE" -name 'ld-linux-x86-64.so.2' | head -n 1)
echo "guix_interp=$guix_interp"
guix_libs=$(find "$GUIX_PROFILE/gnu/store" -maxdepth 2 -type d -name lib | tr '\n' ':')

if ! pgrep guix-daemon >/dev/null 2>&1 ; then
  # Start it
  our_group=$(groups | awk '{print $1}')
  sudo systemd-run \
    --unit=guix-daemon --property=BindPaths="$GUIX_PROFILE/var/guix":/var/guix --wait \
    "$guix_interp" --library-path "$guix_libs" $(bin_path guix-daemon) --build-users-group="$our_group" --disable-chroot &
fi


# Debugging
export guix_interp="$guix_interp"
export guix_libs="$guix_libs"
"$guix_interp" --library-path "$guix_libs" $(bin_path bash)

