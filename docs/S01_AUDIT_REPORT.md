# Sprint S-01 Audit Report

**Sprint:** S-01 — Addon Shell
**Auditor:** CTO, Keystone Council
**Audit Date:** 2026-06-11
**Files Reviewed:**
- `KeystoneCouncil.toc`
- `Core/Constants.lua`
- `Core/Logger.lua`
- `Core/EventBus.lua`
- `Core/Module.lua`
- `Core/Bootstrap.lua`

**Reference Documents:**
- `docs/KSC_1_0_IMPLEMENTATION_PLAN.md` (S-01 acceptance criteria)
- `docs/KSC_1_0_BLUEPRINT.md` (module specs and public APIs)

---

## Preliminary Finding

**No `S01_COMPLETION_REPORT.md` exists in the repository.**

This audit was requested against a file that was never submitted. What was submitted — and what this audit reviews — is the inherited 0.9.14-alpha codebase. These files have not been rewritten for 1.0. They are being evaluated against S-01 acceptance criteria for the first time here.

This finding alone is grounds for rejection. The audit continues to document every specific deficiency so the engineer has a complete remediation list.

---

## Verdict

**SPRINT S-01: REJECTED**

**Blocking failures:** 9
**Architectural violations:** 7
**Technical debt items:** 6
**Sprint scope violations:** 5

No path to approval without remediation. Specific items follow.

---

## Section 1 — Acceptance Criteria Pass/Fail

The S-01 acceptance criteria from the implementation plan, evaluated against the submitted code.

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Addon loads without Lua errors in WoW | **UNKNOWN** | Cannot verify — no test report submitted. The code references `KC.MainFrame:Toggle()` on bare `/kc` which will Lua-error in S-01 scope since MainFrame does not exist. Presumed FAIL. |
| 2 | `/kc` prints "Keystone Council loaded." to chat | **FAIL** | `HandleSlash` routes bare `/kc` to `KC.MainFrame:Toggle()` (Bootstrap.lua:141). Plan specifies a stub handler printing "Keystone Council loaded." MainFrame is a S-11 module. |
| 3 | `/ksc`, `/key`, `/keys` registered as aliases | **PASS** | Lines 363–366 register all four aliases. |
| 4 | `Module.InitializeAll()` and `Module.EnableAll()` complete without error | **FAIL** | Methods are named `InitializeModules()` and `EnableModules()`, not `InitializeAll()` and `EnableAll()`. Public API names do not match the blueprint spec. |
| 5 | `Logger.Print("test")` outputs to chat frame with addon prefix | **PASS** | Implemented correctly at Logger.lua:5–9. |
| 6 | `Logger.Debug("test")` produces no output when debug = false | **PASS** | Correctly gated at Logger.lua:12. |
| 7 | `Logger.Debug("test")` produces output when debug = true | **PASS** | Correctly gated at Logger.lua:12–14. |
| 8 | `Logger.Error("test")` outputs in red | **PASS** | `|cffff5555` applied at Logger.lua:18. |
| 9 | `Logger.Warn("test")` outputs in yellow | **FAIL** | `Logger.Warn` does not exist. The method is absent from Logger.lua entirely. |
| 10 | `EventBus.Emit("FAKE_EVENT")` with no listeners does not error | **PASS** | Early return at EventBus.lua:21 handles nil listener table. |
| 11 | `EventBus.Emit` with erroring listener does not block others | **PASS** | pcall isolation at EventBus.lua:25–28 is correct. |
| 12 | `Module.GetStatus("nonexistent")` returns nil without error | **FAIL** | `KC.Module.GetStatus(name)` does not exist. Only `KC:GetModuleStatusRows()` exists, which returns all rows, not a single-name lookup. |

**Passing: 6 / 12**
**Failing: 5 / 12**
**Unknown: 1 / 12**

A sprint with 5 hard failures and 1 unverifiable criterion cannot pass.

---

## Section 2 — Missing Requirements

