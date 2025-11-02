# Contributing

## Development Setup

1. Fork and clone the repository
2. Create feature branch: `git checkout -b feature/your-feature`
3. Make changes and test locally
4. Push to your fork
5. Submit pull request

## Testing Changes

```bash
make kind-up
make istio-install monitoring-install argo-install
make app-build app-test
make deploy-dev
```

## Code Standards

- Go code must pass tests
- YAML must be valid
- Scripts must be POSIX-compliant
- All changes must work on Kind

## Commit Messages

- Use present tense
- Keep under 72 characters
- Reference issues when applicable

## Registry Override

For testing with your own registry:

```bash
export REGISTRY_HOST=your.registry.com:5000
make app-push
```