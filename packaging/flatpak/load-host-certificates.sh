#!/bin/sh
# Sourced by the launcher and the runtime smoke check. Flatpak's p11-kit
# client talks to the host trust module, including locally installed CAs.
export HAPPY_HOST_CA_BUNDLE=
certificate_bundle=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/happy-ca-XXXXXX.pem")
if trust extract --overwrite --filter=ca-anchors --purpose=server-auth \
    --format=pem-bundle "$certificate_bundle" &&
    test -s "$certificate_bundle"; then
  export HAPPY_HOST_CA_BUNDLE="$certificate_bundle"
else
  echo 'Happy Flutter: could not export the host CA trust store' >&2
  rm -f "$certificate_bundle"
fi
