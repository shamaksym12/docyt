#!/usr/bin/env bash

# This script updates uploads schema documentation to S3 bucket where it is hosted from. The URL:
#
# https://internal-websites.docyt.com/reports-service-schema/report-schema.html

set -euo pipefail

aws s3 sync app/assets/schemas/docs/ s3://serverlessrepo-docyt-internal-websites-s3bucket-jpxk2zhisyxy/reports-service-schema/