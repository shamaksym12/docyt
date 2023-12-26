#!/usr/bin/env bash

#
# This script updates the JSON schema HTML documentation
#

set -euo pipefail

generate-schema-doc --config-file app/assets/schemas/json-schema-for-humans-config.json app/assets/schemas/report-schema.json app/assets/schemas/docs/
echo "Schema generated: app/assets/schemas/docs/report-schema.html"