### MR-01: `Logger.Warn` is absent

**Severity: Blocking**

The blueprint Public API for Logger defines four tiers: Print, Warn, Debug, Error. The implementation has three. The S-01 acceptance criterion explicitly tests `Logger.Warn("test")` outputs in yellow. The method does not exist.

Every sprint from S-08 onward uses `Logger.Warn` for integration degradation notices. Building on a Logger without Warn means every future caller will either silent-fail or require a backfill pass.

**Required:** Add `KC.Logger.Warn(message)` outputting yellow (`|cffffff00`).

---

### MR-02: `EventBus.Off` is absent

**Severity: Blocking**

The blueprint Public API for EventBus defines three methods: On, Emit, Off. `Off` is not implemented. Without it, there is no mechanism to deregister listeners. Any module that registers a listener during `OnEnable` and needs to clean up during `OnDisable` or reload will leak listeners across the module lifecycle. This accumulates silently and produces duplicate event firings in long sessions.

**Required:** Implement `KC.EventBus.Off(eventName, owner)` that removes all listeners registered by `owner` for `eventName`.

---

### MR-03: `Module.GetStatus(name)` is absent

**Severity: Blocking**

The blueprint Public API for Module defines `KC.Module.GetStatus(name)` returning a single status string. This is also an explicit acceptance criterion. The implementation provides only `KC:GetModuleStatusRows()` which returns a flat array of all modules. This is not equivalent. Diagnostics (S-14) and Diagnostics panel (S-13) both call `GetStatus` per-module. Building those sprints against the missing API will require a retrofit.

**Required:** Implement `KC.Module.GetStatus(name)` returning the status string for a single named module, or nil if the module is not registered.

---

### MR-04: `KC.FIELD_VERSION` table is absent from Constants

**Severity: Blocking**

The blueprint specifies `KC.FIELD_VERSION = { KEY=1, LEDGER=1, VOTE=1, HELLO=1, ACK=1, RESULT=1 }` as a Constants export. This is consumed by Protocol.lua (S-07) for per-message-type field versioning, which is a core reliability feature of the 1.0 wire format. Without it defined in Constants, Protocol.lua in S-07 either hardcodes the values (technical debt) or imports from an undefined location (runtime error).

**Required:** Add `KC.FIELD_VERSION` table to Constants.lua.

---

### MR-05: `KC.MODES` enum is absent from Constants

**Severity: Blocking**

The blueprint specifies `KC.MODES` as a Constants export containing the valid mode identifiers. Every Council engine and the mode selector UI reads from this enum. Without it, mode validation is done by string comparison scattered across files, which is the 0.9.x pattern the blueprint explicitly replaces.

**Required:** Add `KC.MODES = { SPIN="spin", RAFFLE="raffle", MAJORITY="majority", SMART="smart", CHAOS="chaos" }` to Constants.lua.

---

### MR-06: New event names absent from `KC.EVENTS`

**Severity: Blocking**

The blueprint adds two new events required by S-08 and S-07 respectively:
- `INTEGRATION_HEALTH_CHANGED` — emitted by IntegrationBus, consumed by IntegrationHealthPanel
- `PEER_VERSION_MISMATCH` — emitted by PartySync, consumed by PeerPanel and Toasts

The current `KC.EVENTS` table has neither. The existing `INTEGRATIONS_CHANGED` event is the old name from 0.9.x and does not match the blueprint specification.

**Required:** Add `INTEGRATION_HEALTH_CHANGED` and `PEER_VERSION_MISMATCH` to `KC.EVENTS`. The name `INTEGRATIONS_CHANGED` must be renamed or removed — it is not in the 1.0 spec.

---

### MR-07: `PLAYER_LOGIN` not registered in Bootstrap

**Severity: Blocking**

