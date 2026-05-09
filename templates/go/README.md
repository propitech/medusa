# Go templates — not yet implemented

Status: **placeholder**. No reusable workflow exists yet.

When the first propitech Go project lands, extract its CI under
`.github/workflows/go-ci.yml` (reusable) plus any composite actions
under `actions/go/`, then add a caller template at
`templates/go/workflows/ci.yml` and a `bootstrap-go.sh` script.

Until then, this directory exists only to reserve the namespace.
