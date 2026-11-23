# Testing Instructions

Run the commands below from the repository root.

## Just Recipes

`just --list` shows the common commands. Recipes that accept a backend use `oxide` by default and also accept `rust-cuda`:

```bash
just develop         # Build an editable extension.
just test            # Build and run the Python and ordinary Rust tests.
just test rust-cuda  # Run the same workflow with Rust-CUDA.
just fixtures        # Run the passing galpy fixture tests.
just diagnostics     # Include known host/device math differences.
just lint python     # Run Python formatting, linting, and type checks.
just lint            # Also run Clippy for all Rust configurations.
just verify          # Regenerate fixtures and check both backends.
```

## Devcontainer

Open the Drift checkout in VS Code and run **Dev Containers: Reopen in Container**. From `/workspaces/drift`, install the `cargo-oxide` CLI once per new container using the same revision as `cuda-host` in Drift's `Cargo.toml`.

```bash
cargo install --locked --git https://github.com/NVIDIA/cuda-rust.git \
    --rev 754b6d10e26919dfb2689d4e1d33da56ad039918 cargo-oxide
```

Drift's default backend, `cuda-oxide`, lives in the `cuda-oxide/` directory of NVIDIA's `cuda-rust` monorepo and uses Rust 1.99.1. Drift's Rust-CUDA reference backend uses `nightly-2026-04-02` with LLVM 7. The image registers CUDA's NVVM library directory with the system loader.

For upstream work, uncomment the `mounts` line in `.devcontainer/devcontainer.json` before creating the container. It mounts `../cuda-rust` at `/workspaces/cuda-rust`, alongside Drift in the VS Code Explorer. Set `CUDA_RUST_PATH` on the host if your checkout lives elsewhere. To use its local CLI, install from the mount:

```bash
cargo +1.99.1 install --locked --force \
    --path /workspaces/cuda-rust/cuda-oxide/crates/cargo-oxide
```

## Nix

Run `nix develop` from the repository root. The shell remains in that directory and installs the pinned `cargo-oxide` frontend on its first normal entry. Before using Rust-CUDA for the first time, install its toolchain with:

```bash
rustup toolchain install nightly-2026-04-02 --profile minimal --component rust-src --component rustc-dev --component rust-analyzer --component rustfmt --component clippy --component llvm-tools
```

## Galpy Fixture Tests

The galpy reference data is generated locally and ignored by Git. From the devcontainer or Nix shell, download and build the pinned native galpy 1.11.2 source and generate both basic references and both 100-case corpora with:

```bash
./scripts/generate_galpy_fixtures.py
```

Use `reference` or `corpus` as the optional argument to generate only that set. The verified archive, patched source, and editable Python environment remain available under `tmp/galpy-fixtures`; the source and environment are recreated cleanly on each run. The generator checks that native `libgalpy` loaded and validates the complete staged output before replacing any fixture files.

The basic references are written to `tests/fixtures/dopr54_galpy_native/reference.fixture` and `tests/fixtures/dop853_galpy_native/reference.fixture`; corpus cases are written beside them as `case_XXX.fixture`.

The passing fixture suite covers the DOPR54 and DOP853 basic CPU/GPU contracts, bit-exact CPU comparison across both 100-case corpora, and GPU error summaries across both corpora. Tests run serially because they share one GPU.

### cuda-oxide

```bash
cargo oxide test --materialize-cubin -- \
    --release --tests -- \
    --ignored --test-threads=1 --nocapture \
    --skip tests::dopr54_gpu_matches_native_galpy_fixtures \
    --skip tests::dop853_gpu_matches_native_galpy_dump \
    --skip tests::dop853_gpu_matches_native_galpy_fixtures
```

### Rust-CUDA

```bash
cargo +nightly-2026-04-02 test \
    --release --no-default-features --features rust-cuda \
    --tests -- --ignored --test-threads=1 --nocapture \
    --skip tests::dopr54_gpu_matches_native_galpy_fixtures \
    --skip tests::dop853_gpu_matches_native_galpy_dump \
    --skip tests::dop853_gpu_matches_native_galpy_fixtures
```

The skipped tests require bit-exact agreement between native host math and CUDA device math. They are retained as strict diagnostic probes and fail at the known transcendental differences. Remove the three `--skip` options to run them as well, expecting a non-zero overall test result.

## Ordinary Tests

Run the ordinary non-ignored test targets through cuda-oxide with:

```bash
cargo oxide test --materialize-cubin -- --release --tests
```

Or through Rust-CUDA with:

```bash
cargo +nightly-2026-04-02 test \
    --release --no-default-features --features rust-cuda --tests
```

## Linting

Check the default cuda-oxide configuration with:

```bash
cargo clippy --workspace --all-targets -- -D warnings
```

Check the Rust-CUDA configuration with:

```bash
cargo +nightly-2026-04-02 clippy \
    --workspace --all-targets --no-default-features \
    --features rust-cuda -- \
    -D warnings -A clippy::duplicated-attributes -A unused-attributes
```

The two Rust-CUDA allowances cover `cuda_builder` injecting `no_std` into the already-`no_std` shared crate. All other warnings remain errors.

## Testing local cuda-rust changes

Drift normally builds against the Git revision in `Cargo.lock`. To use edits from the sibling checkout, append this temporary override to Drift's `.cargo/config.toml`:

```toml
[patch."https://github.com/NVIDIA/cuda-rust.git"]
cuda-core = { path = "../cuda-rust/cuda-core" }
cuda-device = { path = "../cuda-rust/cuda-oxide/crates/cuda-device" }
cuda-host = { path = "../cuda-rust/cuda-oxide/crates/cuda-host" }
```

Run `cargo metadata --format-version 1 > /dev/null` once to update the local lockfile before using Drift's `--locked` recipes. Keep the patch and lockfile changes local. To return to the pinned revision, remove the patch section and restore the corresponding lockfile changes.

## Wheel Builds

Published wheels use cuda-oxide. From a glibc 2.28 release environment, build and validate the wheel with:

```bash
just wheel
```

On a newer glibc host, use Zig to target glibc 2.28:

```bash
just wheel zig
```

The validated wheel is written to `dist/`. Recheck an existing artifact with:

```bash
just wheel-check dist/astrodrift-<version>-cp313-abi3-manylinux_2_28_x86_64.whl
```

See [Wheel Compatibility](Wheel_Compatibility.md) for the release contract.

For reference, build a development-only Rust-CUDA wheel with:

```bash
RUSTUP_TOOLCHAIN=nightly-2026-04-02 uv run --no-sync maturin build \
    --release \
    --locked \
    --no-default-features \
    --features rust-cuda \
    --compatibility linux \
    --interpreter "${PYTHON:-$UV_PROJECT_ENVIRONMENT/bin/python}" \
    --out dist/rust-cuda
```

## TODO

- Replace the localized raw time-major output writer with a proof-carrying cuda-device view once a runtime-sized strided representation is available without changing the trajectory allocation or layout.
