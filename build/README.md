# Custom binaries

This directory produces two binaries:

- `build-fossil.sh` → `dist/fossil-ppv`: a thin wrapper around the shared [`fossil-see`](https://github.com/wmacevoy/fossil-sqlcipher-libressl) project (vendored as `vendor/fossil-see`), which builds Fossil 2.28 + SQLCipher (encrypted storage) + LibreSSL (TLS + libcrypto for SQLCipher) + the mode-aware `PRAGMA key` patch. This repo delegates to `vendor/fossil-see/build/build.sh` and copies the result here as `fossil-ppv`.
- `build-qjs.sh` → `dist/qjs-ppv`: QuickJS with the `ppv-crypto` native module (`../src/qjs-crypto.c` + `../src/ppv-keccak.c`) linked against LibreSSL libcrypto (built as a side effect of the `fossil-see` build above, at `vendor/fossil-see/vendor/libressl-build-out`). Provides SHA3-256, SHAKE128, and `randomBytes` to `bin/ppv` without shelling out.

The CLI (`bin/ppv`) is NOT linked into either binary. It runs in `qjs-ppv` alongside `fossil-ppv`. A verifier needs both custom binaries plus `gpg` on PATH — no system `openssl`, no stock `qjs`, no Tcl, no Python at runtime. (For mode-1 elections a stock `fossil` binary suffices in place of `fossil-ppv`; mode-2 requires the SQLCipher build.)

## Vendored dependencies

All build inputs are vendored as git submodules under `vendor/`. After cloning the repo:

```
git submodule update --init --recursive
```

| Submodule | Upstream | Notes |
|---|---|---|
| `vendor/fossil-see` | [wmacevoy/fossil-sqlcipher-libressl](https://github.com/wmacevoy/fossil-sqlcipher-libressl) | The shared encrypted-Fossil build (Fossil + SQLCipher + LibreSSL + the mode-aware key patches). Itself carries nested submodules `vendor/fossil` (drhsqlite/fossil-mirror) and `vendor/sqlcipher-libressl` (wmacevoy/sqlcipher-libressl) — see `vendor/fossil-see/build/versions.env` for those pins. |
| `vendor/quickjs` | bellard/quickjs | `3d5e064e`; CLI runtime. `build-qjs.sh` patches `qjs.c` to register `ppv-crypto` and compiles a custom `qjs-ppv` binary linked against LibreSSL libcrypto. |

To bump the `fossil-see` dependency:

```
cd vendor/fossil-see
git fetch
git checkout <new-ref>
cd ../..
git add vendor/fossil-see
git commit -m "Bump fossil-see to <new-ref>"
```

To bump `vendor/quickjs`, same pattern; update `QUICKJS_REF` in `versions.env` afterward.

## Status

**Working end-to-end on three platforms.** GitHub Actions builds `fossil-ppv` and `qjs-ppv`, runs the unit suite and the federated scenario test, on `linux-glibc-x86_64`, `linux-glibc-arm64`, and `macos-arm64` (Apple Silicon). See `.github/workflows/build-test.yml`. CI's `submodules: recursive` checkout pulls `vendor/fossil-see` and its own nested submodules automatically.

Build-time toolchain: a C compiler, `make`, `awk`, `cmake`, `autoconf`, `automake`, `pkg-config`, `patch`, `git`, `gnupg`. No Tcl (SQLCipher's autosetup uses its bundled `jimsh`), no Python.

## Inputs (env)

| Variable | Default | Meaning |
|---|---|---|
| `OUTPUT_DIR` | `build/dist` | Where `build-fossil.sh` writes `fossil-ppv` |
| `JOBS` | detected via `nproc`/`sysctl` | `make -j` parallelism; passed through to `vendor/fossil-see/build/build.sh` via normal environment inheritance |

Everything else (`LIBRESSL_PREFIX`, `SQLCIPHER_DIR`, `FOSSIL_SRC`, `FOSSIL_REF`, and their defaults) is now internal to `vendor/fossil-see/build/build.sh` — see that project's own `README.md` if you need to override one of those directly.

## Build pipeline

`build-fossil.sh` here is now three steps:

1. **Delegate** to `vendor/fossil-see/build/build.sh`, which builds LibreSSL, produces the SQLCipher amalgamation, patches Fossil source, configures, and compiles — see `vendor/fossil-see/README.md` for that pipeline's own detail.
2. **Install**: copy `vendor/fossil-see/build/dist/fossil-see` to `$OUTPUT_DIR/fossil-ppv`.
3. **Smoke test** `fossil-ppv version`.

## Why the CLI is not linked into Fossil

Originally the plan was to embed the CLI (then in Tcl) inside Fossil via `--with-tcl`. After switching the CLI to QuickJS we kept them separate because:

- **Verifier gets a stronger story.** A mode-1 election can be verified with stock `fossil` + `qjs-ppv` + `gpg`. Only mode-2 (encrypted at rest) actually needs `fossil-ppv`.
- **Fossil's own configure has no `--with-quickjs`.** Embedding would mean inventing our own integration patches, adding work without proportional gain.
- **Standalone is simpler to audit.** Two small binaries with well-defined responsibilities beats one big binary that does both.

Fossil's built-in TH1 (Tcl-flavored templating, baked in) remains available for any future web-UI hook work. We just do not link full Tcl on top.

## Why `ppv-crypto` instead of shelling to `openssl`

The original Phase-1 design had `bin/ppv` shell out to system `openssl` for SHA3-256 and SHAKE128. That worked but had three problems:

1. **`openssl` is a heavy runtime dep** for what is fundamentally two hash primitives.
2. **macOS ships LibreSSL 3.3.6 as its system `openssl`**, which has SHA-3 in the CLI but no SHAKE128 (`openssl shake128` is "invalid command"). Users had to install a modern OpenSSL on top.
3. **Shelling out fork()/exec()'s per hash call**, which adds up for SHAKE128 streams during tally.

`build-qjs.sh` reuses the LibreSSL libcrypto it already builds (as a side effect of `fossil-see`'s build), patches QuickJS to register `ppv-crypto`, and links the resulting `qjs-ppv` against `libcrypto.a`. SHA3-256 and `RAND_bytes` come from LibreSSL EVP/RAND. SHAKE128 is implemented in `src/ppv-keccak.c` (LibreSSL has no SHAKE at any level — empirically verified via `EVP_get_digestbyname("shake128") == NULL`); the implementation is the textbook Keccak-f[1600] sponge from FIPS 202 §3, §6.2, verified byte-identical to OpenSSL on rate-boundary test cases.
