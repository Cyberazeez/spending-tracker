#!/bin/bash
# Installs dependencies at the start of CLOUD sessions only. Does nothing on your PC.
if [ "$CLAUDE_CODE_REMOTE" != "true" ]; then
  exit 0
fi
cd "$CLAUDE_PROJECT_DIR" || exit 0

if [ -f package.json ]; then
  stamp=node_modules/.cloud-setup.sha256
  files="package.json scripts/cloud-setup.sh"
  [ -f package-lock.json ] && files="$files package-lock.json"
  if ! sha256sum --check --status "$stamp" 2>/dev/null; then
    rm -f "$stamp"; mkdir -p node_modules
    if [ -f package-lock.json ]; then npm ci; else npm install; fi \
      && sha256sum $files > "$stamp" || rm -f "$stamp"
  fi
fi

[ -f requirements.txt ] && pip install -q -r requirements.txt
exit 0
