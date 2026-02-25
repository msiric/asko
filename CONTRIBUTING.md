# Contributing to asko

Thanks for your interest in contributing to asko.

## Getting Started

1. Fork the repo
2. Clone your fork: `git clone https://github.com/YOUR_USER/asko.git`
3. Install pre-commit hooks: `pre-commit install`
4. Create a branch: `git checkout -b my-feature`
5. Make your changes
6. Run tests: `make test`
7. Run linters: `make lint-all`
8. Commit and push
9. Open a pull request

## Development Requirements

- Docker and Docker Compose V2
- [BATS](https://github.com/bats-core/bats-core) for running tests
- Python 3.12+ with PyYAML (`pip install pyyaml`)
- ShellCheck for linting (`brew install shellcheck`)
- [pre-commit](https://pre-commit.com/) for git hooks (`pip install pre-commit`)
- GNU Make

## Makefile Commands

```bash
make help              # Show all available commands
make test              # Run all tests
make lint-all          # Run all linters (shellcheck, YAML, TOML, compose)
make start             # Start services
make stop              # Stop services
make health            # Check service health
make backup            # Create backup
make update            # Safe rolling update
```

## Running Tests

```bash
make test              # All tests
make test-unit         # Unit tests only
make test-compose      # Compose validation
make test-templates    # Template rendering
make test-security     # Security checks
```

Tests that require the Docker stack to be running will be automatically skipped if it's not up.

## TDD Workflow

We follow test-driven development:

1. Write a failing test for your change
2. Implement the change
3. Verify the test passes: `make test`
4. Verify lints pass: `make lint-all`

## Branch Protection

The `main` branch has the following protections:

- Pull requests required (no direct push)
- CI checks must pass before merge (lint, tests, secret scanning, security scan)
- At least 1 approval required from CODEOWNERS
- Force pushes disabled

## Guidelines

- Every new service must have: healthcheck, resource limits, `security_opt: [no-new-privileges:true]`, `cap_drop: [ALL]`, `logging: *default-logging`
- No service should expose ports to the host except Caddy
- Secrets go in `.env` (never committed), templates use `${VAR}` references
- Shell scripts must pass `shellcheck`
- Docker image tags must be pinned to specific versions (never `:latest` or `:main`)
- Keep the stack lean — don't add services unless they're clearly needed

## Security

If you find a security issue, please use GitHub's private security advisory feature rather than opening a public issue.
