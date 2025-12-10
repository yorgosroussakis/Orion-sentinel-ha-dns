#!/usr/bin/env bash
set -euo pipefail

TARGET="${CHECK_DNS_TARGET:-127.0.0.1}"
FQDN="${CHECK_DNS_FQDN:-github.com}"
TIMEOUT="${CHECK_TIMEOUT:-3}"

if ! output=$(dig @"${TARGET}" "${FQDN}" +short +tries=1 +time="${TIMEOUT}"); then
  echo "check_dns: dig failed for ${FQDN} via ${TARGET}"
  exit 1
fi

if [ -z "${output}" ]; then
  echo "check_dns: empty response for ${FQDN} via ${TARGET}"
  exit 1
fi

exit 0
