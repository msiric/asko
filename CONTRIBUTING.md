# Contributing to asko

Thanks for your interest in contributing to asko.

## Getting Started

1. Fork the repo
2. Clone your fork: `git clone https://github.com/YOUR_USER/asko.git`
3. Create a branch: `git checkout -b my-feature`
4. Make your changes
5. Run tests: `./tests/run-all.sh`
6. Commit and push
7. Open a pull request

## Development Requirements

- Docker and Docker Compose V2
- [BATS](https://github.com/bats-core/bats-core) for running tests
- Python 3 with PyYAML (`pip install pyyaml`)
- ShellCheck for linting (`brew install shellcheck`)

## Running Tests

```bash
# All tests
./tests/run-all.sh

# Specific category
./tests/run-all.sh unit
./tests/run-all.sh templates
./tests/run-all.sh compose
./tests/run-all.sh security
```

Tests that require the Docker stack to be running will be automatically skipped if it's not up.

## TDD Workflow

We follow test-driven development:

1. Write a failing test for your change
2. Implement the change
3. Verify the test passes
4. Verify no existing tests broke

## Guidelines

- Every new service must have: healthcheck, resource limits, `security_opt: [no-new-privileges:true]`, `cap_drop: [ALL]`
- No service should expose ports to the host except Caddy
- Secrets go in `.env` (never committed), templates use `${VAR}` references
- Shell scripts must pass `shellcheck`
- Keep the stack lean — don't add services unless they're clearly needed

## Security

If you find a security issue, please use GitHub's private security advisory feature rather than opening a public issue.
