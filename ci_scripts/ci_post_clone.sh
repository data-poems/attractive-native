#!/bin/sh
# File purpose: Xcode Cloud post-clone hook — regenerate the gitignored
#   XcodeGen project so Archive can find Attractive.xcodeproj.
# Primary functions: install xcodegen (Homebrew), run `xcodegen generate`.
# I/O: reads project.yml; writes Attractive.xcodeproj.
#
# Prophylactic: project.yml is source of truth; .xcodeproj is gitignored.
# Place this script before enabling an Xcode Cloud workflow.

set -eu

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

echo "==> ci_post_clone: branch=${CI_BRANCH:-?} commit=${CI_COMMIT:-?} build=${CI_BUILD_NUMBER:-?}"

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "error: Homebrew is required to install xcodegen on Xcode Cloud" >&2
    exit 1
  fi
  echo "==> Installing xcodegen via Homebrew"
  brew install xcodegen
fi

echo "==> Generating Attractive.xcodeproj from project.yml"
xcodegen generate --spec project.yml

if [ ! -d "$ROOT_DIR/Attractive.xcodeproj" ]; then
  echo "error: expected Attractive.xcodeproj at $ROOT_DIR after xcodegen" >&2
  exit 1
fi

echo "==> ci_post_clone: Attractive.xcodeproj ready"
