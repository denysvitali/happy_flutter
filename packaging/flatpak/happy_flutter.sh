#!/bin/sh
set -eu
. /app/lib/happy_flutter/load-host-certificates.sh
exec /app/lib/happy_flutter/happy_flutter "$@"