The blueprint explicitly requires Bootstrap to register `PLAYER_LOGIN` to reset session vote state and trigger social cache warm-up. The current implementation registers `PLAYER_ENTERING_WORLD` instead. These are different events with different timing and guarantees. `PLAYER_LOGIN` fires once per session login; `PLAYER_ENTERING_WORLD` fires on every instance load and reload, including mid-session zone changes, which would incorrectly reset session state during a dungeon.

**Required:** Register `PLAYER_LOGIN` in Bootstrap for session reset and social warm-up. Distinguish from `PLAYER_ENTERING_WORLD` if that event is still needed for other purposes.

---

### MR-08: On-load confirmation message is wrong

**Severity: Minor**

Bootstrap.lua line 392 prints `"ready. Type /kc to convene."` The S-01 acceptance criterion specifies `"Keystone Council loaded."` This is a minor criterion gap but it confirms the files are 0.9.x unmodified — the plan's delivery order explicitly describes a stub that prints the required string.

**Required:** Change on-load print to match acceptance criterion.

---

## Section 3 — Architectural Violations

### AV-01: Module API is on `KC` root, not `KC.Module` namespace

**Severity: Blocking**

The blueprint defines the Module public API as `KC.Module.Register`, `KC.Module.InitializeAll`, `KC.Module.EnableAll`, `KC.Module.GetStatus`, `KC.Module.GetAll`. The implementation attaches everything to the KC root: `KC:RegisterModule`, `KC:InitializeModules`, `KC:EnableModules`. This is a namespace collision. Every module in the system calls `KC:RegisterModule` which means the Module registry is mixed into the top-level addon object alongside everything else. If any other system defines a method named `RegisterModule` on KC, it silently overwrites the registry.

The blueprint establishes `KC.<LayerName>` namespacing for all modules (KC.Logger, KC.EventBus, KC.Module, KC.KeyStore, etc.). Module is the only system that breaks this pattern.

**Required:** Move Module API to `KC.Module` namespace. `KC.Module.Register`, `KC.Module.InitializeAll`, `KC.Module.EnableAll`, `KC.Module.GetStatus`, `KC.Module.GetAll`. Bootstrap.lua must call `KC.Module.InitializeAll()` and `KC.Module.EnableAll()`, not `KC:InitializeModules()`.

---

### AV-02: Method names do not match blueprint Public API

**Severity: Blocking**

| Blueprint API | Actual Name |
|--------------|-------------|
| `KC.Module.Register` | `KC:RegisterModule` |
| `KC.Module.InitializeAll` | `KC:InitializeModules` |
| `KC.Module.EnableAll` | `KC:EnableModules` |
| `KC.Module.GetStatus(name)` | (absent) |
| `KC.Module.GetAll` | `KC:GetModuleStatusRows` |

Method names are a contract. Every sprint from S-02 onward calls these methods by the blueprint-specified names. Building subsequent sprints against wrong names means either: (a) every caller uses the wrong name and the error is discovered late, or (b) a rename pass is required mid-development. Neither is acceptable.

**Required:** Rename all Module methods to match blueprint spec before any sprint builds against them.

---

### AV-03: Module status values do not match blueprint spec

**Severity: Minor**

Blueprint specifies status values: `"registered"`, `"initialized"`, `"enabled"`, `"error"`.
Implementation uses: `"registered"`, `"initialized"`, `"initialize-failed"`, `"enabled"`, `"enable-failed"`.

The blueprint uses a single `"error"` status for any failure state, with the assumption that error detail is logged at the time of failure. The implementation uses two distinct failure states. This is not inherently wrong — two statuses is more precise — but it diverges from the spec without a documented decision. Diagnostics.lua (S-14) will pattern-match on status values. If the spec says `"error"` and the implementation returns `"initialize-failed"`, the diagnostic health matrix will miss failed modules.

**Required:** Either align status values to `"error"` per spec, or document the decision to use `"initialize-failed"` / `"enable-failed"` and update the blueprint spec. Do not leave it undocumented.

---

### AV-04: `KC.PROTOCOL_VERSION` is a string, not a number

