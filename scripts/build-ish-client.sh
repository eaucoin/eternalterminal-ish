#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${REPO_ROOT}/dist/ish"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to build the iSH client." >&2
  exit 1
fi

if ! docker buildx version >/dev/null 2>&1; then
  echo "docker buildx is required (Docker Desktop 19.03+)." >&2
  exit 1
fi

if [ "${SKIP_SUBMODULE_UPDATE:-0}" != "1" ]; then
  echo "Ensuring submodules are initialized..."
  git -C "${REPO_ROOT}" submodule update --init --recursive
else
  echo "Skipping submodule initialization (SKIP_SUBMODULE_UPDATE=${SKIP_SUBMODULE_UPDATE})"
fi

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"

determine_version() {
  if [ -n "${ET_VERSION:-}" ]; then
    printf '%s' "${ET_VERSION}"
    return
  fi
  python3 - <<'PY' "${REPO_ROOT}"
import re, sys, pathlib
cmakelists = pathlib.Path(sys.argv[1]) / "CMakeLists.txt"
match = re.search(r"project\(EternalTCP VERSION ([0-9]+\.[0-9]+\.[0-9]+)", cmakelists.read_text())
if not match:
    raise SystemExit("Unable to determine Eternal Terminal version from CMakeLists.txt")
print(match.group(1))
PY
}

ET_VERSION_RESOLVED="$(determine_version)"

CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"
JOBS_ARG="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '4')}"

echo "Building Eternal Terminal client for linux/386 (musl)..."
docker buildx build \
  --platform=linux/386 \
  --build-arg CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}" \
  --build-arg JOBS="${JOBS_ARG}" \
  --build-arg ET_VERSION="${ET_VERSION_RESOLVED}" \
  --file "${REPO_ROOT}/docker/ish-client/Dockerfile" \
  --output "type=local,dest=${OUT_DIR}" \
  "${REPO_ROOT}"

cat <<'EOF'

Build complete.
Artifacts are located in dist/ish:
  - et-client-ish.tar.gz (preferred for AirDrop/manual install)
  - et-ish.apk           (installable with 'apk add --allow-untrusted <url>')
  - usr/local/bin/et     (unpacked for inspection/testing)

EOF
