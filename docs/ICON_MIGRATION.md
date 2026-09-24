# Icon Migration — 3D Asset Set (Phase 3 UI)

## What changed

`AppIcons` high-traffic constants now resolve to `assets/icons/cutouts/*.png`
(31 generated + 3 PIL-derived directionals = 34 files); `AppIcon` renders
asset paths full-color via `Image.asset` (tint never applies to artwork).
Zero call-site edits: all screens consume `AppIcons.*` through `AppIcon`.

## Mapping notes

- Directionals (chevron-left/up/down) derived from chevron-right by flip/rotate.
- `arrowLeft/Right/Back` map to chevrons (visually equivalent at 16–20px).
- `timer`/`lockClock` share timer-clock; `user` shares user-login; `cloudUpload` shares upload.
- Remaining HugeIcons (no generated asset): passport/identity, license, bank,
  fire, title, link, calendar, location, car, hash, file, folder, palette,
  cloud, image, history, qr, share + unused constants. Next icon batch should
  cover: passport, calendar, qr-code, share, fire, file, link.
- Navbar selection uses opacity (1.0/0.45) since tinting cannot apply to artwork.

## Verification

`flutter analyze lib/`: 0 errors/warnings. Fast suites green. Visual check on
device required (FLAG_SECURE blocks screencap): walk Home → Vault → Add →
View → Settings and confirm no missing-image gaps (errorBuilder hides
failures silently by design).

## Rollback plan

1. **Primary (instant):** `git revert <migration-commit>` — single commit,
   `hugeicons` dependency untouched, no pubspec change, so revert restores
   line icons with zero further edits.
2. **Surgical (single icon):** repoint one `AppIcons.*` constant back to its
   HugeIcons value; no other file changes needed.
3. **Asset removal:** `git rm assets/icons/cutouts` only after (1); never
   delete assets while constants reference them (errorBuilder would blank them).
4. Pre-migration state is tagged in history (`3262d54` matte pass parent chain);
   rollback validation = analyzer + widget smoke + device walk.
