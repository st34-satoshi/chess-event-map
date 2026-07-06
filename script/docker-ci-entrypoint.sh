#!/usr/bin/env bash
set -euo pipefail

if ! dpkg -s default-libmysqlclient-dev >/dev/null 2>&1; then
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    default-libmysqlclient-dev libvips curl build-essential git
fi

bundle check || bundle install --jobs 4
exec bin/ci "$@"
