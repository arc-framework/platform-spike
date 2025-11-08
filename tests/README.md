# Tests

Test suites for the platform.

## Structure

### integration/
Integration tests for service interactions:
- `docker-compose.test.yml` - Test compose configuration (planned)
- `test-observability.sh` - Test observability stack (planned)

### unit/
Unit tests for individual components (planned)

### e2e/
End-to-end tests (planned)

## Running Tests

Tests will be integrated with CI/CD pipeline.

```bash
# Integration tests (planned)
make test-integration

# All tests (planned)
make test
```

## Adding Tests

1. Place in appropriate subdirectory
2. Follow naming convention: `test-*.sh` or `*_test.go`
3. Ensure tests can run in CI environment
4. Document prerequisites

