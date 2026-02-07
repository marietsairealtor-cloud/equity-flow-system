# RELEASES — Rollback Discipline (Section 5)

## Principles (LOCKED)

- Releases are identified by **annotated git tags** on `main`.
- Rollback is performed by redeploying a **previous tag** (never by hotfixing production directly).
- Every release must pass CI on `main` and a clean checkout build.

## Tag Format

- `vYYYY.MM.DD.N` (N starts at 1 each day)
- Example: `v2026.03.08.1`

## Release Steps

1. Ensure `main` is clean and up to date.
2. Run `npm run ship` on `main` (must pass).
3. Create annotated tag:
   - `git tag -a vYYYY.MM.DD.N -m "Release vYYYY.MM.DD.N"`
4. Push tag:
   - `git push origin vYYYY.MM.DD.N`
5. Verify CI green for the tagged commit.

## Rollback Steps

1. Identify last known-good tag (e.g., `v2026.03.08.1`).
2. Redeploy that tag in hosting provider.
3. Verify `npm run ship` passes on that tag locally if needed.

