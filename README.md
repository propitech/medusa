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
├── .gitignore
└── README.md
```

## How to use it in a propitech repo

### Ruby on Rails project

From the root of your consumer repo:

```bash
mkdir -p .github/workflows

# 1. Caller workflow that delegates to medusa's reusable Ruby/Rails CI.
curl -sSL https://raw.githubusercontent.com/propitech/medusa/v1/templates/ruby-rails/workflows/ci.yml \
  -o .github/workflows/ci.yml

# 2. Stale bot (optional but recommended).
curl -sSL https://raw.githubusercontent.com/propitech/medusa/v1/templates/common/workflows/stale.yml \
  -o .github/workflows/stale.yml

# 3. Dependabot config (must live in your repo; not shareable).
curl -sSL https://raw.githubusercontent.com/propitech/medusa/v1/templates/ruby-rails/dependabot.yml \
  -o .github/dependabot.yml

# 4. PR template + CODEOWNERS (auto-inherit only from a repo named `.github`,
#    so for now copy them per project).
curl -sSL https://raw.githubusercontent.com/propitech/medusa/v1/templates/common/pull_request_template.md \
  -o .github/pull_request_template.md
curl -sSL https://raw.githubusercontent.com/propitech/medusa/v1/templates/common/CODEOWNERS \
  -o .github/CODEOWNERS
```

Then **edit `.github/workflows/ci.yml`**: replace `propitech/REPLACE_ME` with `propitech/<your-repo>` (the codecov slug).

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
| `.github/workflows/ruby-rails-ci.yml` | Lint (rubocop, pnpm), scan (bundle-audit), test (postgres + rspec + codecov + qlty) | `codecov-slug` | `enable-postgres` (true), `enable-redis` (false; reserved), `enable-mysql` (false; reserved), `enable-frontend` (true), `test-command` (`bin/rails db:test:prepare spec`), `security-scan-command` (`bin/rails bundle:audit:update && bin/rails bundle:audit`) | `CODECOV_TOKEN` (req), `QLTY_COVERAGE_TOKEN` (opt) |
| `.github/workflows/stale.yml` | Close stale issues + PRs daily | — | `days-before-stale` (30), `days-before-close` (5), `exempt-pr-labels` (`dependencies`), `exempt-issue-labels` (`security,critical`), `exempt-milestones` (`future,alpha,beta`), `stale-issue-message` | — |

> **Service-toggling caveat:** GitHub Actions cannot conditionally enable `services:`. v1 always starts a postgres container; the `enable-postgres`/`enable-redis`/`enable-mysql` inputs are accepted but currently no-ops. When a non-postgres Rails project arrives, this will be revisited (see Roadmap).

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

See `agent-plans/extract-shared-ci.md` (local only — gitignored) and the project tracker for:

- Tightened per-job permissions, `timeout-minutes`, Ruby/Node matrix
- Conditional services for Rails projects on MySQL / Redis
- Coverage threshold gating, PR coverage comments
- Separate `propitech/.github` repo for true org-default community files (PR template, CODEOWNERS, issue templates) without per-repo copy
- Required workflows (Enterprise) to remove caller-file boilerplate
- Go / Rust / Swift CI extractions
- CodeQL workflow
- Cache cleanup workflow
