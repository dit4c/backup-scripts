#!/bin/sh

set -e

# Map stdout to fd 6, then redirect stdout to stderr
exec 6>&1
exec >&2

SWIFT_ACCOUNT_URL=$1
OBJECT_PREFIX=$2
OBJECT_SUFFIX=$3

TTL_FULL=$(( 24 * 3600 ))
TTL_DAY=$(( 30 * 24 * 3600 ))
TTL_MONTH=$(( 2 * 365 * 24 * 3600 ))

# Use UTC for all timestamps
TS_FULL=$(TZ=UTC date +%Y%m%dT%H%M%S)
TS_DAY=$(TZ=UTC date +%Y%m%d)
TS_MONTH=$(TZ=UTC date +%Y%m)

OS_AUTH_URL_V3=$(echo $OS_AUTH_URL | sed -e 's/v2\.0\/*$//')"v3"
OS_TOKEN=$(curl -i -s \
  -H "Content-Type: application/json" \
  -d "
{
  \"auth\": {
    \"identity\": {
      \"methods\": [
        \"password\"
      ],
      \"password\": {
        \"user\": {
          \"domain\": {
            \"name\": \"default\"
          },
          \"name\": \"$OS_USERNAME\",
          \"password\": \"$OS_PASSWORD\"
        }
      }
    },
    \"scope\": {
      \"project\": {
        \"domain\": {
          \"name\": \"default\"
        },
        \"name\": \"$OS_TENANT_NAME\"
      }
    }
  }
}" \
$OS_AUTH_URL_V3/auth/tokens?nocatalog |
sed -ne '/x-subject-token/Is/^.*:\s*\(.*\)$/\1/p' |
tr -d '\r\n')

# Upload file (taking content from stdin)
CURL_COMMON_ARGS='-v --retry 10 --fail'
OBJECT_URL="$SWIFT_ACCOUNT_URL/${OBJECT_PREFIX}${TS_FULL}${OBJECT_SUFFIX}"
curl -X PUT --data-binary @- \
  $CURL_COMMON_ARGS \
  -H "Content-Type: application/octet-stream" \
  -H "Transfer-Encoding: chunked" \
  -H "X-Auth-Token: $OS_TOKEN" \
  -H "X-Delete-After: $TTL_FULL" \
  $OBJECT_URL

# Copy file
curl -X COPY \
  $CURL_COMMON_ARGS \
  -H "X-Auth-Token: $OS_TOKEN" \
  -H "X-Delete-After: $TTL_DAY" \
  -H "Destination: ${OBJECT_PREFIX}${TS_DAY}${OBJECT_SUFFIX}" \
  $OBJECT_URL
curl -X COPY \
  $CURL_COMMON_ARGS \
  -H "X-Auth-Token: $OS_TOKEN" \
  -H "X-Delete-After: $TTL_MONTH" \
  -H "Destination: ${OBJECT_PREFIX}${TS_MONTH}${OBJECT_SUFFIX}" \
  $OBJECT_URL

# Output to verification step
curl -X GET -sL \
  $CURL_COMMON_ARGS \
  -H "X-Auth-Token: $OS_TOKEN" \
  $OBJECT_URL >&6
