#!/usr/bin/env bash
source "$(dirname "$0")/_lib.sh"
node="${1:?node}"
require_node "$node"
(cd "$VAGRANT_DIR" && vagrant up "$node" --no-provision)
date -u +"up at %Y-%m-%dT%H:%M:%SZ"
