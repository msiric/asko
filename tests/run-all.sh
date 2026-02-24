#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASKO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check BATS is installed
if ! command -v bats &>/dev/null; then
    echo -e "${RED}BATS not found. Install with: brew install bats-core${NC}"
    echo "Or: git clone https://github.com/bats-core/bats-core.git && cd bats-core && sudo ./install.sh /usr/local"
    exit 1
fi

# Test categories
CATEGORIES=("unit" "templates" "compose" "integration" "security" "e2e")

# If a category is specified, run only that
if [[ $# -gt 0 ]]; then
    category="$1"
    if [[ ! -d "${SCRIPT_DIR}/${category}" ]]; then
        echo -e "${RED}Unknown test category: ${category}${NC}"
        echo "Available: ${CATEGORIES[*]}"
        exit 1
    fi
    echo -e "${YELLOW}Running ${category} tests...${NC}"
    bats "${SCRIPT_DIR}/${category}/"
    exit $?
fi

# Run all categories
failed=0
for category in "${CATEGORIES[@]}"; do
    test_dir="${SCRIPT_DIR}/${category}"
    if [[ -d "$test_dir" ]] && ls "$test_dir"/*.bats &>/dev/null 2>&1; then
        echo -e "\n${YELLOW}=== ${category} tests ===${NC}"
        if bats "$test_dir/"; then
            echo -e "${GREEN}${category}: PASSED${NC}"
        else
            echo -e "${RED}${category}: FAILED${NC}"
            failed=1
        fi
    else
        echo -e "\n${YELLOW}=== ${category} tests ===${NC}"
        echo -e "  (no tests found)"
    fi
done

echo ""
if [[ $failed -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
