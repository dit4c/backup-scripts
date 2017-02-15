#!/bin/sh

IFTTT_MAKER_URL=$1
VALUE1=$2
VALUE2=$3

jq -Rs ". | { value1: \"$VALUE1\", value2: \"$VALUE2\", value3: . }" | \
  curl -X POST -H "Content-Type: application/json" --data-binary @- \
  $IFTTT_MAKER_URL
