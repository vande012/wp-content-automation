# Development Guide

## Prerequisites
- **Node.js**: Version >= 20.9.0 (required for Next.js)
- **Package Manager**: npm or yarn
- **Browsers**: Playwright browser binaries

## Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd wp-content-automation
   ```

2. **Install dependencies**:
   ```bash
   npm install
   ```

3. **Install browser binaries**:
   ```bash
   npm run install-browsers
   ```

## Configuration & Setup

### 1. Primary Setup Guide
All project configuration, environment variables, and database setup instructions have been consolidated into the root **[README.md](../README.md)**. Use that file as the single source of truth for:
- Database Configuration (Supabase & Prisma)
- Redis / Docker Setup
- Environment Variable reference
- Web Dashboard and CLI execution commands

### 2. Quick Execution Reference
- **Development Server**: `npm run dev:web`
- **Automation CLI**: `npm start`
- **Database Migrations**: `npm run db:migrate`
- **Database Visualizer**: `npm run db:studio`

---

## Execution Modes

### 1. Web-First (Unified Dashboard)
Launch the dashboard to manage site profiles, trigger scraping jobs, and track metrics with real-time feedback.

### 2. CLI-Only (Direct Automation)
Run the core automation directly from the terminal for batch processing or legacy compatibility.
```bash
npm start
```

## Usage

### Running the Full Pipeline
The primary entry point executes the complete scrape-to-csv workflow:
```bash
npm start
```

### Input Data
Add the URLs you wish to scrape to `data/urls.txt`, one per line. You can optionally specify the content type:
```text
https://example.com/about-us page
https://example.com/blog/article-1 post
```

## Development Workflow

### Coding Standards
- Use ES Modules (`import/export`).
- Follow the service-oriented pattern in `src/core/`.
- Document all core functions with JSDoc.

### Utilities
- Use `src/utils/filesystem.js` for all I/O operations.
- Wrap asynchronous calls in the `retry` utility from `src/utils/errors.js` if they involve network or volatile operations.

## Emergency Bypass

> **⚠️ CRITICAL WARNING:** The emergency bypass should **ONLY** be used in genuine emergency situations where immediate deployment is required. Bypassing quality gates removes all automated safety checks and can introduce bugs, security vulnerabilities, or breaking changes into the codebase.

### When to Use Emergency Bypass

**Acceptable scenarios:**
- Critical production hotfix needed immediately
- Server outage requiring emergency deployment
- Security vulnerability requiring immediate patching
- Situations where running full validation would cause more harm than bypassing it

**NOT acceptable scenarios:**
- "I don't have time to fix the tests"
- "The linter is annoying"
- "I'll fix it later"
- Regular development workflow

### How to Use `--no-verify`

Git provides a built-in `--no-verify` flag that bypasses all git hooks:

**Bypass commit hooks:**
```bash
git commit --no-verify -m "emergency: fix critical production bug"
```

**Bypass push hooks:**
```bash
git push --no-verify
```

**Bypass both (commit and push):**
```bash
git commit --no-verify -m "emergency: critical hotfix"
git push --no-verify
```

### What Gets Bypassed

When using `--no-verify`, only the hooks for that specific command are bypassed:

**If you run `git commit --no-verify`:**
- ❌ ESLint validation (pre-commit)
- ❌ Unit tests (pre-commit)
- ❌ Conventional commit message validation (commit-msg)

**If you run `git push --no-verify`:**
- ❌ Full test suite with coverage (pre-push)
- ❌ Web linting (pre-push)
- ❌ Documentation synchronization validation (pre-push)

### Post-Bypass Actions

After using emergency bypass, you **MUST**:

1. **Document the bypass**: Add a note in the commit message or PR explaining why bypass was necessary
2. **Create follow-up ticket**: Document technical debt created
3. **Run validations manually**: Execute all skipped checks as soon as possible
4. **Fix any issues**: Address problems found by manual validation
5. **Update team**: Notify team of the emergency bypass

### Example Emergency Workflow

```bash
# Emergency hotfix scenario
git checkout main
git checkout -b hotfix/critical-bug

# Make emergency fix
# ... edit files ...

# Commit with bypass (document reason)
git commit --no-verify -m "fix(core): emergency patch for security vulnerability CVE-2026-1234"

# Push with bypass
git push --no-verify

# After emergency is resolved:
# 1. Run full validation suite manually
npm run lint
npm run lint:web
npm run test:coverage
node .husky/scripts/validate-docs.js

# 2. Fix any issues found
# 3. Create follow-up PR for any necessary cleanup
```

### Alternative: Fix Issues Instead

In most cases, the correct approach is to **fix the underlying issues** rather than bypass:

- **Linting errors**: Fix the code quality issues
- **Test failures**: Fix the broken tests or implementation
- **Documentation**: Update docs to reflect architecture changes

The time spent fixing issues properly is almost always worth it to maintain code quality.

## Troubleshooting
- **Cloudflare Blocks**: If sites block headless access, try setting `SCRAPER_HEADLESS=false` to debug visually or update the `userAgent` in config.
- **Missing Images**: Check `output/images/image-mapping.json` to verify if images were successfully detected and downloaded.
- **CSS Issues**: If too much CSS is removed, update the `_shouldPreserveClass` whitelist in `src/core/processor.js`.
