# medusa

Shared GitHub Actions reusable workflows, composite actions, and per-repo templates for the **propitech** organization. Source of truth for CI across all org projects, organized by language (Ruby/Rails first; Go, Rust, Swift planned).

> **Note on inheritance:** GitHub does **not** auto-inherit workflows from this repo. Each consumer repo ships a thin caller workflow file in its own `.github/workflows/` that uses `uses: propitech/medusa/...@v1`. The `templates/` directory contains ready-to-copy starters.

## Repo layout

```
medusa/
├── .github/
│   ├── CODEOWNERS                                # for medusa itself
│   └── workflows/
│       ├── ruby-rails-ci.yml                     # reusable: lint + scan + test
│       └── stale.yml                             # reusable: language-agnostic stale bot
├── actions/
│   └── ruby-rails/
│       └── setup-and-install/
│           └── action.yml                        # composite: ruby + pnpm + node
├── scripts/
│   └── bootstrap-rails.sh                        # one-shot consumer installer
├── templates/
│   ├── common/
│   │   ├── pull_request_template.md
│   │   ├── CODEOWNERS
│   │   └── workflows/
│   │       └── stale.yml                         # caller wrapper
│   ├── ruby-rails/
│   │   ├── dependabot.yml
│   │   └── workflows/
│   │       └── ci.yml                            # caller wrapper
│   ├── go/                                       # placeholder
│   ├── rust/                                     # placeholder
│   └── swift/                                    # placeholder
├── agent-plans/                                  # design docs (committed)
├── .gitignore
└── README.md
```

## How to use it in a propitech repo

### Ruby on Rails project

From the root of your consumer repo:

```bash
# One-shot bootstrap (creates .github/ files; idempotent — re-run safe).
bash <(curl -sSL https://raw.githubusercontent.com/propitech/medusa/v1/scripts/bootstrap-rails.sh)

# Then commit .github/ and set CODECOV_TOKEN under Settings → Secrets.
```

The script fetches: `ci.yml`, `stale.yml`, `dependabot.yml`, `pull_request_template.md`, `CODEOWNERS`.

Optional env vars: `FORCE=1` to overwrite, `DRY_RUN=1` to preview, `VERSION=<tag|branch>` to pin a non-`v1` ref, `TARGET=<dir>` to bootstrap into a directory other than `$PWD`.

Zero edits required — `codecov-slug` defaults to your repo's `${{ github.repository }}` automatically.

### Required secrets in the consumer repo

Set these under **Settings → Secrets and variables → Actions**:

| Secret | Required | Purpose |
|--------|----------|---------|
| `CODECOV_TOKEN` | yes | Upload coverage to Codecov |
| `QLTY_COVERAGE_TOKEN` | no | Upload coverage to Quality.sh; step skips silently when unset |

### Versioning

- Pin `@v1` for stability (recommended).
- `@main` for bleeding edge — expect breakage.
- Major-compatible updates re-point the `vN` tag in place. Breaking changes bump to `vN+1`.

## Available reusable workflows

| Workflow | Purpose | Required inputs | Optional inputs | Secrets |
|----------|---------|-----------------|-----------------|---------|
| `.github/workflows/ruby-rails-ci.yml` | Lint (rubocop, pnpm), scan (bundle-audit), test (postgres + rspec + codecov + qlty) | *(none — all defaulted)* | `codecov-slug` (defaults to `${{ github.repository }}`), `enable-frontend` (true), `test-command` (`bin/rails db:test:prepare spec`), `security-scan-command` (`bin/rails bundle:audit:update && bin/rails bundle:audit`), `runs_on` (JSON-encoded label, empty → `ubuntu-latest`; pass `${{ vars.RUNNER_LABELS }}` to route to self-hosted) | `CODECOV_TOKEN` (req), `QLTY_COVERAGE_TOKEN` (opt) |
| `.github/workflows/stale.yml` | Close stale issues + PRs daily | — | `days-before-stale` (30), `days-before-close` (5), `exempt-pr-labels` (`dependencies`), `exempt-issue-labels` (`security,critical`), `exempt-milestones` (`future,alpha,beta`), `stale-issue-message` | — |

> Postgres is always started as a service. Non-postgres Rails projects (MySQL, Redis-only, etc.) are not yet supported; see Roadmap.

## Available composite actions

| Action | Purpose | Inputs |
|--------|---------|--------|
| `actions/ruby-rails/setup-and-install` | Install OS deps (Chrome, libvips, libpq, ...), set up Ruby (from `mise.toml`), install pnpm + Node 20, run `pnpm install --frozen-lockfile` | `install_ruby` (`true`), `install_node` (`true`) |

Reference from a workflow:

```yaml
- uses: propitech/medusa/actions/ruby-rails/setup-and-install@v1
  with:
    install_node: "false"
```

## Versioning policy

- We tag `vN` for major-compatible releases (`v1`, `v2`, ...).
- Breaking changes bump the major version.
- The `vN` tag is force-moved (`git tag -f vN && git push --force --tags`) to the latest compatible commit; consumers pinning `@v1` get fixes automatically.

## Contributing

1. Branch off `main`.
2. Make changes; if you change a reusable workflow's signature (inputs / secrets), document it under "Available reusable workflows" above.
3. Open a PR. CODEOWNERS will request `@propitech/dev` review.
4. To smoke-test a change end-to-end, point a consumer repo at your branch:
   ```yaml
   uses: propitech/medusa/.github/workflows/ruby-rails-ci.yml@<your-branch>
   ```

## Code ownership

See [`.github/CODEOWNERS`](.github/CODEOWNERS). `@propitech/dev` reviews everything in this repo.

## Roadmap

See plans under `agent-plans/` and the project tracker for:

- Tightened per-job permissions, `timeout-minutes`, Ruby/Node matrix
- Conditional services for Rails projects on MySQL / Redis (re-introduces `enable-mysql` / `enable-redis` inputs once implemented)
- Coverage threshold gating, PR coverage comments
- **Create `propitech/.github` repo** for true auto-inherited community files (PR template, CODEOWNERS, issue templates). Removes the per-repo copy step for those files; cannot be done from `medusa` because GitHub only auto-inherits from a repo literally named `.github`.
- Required workflows (Enterprise) to remove caller-file boilerplate
- Go / Rust / Swift CI extractions (with per-language `bootstrap-<lang>.sh` scripts)
- CodeQL workflow
- Cache cleanup workflow
