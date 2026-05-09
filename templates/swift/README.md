# Swift templates — not yet implemented

Status: **placeholder**. No reusable workflow exists yet.

When the first propitech Swift project lands, extract its CI under
`.github/workflows/swift-ci.yml` (reusable) plus any composite actions
under `actions/swift/`, then add a caller template at
`templates/swift/workflows/ci.yml` and a `bootstrap-swift.sh` script.

Until then, this directory exists only to reserve the namespace.