**Severity: Blocking**

`Constants.lua` line 7: `KC.PROTOCOL_VERSION = "2"` (string literal).

The blueprint specifies this as a `number`. Protocol.lua (S-07) will call `KC.Protocol.VERSION_COMPATIBLE(version)` comparing incoming version numbers to `KC.PROTOCOL_VERSION`. String-to-number comparison in Lua does not auto-coerce (`"2" == 2` is `false`). Every version compatibility check will silently fail — every peer will appear version-incompatible. This is a silent correctness bug that will not produce a Lua error but will break party sync for all users.

Additionally, for 1.0 the protocol version must be incremented to 3 (per blueprint). The version should be updated now, as a number.

**Required:** Change to `KC.PROTOCOL_VERSION = 3` (number, not string). Update all references.

---

### AV-05: Bootstrap contains logic from 4 future sprints

**Severity: Blocking**

Bootstrap.lua is 411 lines. The S-01 spec describes Bootstrap as: frame creation, ADDON_LOADED handler, slash command registration with stub handler, InitializeAll, EnableAll. What was submitted includes:

- `AddTestKeys()` — DevTools functionality (S-14 scope)
- `ScheduleRefreshKeys()` — integration orchestration (S-08/S-09 scope)
- `RefreshKeys()` — 50-line function calling 6 deleted modules (S-08/S-09 scope)
- `HandleSlash()` — 215 lines routing 40+ commands including deleted commands (mixed sprint scope)
- `ShowHelp()` — 40-line command documentation referencing deleted features

A Bootstrap.lua built for S-01 should be approximately 60–80 lines. The current file is 5× that because it carries forward the entire 0.9.x command surface.

---

### AV-06: Bootstrap references 6 modules deleted in blueprint

**Severity: Blocking**

`HandleSlash` and `RefreshKeys` reference the following modules, all of which are scheduled for deletion in the blueprint:

| Module | Blueprint status | Bootstrap reference |
|--------|-----------------|---------------------|
| `KC.ExternalKeyProvider` | DELETE | Bootstrap.lua:90–98 |
| `KC.ExternalScoreProvider` | DELETE | Bootstrap.lua:99–101 |
| `KC.SharedKeyProvider` | DELETE | Bootstrap.lua:106–108 |
| `KC.GroupKeyProvider` | DELETE | Bootstrap.lua:109–111 |
| `KC.AstralBridge` | DELETE (merged into AstralKeys) | Bootstrap.lua:121–129 |
| `KC.Util` | DELETE (split into Util/) | Bootstrap.lua:282 |

Every reference to a deleted module in the entry-point file is a future runtime error the moment those files are removed from the .toc. These must be excised now.

---

### AV-07: DevTools password pattern persists in Bootstrap

**Severity: Blocking**

Bootstrap.lua lines 327–343 implement the `KC.DevTools:Unlock(rest)` / `KC.DevTools:IsUnlocked()` password flow that the blueprint explicitly eliminates. The blueprint replaces the password gate with `profile.debug = true`. Having the password flow in Bootstrap means it will survive into 1.0 unless explicitly removed. This is not just technical debt — it is a documented architectural decision that was not implemented.

---

## Section 4 — Technical Debt

### TD-01: `HandleSlash` routes commands that do not exist in 1.0

`HandleSlash` contains routes for: `/kc quote guild`, `/kc quote rare`, `/kc dev <password>`, `/kc astraldebug`, `/kc failures`, `/kc streamtest`. These reference deleted features (guild-banter quotes, rare quotes, AstralBridge debug, password-gated dev). They will either silently no-op (nil-safe guards are present) or produce orphaned help text. Either way, they inflate Bootstrap and preserve deleted product surface in the command layer.

---

### TD-02: `ShowHelp()` documents a different product

