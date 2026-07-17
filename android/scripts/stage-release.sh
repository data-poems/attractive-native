#!/usr/bin/env bash
# File Purpose: Builds, validates, versions, and checksum-stages Attractive Android releases.
# Primary Components: JDK check, Gradle verification, APK/AAB collection, dual stage roots.
# Inputs/Outputs: Optional signing env vars; writes release/android/ and dist/platforms/android/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPOSITORY_DIR="$(cd "${ANDROID_DIR}/.." && pwd)"

export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 21 2>/dev/null || true)}"
if [[ -z "${JAVA_HOME}" ]]; then
  echo "Attractive Android releases require JDK 21." >&2
  exit 1
fi
export PATH="${JAVA_HOME}/bin:${PATH}"

JAVA_VERSION="$(
  java -XshowSettings:properties -version 2>&1 |
    awk -F= '/java.specification.version/ { gsub(/[[:space:]]/, "", $2); print $2; exit }'
)"
if [[ "${JAVA_VERSION}" != "21" ]]; then
  echo "Attractive Android releases require JDK 21; found JDK ${JAVA_VERSION:-unknown}." >&2
  exit 1
fi

cd "${ANDROID_DIR}"
./gradlew --no-daemon clean test lintRelease assembleRelease bundleRelease

VERSION_FILE="${ANDROID_DIR}/version.properties"
VERSION_NAME="$(awk -F= '$1 == "VERSION_NAME" { print $2; exit }' "${VERSION_FILE}")"
VERSION_CODE="$(awk -F= '$1 == "VERSION_CODE" { print $2; exit }' "${VERSION_FILE}")"
if [[ -z "${VERSION_NAME}" || -z "${VERSION_CODE}" ]]; then
  echo "version.properties must define VERSION_NAME and VERSION_CODE." >&2
  exit 1
fi

VERSION_TAG="${VERSION_NAME}+${VERSION_CODE}"
LEGACY_STAGE_DIR="${REPOSITORY_DIR}/release/android/${VERSION_TAG}"
# platforms suite convention: dist/platforms/<adapter-id>/
PLATFORMS_STAGE_DIR="${REPOSITORY_DIR}/dist/platforms/android/${VERSION_TAG}"

APK_SOURCE="${ANDROID_DIR}/app/build/outputs/apk/release/app-release.apk"
SIGNING_LABEL="signed"
if [[ ! -f "${APK_SOURCE}" ]]; then
  APK_SOURCE="${ANDROID_DIR}/app/build/outputs/apk/release/app-release-unsigned.apk"
  SIGNING_LABEL="unsigned"
fi

AAB_SOURCE="${ANDROID_DIR}/app/build/outputs/bundle/release/app-release.aab"
if [[ ! -f "${APK_SOURCE}" || ! -f "${AAB_SOURCE}" ]]; then
  echo "Expected release APK and AAB outputs were not produced." >&2
  exit 1
fi

APK_NAME="strangely-attractive-${VERSION_NAME}-${VERSION_CODE}-${SIGNING_LABEL}.apk"
AAB_NAME="strangely-attractive-${VERSION_NAME}-${VERSION_CODE}-${SIGNING_LABEL}.aab"
APKSIGNER="${HOME}/Library/Android/sdk/build-tools/36.0.0/apksigner"

stage_into() {
  local dest="$1"
  mkdir -p "${dest}"
  cp "${APK_SOURCE}" "${dest}/${APK_NAME}"
  cp "${AAB_SOURCE}" "${dest}/${AAB_NAME}"

  # Installable testing APK when release keystore is not configured.
  if [[ "${SIGNING_LABEL}" == "unsigned" && -f "${HOME}/.android/debug.keystore" && -x "${APKSIGNER}" ]]; then
    local testing_apk="strangely-attractive-${VERSION_NAME}-${VERSION_CODE}-testing.apk"
    "${APKSIGNER}" sign \
      --ks "${HOME}/.android/debug.keystore" \
      --ks-pass pass:android \
      --ks-key-alias androiddebugkey \
      --key-pass pass:android \
      --out "${dest}/${testing_apk}" \
      "${dest}/${APK_NAME}"
    "${APKSIGNER}" verify --verbose "${dest}/${testing_apk}" >/dev/null
  fi

  (
    cd "${dest}"
    shasum -a 256 strangely-attractive-*.apk strangely-attractive-*.aab > SHA256SUMS 2>/dev/null || \
      shasum -a 256 "${APK_NAME}" "${AAB_NAME}" > SHA256SUMS
  )

  cat > "${dest}/PROVENANCE.md" <<EOF
# Strangely Attractive Android ${VERSION_TAG}

- Built: $(date -u +%Y-%m-%dT%H:%MZ)
- Module: android/ (offline WebView shell over attractive-web)
- Signing: ${SIGNING_LABEL}
- Platforms track: dist/platforms/android (suite convention)
- Hosted sideload (when published): https://dr.eamer.dev/downloads/android/strangely-attractive/
EOF

  cat > "${dest}/UPLOAD_CHECKLIST.md" <<EOF
# Android upload checklist — Strangely Attractive ${VERSION_TAG}

- [ ] Verify SHA-256 against SHA256SUMS
- [ ] Prefer release-keystore signing (ATTRACTIVE_STORE_* env) before Play upload
- [ ] Sideload smoke: install testing/signed APK, open attractor, rotate view
- [ ] Confirm offline (no network permission; blockNetworkLoads)
- [ ] Play Console: create app / attach AAB (human login only)
- [ ] Update dr.eamer.dev/downloads catalog if sideload APK changes
EOF
}

stage_into "${LEGACY_STAGE_DIR}"
stage_into "${PLATFORMS_STAGE_DIR}"

if [[ "${SIGNING_LABEL}" == "signed" && -x "${APKSIGNER}" ]]; then
  "${APKSIGNER}" verify --verbose "${PLATFORMS_STAGE_DIR}/${APK_NAME}"
fi

echo "Staged ${SIGNING_LABEL} Android artifacts:"
echo "  ${LEGACY_STAGE_DIR}"
echo "  ${PLATFORMS_STAGE_DIR}"
