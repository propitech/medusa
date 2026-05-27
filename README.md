# medusa

Shared GitHub Actions reusable workflows, composite actions, and per-repo templates for the **propitech** organization. Source of truth for CI across all org projects, organized by language (Ruby/Rails first; Go, Rust, Swift planned).

> **Note on inheritance:** GitHub does **not** auto-inherit workflows from this repo. Each consumer repo ships a thin caller workflow file in its own `.github/workflows/` that uses `uses: propitech/medusa/...@v4`. The `templates/` directory contains ready-to-copy starters.

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
bash <(curl -sSL https://raw.githubusercontent.com/propitech/medusa/v4/scripts/bootstrap-rails.sh)

# Then commit .github/ and set CODECOV_TOKEN under Settings → Secrets.
```

The script fetches: `ci.yml`, `stale.yml`, `dependabot.yml`, `pull_request_template.md`, `CODEOWNERS`.

Optional env vars: `FORCE=1` to overwrite, `DRY_RUN=1` to preview, `VERSION=<tag|branch>` to pin a non-`v4` ref, `TARGET=<dir>` to bootstrap into a directory other than `$PWD`.

Zero edits required — `codecov-slug` defaults to your repo's `${{ github.repository }}` automatically.

### Optional secrets in the consumer repo

Both coverage uploads are skipped silently when their secret is not set, so consumers that don't (yet) wire Codecov or Quality.sh can adopt the workflow without first provisioning tokens.

Set these under **Settings → Secrets and variables → Actions** when you want the uploads:

| Secret | Purpose |
|--------|---------|
| `CODECOV_TOKEN` | Upload coverage to Codecov; step skipped when unset |
| `QLTY_COVERAGE_TOKEN` | Upload coverage to Quality.sh; step skipped when unset |

### Versioning

- Pin `@v4` for stability (recommended; current major).
- `@main` for bleeding edge — expect breakage.
- Major-compatible updates re-point the `vN` tag in place. Breaking changes bump to `vN+1`.

## Available reusable workflows

| Workflow | Purpose | Required inputs | Optional inputs | Secrets |
|----------|---------|-----------------|-----------------|---------|
| `.github/workflows/ruby-rails-ci.yml` | Lint (rubocop, pnpm), scan (bundle-audit), test (postgres + rspec + codecov + qlty) | *(none — all defaulted)* | `codecov-slug` (defaults to `${{ github.repository }}`), `enable-frontend` (true), `test-command` (`bin/rails db:test:prepare spec`), `security-scan-command` (`bin/rails bundle:audit:update && bin/rails bundle:audit`), `runs_on` (JSON-encoded label, empty → `ubuntu-latest`; pass `${{ vars.RUNNER_LABELS }}` to route to self-hosted), `container-image` (default `ghcr.io/propitech/runner-rails-8.1:latest`), `timeout-minutes` (default 30, applied uniformly to scan_ruby/lint/test) | `CODECOV_TOKEN` (opt — step skipped when unset), `QLTY_COVERAGE_TOKEN` (opt — step skipped when unset) |
| `.github/workflows/stale.yml` | Close stale issues + PRs daily | — | `days-before-stale` (30), `days-before-close` (5), `exempt-pr-labels` (`dependencies`), `exempt-issue-labels` (`security,critical`), `exempt-milestones` (`future,alpha,beta`), `stale-issue-message` | — |

> Postgres is always started as a service. Non-postgres Rails projects (MySQL, Redis-only, etc.) are not yet supported; see Roadmap.

### Container-first execution model (v4+)

From `@v4` onward, every job in `ruby-rails-ci.yml` runs inside a job-level
`container:` (default image `ghcr.io/propitech/runner-rails-8.1:latest`),
on **both** GitHub-hosted and self-hosted runners. This keeps the
toolchain identical across environments and lets us stop publishing host
ports for service containers, which is the source of port collisions
when multiple jobs run concurrently on the same self-hosted VM.

What that means for callers:

- **No host port mapping.** The `postgres` service no longer publishes
  `5432:5432`. Workflows reach it by service hostname:
  ```yaml
  env:
    DATABASE_URL: postgres://postgres:postgres@postgres:5432
  ```
  Not `localhost:5432` — that won't resolve from inside the job
  container. Caller workflows that override `test-command` should rely
  on this env or set their own DB URL using the `postgres` hostname.
- **N-concurrent safe.** Each job gets its own GHA-managed bridge
  network, so service containers across concurrent jobs no longer fight
  over `0.0.0.0:5432`.
- **Permissions.** The workflow declares `permissions.packages: read`
  so the workflow `GITHUB_TOKEN` can pull the container image from
  GHCR. Consumers do not need to add anything for org-private images.
- **Override the image.** Set the `container-image` input on the
  caller-side `with:` block. The image must ship Ruby, Node, pnpm,
  postgres-client, libpq, libvips, libjemalloc, and chromium +
  chromedriver — otherwise `setup-and-install` and system tests will
  fail.

### Migrating from `@v3` to `@v4`

Breaking changes from `@v3`:

1. The reusable workflow now sets `container:` on every job. If your
   consumer caller workflow pinned `@v3` and depended on the runner's
   host filesystem or host network, retest under `@v4`.
2. `services.postgres.ports` is gone. If you override `test-command`
   and pass a hard-coded `DATABASE_URL=...@localhost:5432`, switch the
   host to `postgres`.
3. `setup-and-install` no longer installs Ruby or Node — it assumes the
   container image bakes both. If you use the action outside the
   reusable workflow, make sure your runner / container has Ruby, Node,
   and pnpm available on `$PATH`.

Caller-side migration: bump the `uses:` reference in your
`.github/workflows/ci.yml` from `@v3` to `@v4`. No new inputs are
required to take the defaults.

## Available composite actions

| Action | Purpose | Inputs |
|--------|---------|--------|
| `actions/ruby-rails/setup-and-install` | Run `bundle install` and `pnpm install --frozen-lockfile`. Assumes Ruby, Node, pnpm, and system deps are already present (i.e. the job is running inside `ghcr.io/propitech/runner-rails-8.1` or an equivalent image). | `install_ruby` (`true`), `install_node` (`true`) |

Reference from a workflow:

```yaml
- uses: propitech/medusa/actions/ruby-rails/setup-and-install@v4
  with:
    install_node: "false"
```

## Versioning policy

- We tag `vN` for major-compatible releases (`v1`, `v2`, ...).
- Breaking changes bump the major version.
- The `vN` tag is force-moved (`git tag -f vN && git push --force --tags`) to the latest compatible commit; consumers pinning `@vN` get fixes automatically.

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
