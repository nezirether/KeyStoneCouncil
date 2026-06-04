# Keystone Council 0.9.9 alpha - AstralKeys + BigWigs key import fix

Changes made:

- Added `## OptionalDeps: AstralKeys, BigWigs` so Keystone Council loads after those addons when installed.
- Fixed `ExternalKeyProvider` to understand AstralKeys saved-variable field names:
  - `unit`
  - `dungeon_id`
  - `key_level`
  - `weekly_best`
  - `mplus_score`
  - `btag`
- Added `AstralCharacters` as an import probe candidate.
- Improved `SharedKeyProvider` / LibKeystone retry behavior for BigWigs.

Expected behavior:

- If AstralKeys is installed and has cached guild/friend keys, Keystone Council imports them.
- If BigWigs is installed with LibKeystone, Keystone Council requests PARTY/GUILD key broadcasts through LibKeystone.
- Other players still need a compatible broadcaster installed for live remote key updates. AstralKeys cached data can fill the list even when players are not actively broadcasting.

Test commands:

```text
/reload
/kc refresh
/kc diag
```

Look for diagnostics like:

```text
External key provider: loaded, imported X via AstralKeys saved variable
Shared key provider: ready
```