`ShowHelp()` prints 40 lines of command documentation, many referencing commands from 0.9.x that do not exist in 1.0: `!key`, `/kc quote guild|rare`, `/kc dev <password>`, `/kc failures`, `/kc astraldebug`. A player running 1.0 who types `/kc help` will see commands that do not work.

---

### TD-03: `InitializeDatabase()` called but not defined in Bootstrap scope

`Bootstrap.lua` line 359 calls `self:InitializeDatabase()`. This method is defined somewhere else (likely Config/Defaults.lua or an older version of Bootstrap). Bootstrap should own this call only if it owns the method, or should delegate explicitly to a defined public API (`KC.Defaults.Initialize()`). The implicit cross-file dependency is invisible and fragile.

---

### TD-04: `.toc` version is `0.9.14-alpha`

The .toc still declares `Version: 0.9.14-alpha`. Working toward 1.0 while the manifest declares alpha creates ambiguity for WoW's addon manager and for users on CurseForge/Wago. The version should be updated to `1.0.0-dev` or equivalent at the start of 1.0 development.

---

### TD-05: `VOTES_CHANGED` event name not in blueprint

`KC.EVENTS` includes `VOTES_CHANGED`. The blueprint event table does not include this event. The blueprint uses `SESSION_CHANGED` to cover all vote state changes. If `VOTES_CHANGED` is still needed, it must be documented in the blueprint. If it is a legacy alias, it should be removed.

---

### TD-06: `.toc` `OptionalDeps` references deleted integrations

The .toc declares `OptionalDeps: AstralKeys, BigWigs`. BigWigs / LibKeystone is a deleted integration in 1.0 (SharedKeyProvider removed). The OptionalDeps line should be updated to reflect only AstralKeys.

---

## Section 5 — Sprint Scope Violations

### SV-01: `.toc` loads 11 files scheduled for deletion

The .toc loads:
- `Core/FileManifest.lua` — DELETE
- `Core/Util.lua` — DELETE (split into Util/)
- `Integrations/ExternalKeyProvider.lua` — DELETE
- `Integrations/AstralBridge.lua` — DELETE
- `Integrations/ExternalScoreProvider.lua` — DELETE
- `Integrations/SharedKeyProvider.lua` — DELETE
- `Integrations/GroupKeyProvider.lua` — DELETE
- `Integrations/CountdownProviderA.lua` — DELETE
- `Integrations/CountdownProviderB.lua` — DELETE
- `Council/KC_ChaosMode.lua` — RENAME to ChaosMode.lua
- `UI/KC_PortalActions.lua` — DELETE (merged into TeleportButton)

S-01 requires a clean .toc representing only the files that exist for this sprint. These files should be removed from the .toc and deleted from disk as part of S-01's file-cleanliness requirement.

---

### SV-02: `.toc` load order does not match blueprint

The blueprint specifies load order: Core → Util → Config → Seasons → Data → Comm → Integrations → Council → UI.

The current .toc loads `Core/Diagnostics.lua` after `Core/Bootstrap.lua`. Diagnostics depends on Data, Comm, and Integration layers. Loading it in Core position, after Bootstrap, means it loads before Data, Comm, and Integrations are available — it can only function because those modules do nil-safe guards. This is accidental correctness, not designed correctness. Bootstrap itself is listed last in Core, after Diagnostics. The load order must be restructured.

---

### SV-03: S-01 Bootstrap calls UI modules that do not exist in S-01 scope

`HandleSlash` routes bare `/kc` to `KC.MainFrame:Toggle()`. In S-01 scope, `KC.MainFrame` does not exist. This call will produce a Lua error (`attempt to index a nil value`). S-01 must have a stub slash handler that does not reference UI modules.

---

### SV-04: S-01 Bootstrap calls Data modules that do not exist in S-01 scope

`HandleSlash` routes `/kc clear` to `KC.KeyStore:ClearSource()` and `KC.SessionStore:ClearVotes()`. In S-01 scope, neither exists. Same issue as SV-03.

---

### SV-05: Constants does not reflect 1.0 spec values

