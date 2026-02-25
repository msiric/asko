#!/usr/bin/env bash
# Shared constants and utilities for asko scripts.
# Source this file at the top of each script:
#   source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

set -euo pipefail

# Resolve paths relative to the sourcing script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
ASKO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Logging
info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Load .env if it exists
load_env() {
    if [[ -f "${ASKO_ROOT}/.env" ]]; then
        set -a
        # shellcheck source=/dev/null
        source "${ASKO_ROOT}/.env"
        set +a
    fi
}
