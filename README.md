# Python Project Template

A modern Python project template with uv, Ruff, mypy, and CI/CD best practices.

## Features

- 📦 **[uv](https://docs.astral.sh/uv/)** for dependency management
- 🧹 **[Ruff](https://github.com/astral-sh/ruff)** for linting and formatting
- 🔍 **[mypy](https://mypy.readthedocs.io/)** for type checking
- ✅ **[pytest](https://pytest.org/)** with coverage reporting
- 🔄 **GitHub Actions** CI/CD with matrix testing
- 📝 **Semantic Release** for automated versioning
- 🔒 **Pre-commit hooks** with conventional commit validation
- 🛡️ **Dependabot** for security updates

## Project Structure

```text
.
├── .github/
│   ├── workflows/
│   │   ├── ci.yml           # CI: Lint, Type-check, Test matrix
│   │   └── release.yml      # CD: Automated versioning & GitHub Release
│   └── dependabot.yml       # Weekly dependency updates
├── scripts/
│   ├── setup-github.ps1     # Configure GitHub repo settings (PowerShell)
│   └── setup-github.sh      # Configure GitHub repo settings (Bash)
├── src/
│   └── {{project_name}}/    # Your project source code
├── tests/                   # Your test suite
├── Dockerfile               # Containerization with uv
├── pyproject.toml           # Project metadata & tool configuration
└── README.md                # This file
```

## Usage

1. Click **"Use this template"** on GitHub.
2. Run the setup script: `.\scripts\setup-github.ps1` (Windows) or `./scripts/setup-github.sh` (Linux/Mac).
3. Update `pyproject.toml` with your project data.
