#!/usr/bin/env bash

set -euo pipefail

export HEALTH_CHECK_PORT=8088

bundle exec rails server
