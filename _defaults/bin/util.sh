set -o errexit
set -o pipefail
set -o nounset

die() {
  echo -e >&2 "error: $@"
  exit 1
}

log() {
  echo >&2 "$@"
}
