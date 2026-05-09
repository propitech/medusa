# Rust templates — not yet implemented

Status: **placeholder**. No reusable workflow exists yet.

When the first propitech Rust project lands, extract its CI under
`.github/workflows/rust-ci.yml` (reusable) plus any composite actions
under `actions/rust/`, then add a caller template at
`templates/rust/workflows/ci.yml` and a `bootstrap-rust.sh` script.

Until then, this directory exists only to reserve the namespace.
