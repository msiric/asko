#!/usr/bin/env bats

load '../helpers/test-helpers'

@test "whatsapp-ai-assistant workflow exists" {
    [[ -f "${ASKO_ROOT}/workflows/n8n/whatsapp-ai-assistant.json" ]]
}

@test "daily-summary workflow exists" {
    [[ -f "${ASKO_ROOT}/workflows/n8n/daily-summary.json" ]]
}

@test "url-summarizer workflow exists" {
    [[ -f "${ASKO_ROOT}/workflows/n8n/url-summarizer.json" ]]
}

@test "all workflow files are valid JSON" {
    for wf in "${ASKO_ROOT}"/workflows/n8n/*.json; do
        [[ -f "$wf" ]] || continue
        python3 -c "import json; json.load(open('$wf'))" || {
            echo "Invalid JSON: $wf"
            false
        }
    done
}

@test "workflow files contain n8n workflow structure" {
    for wf in "${ASKO_ROOT}"/workflows/n8n/*.json; do
        [[ -f "$wf" ]] || continue
        # n8n workflows have a "nodes" array
        python3 -c "
import json
data = json.load(open('$wf'))
assert 'nodes' in data, f'Missing nodes in $wf'
assert isinstance(data['nodes'], list), f'nodes is not a list in $wf'
" || {
            echo "Missing n8n structure: $wf"
            false
        }
    done
}