`KC.VERSION = "0.9.14-alpha"` — should be `1.0.0-dev` for 1.0 development.
`KC.PROTOCOL_VERSION = "2"` — should be `3` (number) for 1.0.

These are not cosmetic — PROTOCOL_VERSION is used for wire compatibility checks. Running S-07 tests against version "2" while the blueprint designs for version 3 creates a version gap that must be bridged in a later sprint rather than addressed now at zero cost.

---

## Section 6 — Overengineering

### OE-01: `HandleSlash` is a 215-line god function

For S-01, HandleSlash should be a stub. A 215-line routing table for 40+ commands, built before any of those commands have implementations behind them, is scaffolding that has outpaced the structure it was meant to support. Commands that route to deleted or non-existent modules are dead weight. The 0.9.x slash handler should not be carried forward — it should be rebuilt incrementally, adding routes as each sprint's modules come online.

---

### OE-02: `GetModuleStatusRows()` returns a structured table unnecessarily

For S-01, the only required Module output is `GetStatus(name)` returning a string and `GetAll()` returning a flat map. `GetModuleStatusRows()` returns an array of `{name, status}` structs, which is a premature formatting decision. The consumer of this data (Diagnostics) should format its own rows. The Module layer should return raw data.

---

## Section 7 — Underengineering

### UE-01: No `KC.Module.GetAll()` returning a map

The blueprint specifies `KC.Module.GetAll()` returns `{ name: status }` — a flat map. Neither `GetModuleStatusRows()` (which returns an array of structs) nor `GetStatus(name)` (which is absent) satisfies this. Diagnostics needs a full module status snapshot. The current structure requires iterating an array and re-indexing it every time.

---

### UE-02: EventBus has no listener count or inspection capability

For a system that will have 40+ modules all registering listeners, there is no way to inspect listener state for debugging. This is not a hard requirement for S-01 but becomes a gap in S-14 when Diagnostics needs to report EventBus health. A `KC.EventBus.GetListenerCount(eventName)` or `KC.EventBus.GetAll()` method should be considered.

This is flagged as underengineering rather than a blocking issue — it can be added in a later sprint.

---

## Section 8 — Remediation Checklist

The following items must be completed before S-01 can be re-submitted.

### Constants.lua

- [ ] Change `KC.VERSION` to `"1.0.0-dev"`
- [ ] Change `KC.PROTOCOL_VERSION` to `3` (number, not string)
- [ ] Add `KC.FIELD_VERSION = { KEY=1, LEDGER=1, VOTE=1, HELLO=1, ACK=1, RESULT=1 }`
- [ ] Add `KC.MODES = { SPIN="spin", RAFFLE="raffle", MAJORITY="majority", SMART="smart", CHAOS="chaos" }`
- [ ] Add `INTEGRATION_HEALTH_CHANGED` to `KC.EVENTS`
- [ ] Add `PEER_VERSION_MISMATCH` to `KC.EVENTS`
- [ ] Rename `INTEGRATIONS_CHANGED` to `INTEGRATION_HEALTH_CHANGED` or remove it (document decision)
- [ ] Audit `VOTES_CHANGED` — keep with documentation or remove

### Logger.lua

- [ ] Add `KC.Logger.Warn(message)` outputting yellow text (`|cffffff00`)

### EventBus.lua

- [ ] Implement `KC.EventBus.Off(eventName, owner)`

### Module.lua

- [ ] Move API to `KC.Module` namespace (not KC root)
- [ ] Rename `RegisterModule` → `KC.Module.Register`
- [ ] Rename `InitializeModules` → `KC.Module.InitializeAll`
- [ ] Rename `EnableModules` → `KC.Module.EnableAll`
- [ ] Implement `KC.Module.GetStatus(name)` — single-name lookup returning string or nil
- [ ] Rename `GetModuleStatusRows` → `KC.Module.GetAll` returning `{ name: status }` map
- [ ] Align status values to spec: use `"error"` for failure states, OR document the two-status decision and update blueprint

