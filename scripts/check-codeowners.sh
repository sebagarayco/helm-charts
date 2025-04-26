#!/usr/bin/env bash

cat <<EOF
# The repo admins team will be the default owners for everything in the repo.
# Unless a later match takes precedence, they will be requested for review when someone opens a pull request.
* @sebagarayco

EOF

for DIR in ./charts/*
do
  FILE="$DIR/Chart.yaml"
  DIR="${DIR//\./}"
  MAINTAINERS="$(yq e '.maintainers.[].name' "$FILE" | sed 's/^/@/' | sort --ignore-case | tr '\r\n' ' ')"
  echo -e "$DIR/ $MAINTAINERS"
done
