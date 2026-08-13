# Fossil source patches

Small patches applied to the upstream Fossil source tree during the build. Each patch is self-contained, attributed to a specific Fossil revision, and small enough to read in one sitting.

## Patches in this directory

- **`qjs-register-ppv-crypto.patch`** — registers the `ppv-crypto` native module into `qjs.c` so `qjs-ppv` provides `sha3_256`, `shake128`, and `randomBytes` to `bin/ppv` without shelling out. Applied by `build-qjs.sh`, not `build-fossil.sh`. Target revision: `QUICKJS_REF` in `versions.env`.

## Patches that moved to fossil-see

The mode-aware key source patch and the `fossil server`/`fossil ui` encryption fix used to live here. Both were factored out into the shared [`fossil-see`](https://github.com/wmacevoy/fossil-sqlcipher-libressl) project (vendored here as `vendor/fossil-see`), since the bug and fix apply to any SEE-enabled Fossil build, not just this one — see `vendor/fossil-see/build/patches/README.md` in that submodule:

- `fossil-db-key.patch` (renamed identifiers: `FOSSIL_PPV_KEY`/`FOSSIL_PPV_STOCK_PROMPT`/`ppv_decrypt_master_key` → `FOSSIL_SEE_KEY`/`FOSSIL_SEE_STOCK_PROMPT`/`see_decrypt_master_key` — same mode-aware key-source design, generic naming). See `docs/threat-model.md` here for this project's specific use of it (roster, convener, mode-2 group key) and `vendor/fossil-see/docs/SECURITY.md` for the generic mechanism.
- `fossil-server-key-validator.patch` (unchanged — fixes `fossil server`/`fossil ui` failing to open any SEE-encrypted repo). Upstream write-up, drafted but not yet filed with fossil-scm.org: `vendor/fossil-see/docs/upstream-report-fossil-server-see-key.md`.

`build/build-fossil.sh` is now a thin wrapper around `vendor/fossil-see/build/build.sh`; it no longer applies any Fossil patches itself.

## Conventions

- One patch per concern. Don't bundle unrelated edits.
- Patches are unified diffs (`diff -u` or `git diff` output), applied with `patch -p1` from the source root they target.
- Verify against the pinned ref before treating a patch as ready.