### Bootstrap.lua

- [ ] Replace `HandleSlash` with a stub that prints "Keystone Council loaded." on bare `/kc`
- [ ] Remove `ShowHelp()` or reduce to S-01-scope commands only
- [ ] Remove `AddTestKeys()` — belongs in DevTools (S-14)
- [ ] Remove `RefreshKeys()` — belongs in S-08/S-09 scope
- [ ] Remove `ScheduleRefreshKeys()` — belongs in S-08/S-09 scope
- [ ] Remove all references to: `ExternalKeyProvider`, `ExternalScoreProvider`, `SharedKeyProvider`, `GroupKeyProvider`, `AstralBridge`, `KC.Util`
- [ ] Remove DevTools password unlock pattern (`DevTools:Unlock(rest)`, `DevTools:IsUnlocked()`)
- [ ] Register `PLAYER_LOGIN` event (not just `PLAYER_ENTERING_WORLD`) for session reset
- [ ] Change on-load print to `"Keystone Council loaded."`
- [ ] Update `KC:InitializeModules()` call to `KC.Module.InitializeAll()`
- [ ] Update `KC:EnableModules()` call to `KC.Module.EnableAll()`

### KeystoneCouncil.toc

- [ ] Update `Version` to `1.0.0-dev`
- [ ] Remove `Core/FileManifest.lua`
- [ ] Remove `Core/Util.lua`
- [ ] Remove `Integrations/ExternalKeyProvider.lua`
- [ ] Remove `Integrations/AstralBridge.lua`
- [ ] Remove `Integrations/ExternalScoreProvider.lua`
- [ ] Remove `Integrations/SharedKeyProvider.lua`
- [ ] Remove `Integrations/GroupKeyProvider.lua`
- [ ] Remove `Integrations/CountdownProviderA.lua`
- [ ] Remove `Integrations/CountdownProviderB.lua`
- [ ] Rename `Council/KC_ChaosMode.lua` reference to `Council/ChaosMode.lua`
- [ ] Remove `UI/KC_PortalActions.lua`
- [ ] Update `OptionalDeps` to remove BigWigs
- [ ] Update load order to match blueprint: Core → Util → Config → Seasons → Data → Comm → Integrations → Council → UI
- [ ] Move `Core/Diagnostics.lua` to correct position (after all layers it depends on)
- [ ] For S-01 specifically: .toc should load only S-01 modules; all others may be retained on disk but should not be in the active load order until their sprint is complete

### Files to Delete from Disk

- [ ] `Core/FileManifest.lua`
- [ ] `Core/Util.lua` (after Util/ split is implemented in S-02)
- [ ] `Integrations/ExternalKeyProvider.lua`
- [ ] `Integrations/AstralBridge.lua`
- [ ] `Integrations/ExternalScoreProvider.lua`
- [ ] `Integrations/SharedKeyProvider.lua`
- [ ] `Integrations/GroupKeyProvider.lua`
- [ ] `Integrations/CountdownProviderA.lua`
- [ ] `Integrations/CountdownProviderB.lua`
- [ ] `UI/KC_PortalActions.lua`

---

## Resubmission Requirements

S-01 may be resubmitted when:

1. All items in the remediation checklist are complete
2. A `S01_COMPLETION_REPORT.md` is submitted documenting:
   - Every acceptance criterion and its pass/fail result
   - Evidence of in-client testing (screenshot or log output acceptable)
   - Any deviations from the plan with documented rationale
3. The addon loads in WoW without Lua errors in S-01 scope (only S-01 modules in .toc)
4. All 12 acceptance criteria pass

The remediation checklist has 43 items. This is not a minor revision — it is a foundational rewrite of the Shell sprint to reflect the 1.0 architecture rather than the 0.9.x inherited codebase.

---

*End of S-01 Audit Report*
*Status: REJECTED — resubmission required*
