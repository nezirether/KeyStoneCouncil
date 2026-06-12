# Keystone Council 1.0 — Implementation Plan

**Authority:** KSC_1_0_BLUEPRINT.md + KSC_1_0_PRD.md
**Date:** 2026-06-11
**Format:** Sequential sprints. Each sprint must reach acceptance criteria before the next begins.

---

## Reading This Document

Each sprint is a vertical slice of working software. A sprint is **done** when every acceptance criterion passes, not when code is written. Testing requirements are mandatory — a sprint with failing tests is not done.

Sprints are numbered `S-01` through `S-14`. They must be completed in order. Dependencies are explicit.

An engineer starting from an empty repository follows this document top-to-bottom.

---

## Sprint Overview

| Sprint | Name | Layer | Modules Touched |
|--------|------|-------|-----------------|
| S-01 | Addon Shell | Foundation | .toc, Bootstrap, Constants, EventBus, Module, Logger |
| S-02 | Utilities | Foundation | Names, Social, Keys, Group |
| S-03 | Configuration | Foundation | Defaults |
| S-04 | Seasonal Data | Data | Season_TWW2, SeasonRegistry, SourcePriorityMap |
| S-05 | Key Storage | Data | KeyStore, KeyLedger |
| S-06 | Session & History | Data | SessionStore, HistoryStore, StatsStore, SeasonBest |
| S-07 | Network Protocol | Networking | Protocol, PartySync, KeyNetwork |
| S-08 | Native Integration | Integrations | IntegrationBus, BlizzardKeys |
| S-09 | AstralKeys Integration | Integrations | AstralKeys |
| S-10 | Decision Engines | Council | Modes, SpinEngine, VoteEngine, MajorityEngine, SmartEngine, ChaosMode, ReadyCheck, ResultExplainer |
| S-11 | Core UI | UI | MainFrame, KeyList, MinimapButton, Toasts |
| S-12 | Decision UI | UI | VotePanel, WinnerBanner, StreamerOverlay, ResultRenderer, Wheel |
| S-13 | Support UI | UI | CandidateInspector, IntegrationHealthPanel, Settings, StatsPanel, PeerPanel, TeleportButton, DevPanel |
| S-14 | Release Candidate | Polish | Diagnostics, Quotes, DevTools, Migration v4, full .toc audit |

---

## S-01 — Addon Shell

**Goal:**
The addon loads in WoW without errors. The slash command `/kc` is registered. The module lifecycle (init → enable) runs and completes. Logger output reaches the chat frame.

---

### Modules

- `KeystoneCouncil.toc`
- `Core/Constants.lua`
- `Core/EventBus.lua`
- `Core/Module.lua`
- `Core/Logger.lua`
- `Core/Bootstrap.lua`

---

### Dependencies

None. This is the foundation. Nothing depends on anything outside this sprint.

---

### Delivery Order

1. `KeystoneCouncil.toc` — stub with addon name, interface version, and load order for this sprint's files only. Expand each sprint.
2. `Core/Constants.lua` — all event names, KC.VERSION, KC.ADDON_NAME, KC.COMM_PREFIX, KC.PROTOCOL_VERSION, KC.FIELD_VERSION table, KC.MODES enum, KC.COLORS.
3. `Core/Logger.lua` — Print, Warn, Debug, Error. Debug tier reads from a temporary `KC._debug` flag (profile not available yet).
4. `Core/EventBus.lua` — On, Emit, Off. pcall isolation per listener.
5. `Core/Module.lua` — Register, InitializeAll, EnableAll, GetStatus, GetAll.
6. `Core/Bootstrap.lua` — ADDON_LOADED frame, slash command registration for `/kc` and aliases, stub slash handler that prints "Keystone Council loaded.", call InitializeAll and EnableAll.

---

### Acceptance Criteria

- [ ] Addon loads without Lua errors in WoW
- [ ] `/kc` prints "Keystone Council loaded." to chat
- [ ] `/ksc`, `/key`, `/keys` are registered aliases and respond identically
- [ ] `Module.InitializeAll()` and `Module.EnableAll()` complete without error
- [ ] `Logger.Print("test")` outputs to chat frame with addon prefix
- [ ] `Logger.Debug("test")` produces no output when `KC._debug = false`
- [ ] `Logger.Debug("test")` produces output when `KC._debug = true`
- [ ] `Logger.Error("test")` outputs in red
- [ ] `Logger.Warn("test")` outputs in yellow
- [ ] `EventBus.Emit("FAKE_EVENT")` with no listeners does not error
- [ ] `EventBus.Emit` with a listener that errors does not prevent other listeners from firing
- [ ] `Module.GetStatus("nonexistent")` returns nil without error

---

### Testing Requirements

- Manually load addon in WoW client
- Verify each slash command alias
- Verify each Logger tier output
- Register two EventBus listeners; make one throw an error; verify the second still fires
- Register a module; call InitializeAll; verify GetStatus returns "initialized"

---

## S-02 — Utilities

**Goal:**
All name normalization, social roster caching, key utility functions, and group state utilities are available as clean, testable modules. No WoW API calls yet — stub any calls that require a live client.

---

### Modules

- `Util/Names.lua`
- `Util/Social.lua`
- `Util/Keys.lua`
- `Util/Group.lua`

---

### Dependencies

- S-01 complete (Core layer available)

---

### Delivery Order

1. `Util/Names.lua` — PlayerFullName, NormalizePlayerName, GetUnitFullName, FindUnitTokenByName, SplitFullName, IsSamePlayer.
2. `Util/Group.lua` — IsCurrentPlayerLeader, GetGroupSize, GetGroupMembers, GetGroupChannel, IsInInstance. Wrap all WoW API calls so they can be stubbed.
3. `Util/Social.lua` — IsGuildMember, IsFriend, IsPartyMember, IsOwnerOnline, GetGuildRank, RebuildGuildCache, RebuildFriendCache. Register GUILD_ROSTER_UPDATE and FRIENDLIST_UPDATE frame events for cache invalidation.
4. `Util/Keys.lua` — KeySignature, FormatKeystoneLink, EnrichKeyData, GetOwnedKey, GetUnitMythicPlusScore, GetUnitMythicPlusWeeklyBest. GetOwnedKey is a stub that returns nil until BlizzardKeys is wired in S-08.

---

### Acceptance Criteria

- [ ] `Names.NormalizePlayerName("Jaxen-Stormrage")` returns `"jaxen-stormrage"`
- [ ] `Names.NormalizePlayerName("Jaxen - Stormrage")` returns `"jaxen-stormrage"` (spaces removed)
- [ ] `Names.SplitFullName("Jaxen-Stormrage")` returns `"Jaxen"`, `"Stormrage"`
- [ ] `Names.IsSamePlayer("jaxen-stormrage", "Jaxen-Stormrage")` returns true
- [ ] `Names.IsSamePlayer("jaxen-stormrage", "chopper-stormrage")` returns false
- [ ] `Keys.KeySignature({ ownerGUID="GUID1", dungeonID=503 })` returns `"GUID1:503"`
- [ ] `Social.RebuildGuildCache()` does not error in a live client (empty is acceptable)
- [ ] `Social.RebuildFriendCache()` does not error in a live client
- [ ] `Group.GetGroupChannel()` returns a non-nil string in all group contexts
- [ ] `Group.IsInInstance()` returns false when outside an instance

---

### Testing Requirements

- Test NormalizePlayerName with 5 input variations (spaces, dashes, mixed case, realm suffix, no realm)
- Test IsSamePlayer with matching and non-matching pairs
- Test KeySignature with valid and missing fields
- Load in WoW client; verify Social cache rebuild does not error
- Verify GUILD_ROSTER_UPDATE triggers RebuildGuildCache (check via Logger.Debug output)

---

## S-03 — Configuration

**Goal:**
Default profile values are defined and accessible. SavedVariables initialize correctly on first load and survive a reload without corruption.

---

### Modules

- `Config/Defaults.lua`
- `Core/Bootstrap.lua` (extended — SavedVariables init)

---

### Dependencies

- S-01 complete

---

### Delivery Order

1. `Config/Defaults.lua` — Profile v4 defaults table, Global defaults table, PROFILE_VERSION = 4. Every field documented inline.
2. Extend `Bootstrap.lua` — On ADDON_LOADED: initialize `KeystoneCouncilDB` if nil, merge missing keys from Defaults.Profile (do not overwrite existing values), set `profileVersion` if missing.
3. Wire `Logger.Debug` to check `KeystoneCouncilDB.profile.debug` instead of `KC._debug`.

---

### Acceptance Criteria

- [ ] On first load, `KeystoneCouncilDB` is created with all default values
- [ ] On reload, existing SavedVariables values are preserved (not overwritten by defaults)
- [ ] `profileVersion` is set to 4 on first load
- [ ] `profile.mode` defaults to `"spin"`
- [ ] `profile.debug` defaults to `false`
- [ ] `profile.smart.recentPenalty` defaults to `0.65`
- [ ] `Logger.Debug` produces no output when `profile.debug = false`
- [ ] `Logger.Debug` produces output after setting `profile.debug = true` and reloading
- [ ] Adding a new key to Defaults.Profile and reloading merges it into existing SavedVariables

---

### Testing Requirements

- Delete SavedVariables file; reload; verify all defaults present
- Modify a setting; reload; verify setting persists
- Manually remove a key from SavedVariables; reload; verify it is restored from defaults
- Toggle `profile.debug` to true; verify Debug logger activates

---

## S-04 — Seasonal Data

**Goal:**
Dungeon lookup is data-driven and season-agnostic. Any dungeonID returns a valid record. Adding a new season requires only a new data file.

---

### Modules

- `Seasons/Season_TWW2.lua`
- `Seasons/Season_TWW1.lua` (optional — include for completeness)
- `Data/SeasonRegistry.lua`
- `Data/SourcePriorityMap.lua`
- `Core/Constants.lua` (extend — add `KC.ACTIVE_SEASON`)

---

### Dependencies

- S-01 complete

---

### Delivery Order

1. Extend `Constants.lua` — add `KC.ACTIVE_SEASON = "TWW2"`.
2. `Seasons/Season_TWW2.lua` — all 14 TWW2 dungeons with id, name, shortName, mapID.
3. `Seasons/Season_TWW1.lua` — prior season dungeons (for historical ledger display).
4. `Data/SourcePriorityMap.lua` — all source names and priority values. Expose `Get(sourceName)`.
5. `Data/SeasonRegistry.lua` — load all KC.SeasonData tables, build ID-indexed lookup per season, implement GetDungeon, GetAllDungeons, GetCurrentSeason, GetDungeonFromSeason, safe fallback.

---

### Acceptance Criteria

- [ ] `SeasonRegistry.GetDungeon(503)` returns `{ id=503, name="Ara-Kara, City of Echoes", shortName="AK", mapID=2530 }`
- [ ] `SeasonRegistry.GetDungeon(99999)` returns `{ id=99999, name="Dungeon #99999", shortName="???", mapID=0 }` — no error, no nil
- [ ] `SeasonRegistry.GetAllDungeons()` returns exactly 14 entries for TWW2
- [ ] `SeasonRegistry.GetCurrentSeason().key` returns `"TWW2"`
- [ ] `SeasonRegistry.GetDungeonFromSeason(503, "TWW2")` returns the correct dungeon
- [ ] `SeasonRegistry.GetDungeonFromSeason(503, "UNKNOWN_SEASON")` returns the safe fallback — no error
- [ ] `SourcePriorityMap.Get("Blizzard")` returns `100`
- [ ] `SourcePriorityMap.Get("AstralBridge")` returns `55`
- [ ] `SourcePriorityMap.Get("NonExistentSource")` returns `0` — no error
- [ ] Changing `KC.ACTIVE_SEASON` to `"TWW1"` and reloading returns TWW1 dungeons from GetAllDungeons

---

### Testing Requirements

- Call GetDungeon with every valid TWW2 dungeon ID; verify correct name returned
- Call GetDungeon with 5 invalid IDs including 0, negative, and very large numbers
- Call GetAllDungeons; verify count and that no entry has a nil field
- Simulate season change by toggling ACTIVE_SEASON; verify GetCurrentSeason reflects change
- Call SourcePriorityMap.Get for every defined source; verify expected priority

---

## S-05 — Key Storage

**Goal:**
Keys can be inserted, deduplicated, sorted, and retrieved by view. The persistent ledger records keys and survives a reload. On login, the ledger hydrates the live cache.

---

### Modules

- `Data/KeyStore.lua`
- `Data/KeyLedger.lua`

---

### Dependencies

- S-01, S-02, S-03, S-04 complete

---

### Delivery Order

1. `Data/KeyStore.lua` — Normalize, Upsert, Remove, GetAll, GetByView, GetByID, Clear, Count, DeduplicateByOwner. Emit KEYS_CHANGED on mutation. Import priorities from SourcePriorityMap.
2. `Data/KeyLedger.lua` — Record, GetAll, GetByView, HydrateStore, AutoCleanup, GetAuditSummary, Count. Write to KeystoneCouncilDB.global.keyLedger. Register PLAYER_LOGIN to call HydrateStore then AutoCleanup.

---

### Acceptance Criteria

- [ ] `KeyStore.Upsert(key, "Blizzard")` with a valid key record does not error
- [ ] `KeyStore.GetAll()` returns the upserted key
- [ ] Upserting the same key ID twice keeps only one entry
- [ ] Upserting the same owner from two sources keeps the higher-priority source
- [ ] Upserting the same owner from the same source with a newer `updatedAt` replaces the old entry
- [ ] `KeyStore.GetByView("party")` returns only keys with bucket="party"
- [ ] `KeyStore.GetByView("all")` returns all keys regardless of bucket
- [ ] `KeyStore.Remove(keyID)` removes the entry and emits KEYS_CHANGED
- [ ] `KeyStore.Clear("Blizzard")` removes only Blizzard-sourced keys
- [ ] `KeyStore.Count()` returns the correct count after each mutation
- [ ] KEYS_CHANGED is emitted once per Upsert call
- [ ] `KeyLedger.Record(key)` writes to KeystoneCouncilDB.global.keyLedger
- [ ] After reload, `KeyLedger.HydrateStore()` repopulates KeyStore with ledger entries
- [ ] `KeyLedger.AutoCleanup()` removes entries older than 8 days
- [ ] `KeyLedger.AutoCleanup()` enforces the 500-entry cap (add 600 entries; verify 500 remain)
- [ ] `KeyLedger.Count()` returns accurate count

---

### Testing Requirements

- Insert 10 keys from different sources; verify GetAll returns 10
- Insert same key from Blizzard (100) and AstralBridge (55); verify Blizzard entry wins
- Insert same key from AstralBridge twice with different timestamps; verify newer wins
- Insert 600 ledger entries; run AutoCleanup; verify 500 remain (oldest removed)
- Insert entries with timestamps >8 days ago; run AutoCleanup; verify they are removed
- Reload WoW client; verify ledger entries reappear in KeyStore via HydrateStore
- Insert a key, remove it, verify KEYS_CHANGED fired twice (once per operation)

---

## S-06 — Session & History

**Goal:**
Vote sessions open and close correctly. Votes are recorded and replay-protected. Selection history and statistics persist across reloads.

---

### Modules

- `Data/SessionStore.lua`
- `Data/HistoryStore.lua`
- `Data/StatsStore.lua`
- `Data/SeasonBest.lua`

---

### Dependencies

- S-01, S-03 complete

---

### Delivery Order

1. `Data/SessionStore.lua` — StartVoteSession, SetVote, SetVoteOpen, RecordSelection, GetVotes, IsVoteOpen, GetMode, GetToken, IsClosedToken, GetSelections. Emit SESSION_CHANGED on mutation. Register PLAYER_LOGIN to reset vote state.
2. `Data/HistoryStore.lua` — Record, GetRecent, GetAll, Count. Cap at 50.
3. `Data/StatsStore.lua` — Record, GetPlayerStats, GetDungeonStats, GetTotal, Reset.
4. `Data/SeasonBest.lua` — Record, Get, GetAll. Persist to KeystoneCouncilDB.global.seasonBest.

---

### Acceptance Criteria

- [ ] `SessionStore.StartVoteSession("raffle", "token123")` sets voteOpen=true, voteMode="raffle", voteToken="token123"
- [ ] `SessionStore.SetVote("Jaxen-SR", "GUID1:503")` records the vote
- [ ] `SessionStore.SetVoteOpen(false)` closes the session and adds token to closedVoteTokens
- [ ] `SessionStore.IsClosedToken("token123")` returns true after closing
- [ ] `SessionStore.IsVoteOpen()` returns false after reload (PLAYER_LOGIN reset)
- [ ] `SessionStore.GetVotes()` returns the vote map
- [ ] SESSION_CHANGED emits once per StartVoteSession, SetVote, SetVoteOpen call
- [ ] Closed vote token cache caps at 8 (add 10 tokens; verify oldest 2 are evicted)
- [ ] `SessionStore.RecordSelection(result)` appends to selections; caps at 50
- [ ] `HistoryStore.Record(result)` appends; caps at 50
- [ ] `HistoryStore.GetRecent(3)` returns the 3 most recent entries
- [ ] `StatsStore.Record(result)` increments player and dungeon counts
- [ ] `StatsStore.GetPlayerStats()` returns sorted player list
- [ ] `StatsStore.GetTotal()` returns total selection count
- [ ] `SeasonBest.Record(503, 18, true)` stores the record
- [ ] `SeasonBest.Get(503)` returns the stored record
- [ ] `SeasonBest.Record(503, 15, true)` does NOT overwrite a higher stored level (18)

---

### Testing Requirements

- Start a vote session, cast 3 votes, close session; verify token is closed and votes are retained
- Reload; verify voteOpen is false and closedVoteTokens are retained
- Add 60 selections to SessionStore; verify cap at 50
- Add 60 records to HistoryStore; verify cap at 50
- Record stats for 3 players and 4 dungeons; verify GetPlayerStats and GetDungeonStats return correct sorted results
- Record a season best of 15 then 18 then 12 for the same dungeon; verify Get returns 18

---

## S-07 — Network Protocol

**Goal:**
Messages can be encoded, sent, received, and decoded. Reliable messages get ACKed. Version mismatches are detected and logged. The party can exchange key data.

---

### Modules

- `Comm/Protocol.lua`
- `Comm/PartySync.lua`
- `Comm/KeyNetwork.lua`

---

### Dependencies

- S-01, S-02, S-04, S-05 complete

---

### Delivery Order

1. `Comm/Protocol.lua` — Encode, Decode, VERSION_COMPATIBLE. All message types. Field versioning. 900-byte cap enforcement. Safe fallback on decode errors.
2. `Comm/PartySync.lua` — Send, BroadcastHello, BroadcastKey, BroadcastLedger, BroadcastVote, BroadcastVoteOpen, BroadcastResult, GetPeers, GetPendingCount, GetFailedCount, ProcessRetries. Register CHAT_MSG_ADDON. Emit PEER_VERSION_MISMATCH on incompatible peer.
3. `Comm/KeyNetwork.lua` — BroadcastKey, BroadcastHello, GetPeers. GUILD channel only.

---

### Acceptance Criteria

- [ ] `Protocol.Encode("KEY", fields)` returns a string under 900 bytes for a full key record
- [ ] `Protocol.Decode(encodedString)` returns the original fields without loss
- [ ] Encoding then decoding a KEY message produces identical field values
- [ ] `Protocol.Encode("KEY", fields)` with a payload over 900 bytes returns nil and an error string
- [ ] `Protocol.Decode` with a mismatched PROTOCOL_VERSION returns nil with reason "version_mismatch"
- [ ] `Protocol.Decode` with an unknown FIELD_VERSION decodes known fields and does not error
- [ ] `Protocol.VERSION_COMPATIBLE(KC.PROTOCOL_VERSION)` returns true
- [ ] `Protocol.VERSION_COMPATIBLE(0)` returns false
- [ ] `PartySync.BroadcastHello()` does not error when not in a group
- [ ] `PartySync.BroadcastKey(key)` encodes and sends without error when in a group
- [ ] `PartySync.GetPendingCount()` returns 0 initially
- [ ] `PartySync.GetPeers()` returns empty table initially
- [ ] A HELLO from a peer with a different PROTOCOL_VERSION emits PEER_VERSION_MISMATCH
- [ ] `PartySync.ProcessRetries()` does not error when pending queue is empty
- [ ] `KeyNetwork.BroadcastKey(key)` does not error when not in a guild

---

### Testing Requirements

- Encode and decode all 7 message types; verify round-trip fidelity for every field
- Encode a message with 901+ bytes of content; verify nil return
- Construct a payload with PROTOCOL_VERSION=0; decode it; verify version_mismatch
- Construct a payload with FIELD_VERSION=99 for KEY type; verify known fields decode correctly
- In a live WoW client with a party member also running KSC: BroadcastHello from both sides; verify each sees the other in GetPeers
- Verify ACK flow: send a KEY message; verify ACK received; verify pending count returns to 0
- Simulate failed ACK: verify retry fires after 3 seconds; verify failed count increments after 2 attempts

---

## S-08 — Native Integration

**Goal:**
The player's own key is read from WoW APIs and inserted into KeyStore as the highest-priority entry. Integration health is tracked and queryable.

---

### Modules

- `Integrations/IntegrationBus.lua`
- `Integrations/BlizzardKeys.lua`

---

### Dependencies

- S-01, S-02, S-04, S-05 complete

---

### Delivery Order

1. `Integrations/IntegrationBus.lua` — Report, GetStatus, GetAll. Emit INTEGRATION_HEALTH_CHANGED on state transitions. Initialize all sources to "unknown" on load.
2. `Integrations/BlizzardKeys.lua` — ReadLocalKey, GetOverallScore, GetCurrentWeekBestLevel, GetRunHistoryWeeklyBestLevel, GetCurrentWeek. Report to IntegrationBus on every call. Auto-read on PLAYER_LOGIN and CHALLENGE_MODE_COMPLETED.

---

### Acceptance Criteria

- [ ] `IntegrationBus.GetStatus("Blizzard")` returns "unknown" before any API call
- [ ] `IntegrationBus.Report("Blizzard", "ok", nil)` updates status to "ok"
- [ ] `IntegrationBus.Report("Blizzard", "degraded", "API returned nil")` updates status and errorMessage
- [ ] INTEGRATION_HEALTH_CHANGED emits when status changes from "ok" to "degraded"
- [ ] INTEGRATION_HEALTH_CHANGED does NOT emit when status is reported as the same value (no churn)
- [ ] `IntegrationBus.GetAll()` returns a record for every registered source
- [ ] `BlizzardKeys.ReadLocalKey()` returns a valid KeyRecord when player owns a keystone
- [ ] `BlizzardKeys.ReadLocalKey()` returns nil and reports "degraded" when player has no key
- [ ] `BlizzardKeys.GetOverallScore()` returns a number (may be 0)
- [ ] `BlizzardKeys.GetCurrentWeek()` returns a non-nil string or number
- [ ] On PLAYER_LOGIN, BlizzardKeys auto-reads and upserts to KeyStore
- [ ] Player's own key appears in `KeyStore.GetByView("party")` after login

---

### Testing Requirements

- Log into WoW with a keystone in bags; verify BlizzardKeys.ReadLocalKey returns correct dungeon and level
- Log in without a keystone; verify ReadLocalKey returns nil and IntegrationBus shows "degraded"
- Complete a Mythic+ run; verify CHALLENGE_MODE_COMPLETED triggers re-read
- Call Report with same status twice; verify INTEGRATION_HEALTH_CHANGED fires only once
- Call GetAll; verify every integration source is present

---

## S-09 — AstralKeys Integration

**Goal:**
Keys from AstralKeys (via SavedVariables import and guild channel listening) appear in KeyStore at the correct priority. Schema mismatches report health state, not silent failure.

---

### Modules

- `Integrations/AstralKeys.lua`

---

### Dependencies

- S-01, S-02, S-04, S-05, S-08 complete

---

### Delivery Order

1. `Integrations/AstralKeys.lua`
   - SavedVariables import path: probe one documented schema location. On success, upsert keys to KeyStore at priority AstralKeysSV (60). On schema mismatch, call `Logger.Warn` with expected schema version; report "degraded" to IntegrationBus.
   - Guild channel passive listener: register CHAT_MSG_ADDON for AstralKeys prefix. Decode sync6 format. Dedup by sender+key within 5 seconds. On unknown format, skip silently. On decode success, upsert to KeyStore at priority AstralBridge (55); report "ok".
   - On AstralKeys addon not loaded: report "offline".
   - Wire `ImportSavedVariables()` to the `/kc refresh` slash command in Bootstrap.
   - Expose `SUPPORTED_FORMATS` table.

---

### Acceptance Criteria

- [ ] `/kc refresh` triggers AstralKeys.ImportSavedVariables without error
- [ ] With AstralKeys installed and containing key data: import populates KeyStore with correct dungeon IDs and levels
- [ ] With AstralKeys not installed: `IntegrationBus.GetStatus("AstralKeysSV")` returns "offline"
- [ ] With AstralKeys installed but unknown schema: status returns "degraded" and Logger.Warn fires
- [ ] Guild channel sync6 message for a known key upserts to KeyStore at priority 55
- [ ] Guild channel message in unknown format is silently ignored — no error, no KeyStore mutation
- [ ] Duplicate sync6 messages from same sender for same key within 5 seconds are deduplicated
- [ ] Duplicate sync6 messages from same sender after 5 seconds are processed (dedup window expired)
- [ ] `AstralKeys.SUPPORTED_FORMATS` contains `"sync6"` and nothing else
- [ ] `AstralKeys.GetStatus()` returns the current IntegrationBus status for both sources

---

### Testing Requirements

- With AstralKeys installed: run `/kc refresh`; verify imported keys appear in KeyStore with source="AstralKeysSV"
- With AstralKeys not installed: run `/kc refresh`; verify "offline" status
- Manually construct a sync6 guild message and inject it; verify key appears in KeyStore with source="AstralBridge"
- Inject the same sync6 message twice within 2 seconds; verify only one KeyStore entry
- Inject same message again after 6 seconds; verify KeyStore entry is updated
- Construct a malformed guild message; verify no error and no KeyStore mutation

---

## S-10 — Decision Engines

**Goal:**
All five selection modes produce a valid ResultRecord. Every mode is independently callable. The result includes a human-readable rationale.

---

### Modules

- `Council/SpinEngine.lua`
- `Council/VoteEngine.lua`
- `Council/MajorityEngine.lua`
- `Council/SmartEngine.lua`
- `Council/ChaosMode.lua`
- `Council/ReadyCheck.lua`
- `Council/ResultExplainer.lua`
- `Council/Modes.lua`

---

### Dependencies

- S-01 through S-07 complete (all data, storage, and network layers)

---

### Delivery Order

1. `Council/SpinEngine.lua` — PickWeighted, GenerateSeed, BuildResult. Pure logic, no WoW API calls.
2. `Council/VoteEngine.lua` — Vote, GetWeights, GetVoteSummary. Reads from SessionStore and KeyStore.
3. `Council/MajorityEngine.lua` — GetWinner, GetVoteCounts. Tie-break via SpinEngine. Zero-vote fallback to spin.
4. `Council/SmartEngine.lua` — Score, GetScoreBreakdown. All signal math. Reads from KeyStore, HistoryStore, SeasonBest, BlizzardKeys.
5. `Council/ChaosMode.lua` — Assign, BroadcastAssignments, BuildResult. One key per player, minimize repeats.
6. `Council/ResultExplainer.lua` — Explain. Per-mode rationale strings for all five modes.
7. `Council/ReadyCheck.lua` — Start, GetReadyState, Cancel. 15-second timeout, emit READY_COMPLETE and READY_TIMEOUT.
8. `Council/Modes.lua` — Start, GetCandidateKeys, GetMode, SetMode, Cancel. Orchestrates all engines. Emits COUNCIL_RESULT. Post-result recording.

---

### Acceptance Criteria

**SpinEngine:**
- [ ] `SpinEngine.PickWeighted(keys, weights, seed)` always returns a key from the input list
- [ ] Same seed + same keys + same weights always returns the same key (deterministic)
- [ ] A key with weight 0 is never returned
- [ ] `SpinEngine.BuildResult(...)` returns a ResultRecord with all required fields non-nil

**VoteEngine:**
- [ ] `VoteEngine.Vote(keyID)` with a closed session does not register the vote
- [ ] `VoteEngine.Vote(keyID)` with a non-existent keyID does not register the vote
- [ ] `VoteEngine.GetWeights(keys)` returns base weight 1 for unvoted keys
- [ ] Each vote on a key adds 3 to its weight
- [ ] `VoteEngine.GetVoteSummary()` returns per-key vote counts

**MajorityEngine:**
- [ ] `MajorityEngine.GetWinner(keys)` with zero votes falls back to spin (all equal weights)
- [ ] `MajorityEngine.GetWinner(keys)` returns the key with the most votes
- [ ] On tie, GetWinner calls SpinEngine among tied keys and returns one deterministically

**SmartEngine:**
- [ ] `SmartEngine.Score(keys)` returns a weight for every input key
- [ ] `SmartEngine.GetScoreBreakdown(keys)` returns a breakdown for every key with no nil signal values
- [ ] A key in the last 3 selections has its weight multiplied by 0.65 (recentPenalty default)
- [ ] A key whose owner has the lowest score receives scoreGapBonus
- [ ] A key level above owner's weeklyBest receives vaultNeedBonus

**ChaosMode:**
- [ ] `ChaosMode.Assign(keys, 5 players)` with 5+ keys returns no duplicate keys per player
- [ ] `ChaosMode.Assign(keys, 5 players)` with 3 keys returns assignments for all 5 players (repeats minimized)
- [ ] BuildResult returns a result with assignments map populated

**ReadyCheck:**
- [ ] `ReadyCheck.Start()` emits no error when not in a group
- [ ] READY_COMPLETE fires when all party members ACK
- [ ] READY_TIMEOUT fires after 15 seconds with missing members; missing members treated as ready

**Modes:**
- [ ] `Modes.Start("spin")` with candidate keys produces a COUNCIL_RESULT event
- [ ] `Modes.Start("raffle")` opens a vote session via SessionStore
- [ ] `Modes.Start("majority")` opens a vote session via SessionStore
- [ ] `Modes.Start("smart")` produces a COUNCIL_RESULT event with Smart-scored weights
- [ ] `Modes.Start("chaos")` produces a COUNCIL_RESULT event with chaos assignments
- [ ] After COUNCIL_RESULT: HistoryStore, StatsStore, and SessionStore are all updated
- [ ] `Modes.GetCandidateKeys()` with no keys in KeyStore returns an empty list without error
- [ ] COUNCIL_RESULT result has a non-empty `rationale` field from ResultExplainer

**ResultExplainer:**
- [ ] Explain with mode="spin" returns a string containing "at random"
- [ ] Explain with mode="raffle" returns a string referencing vote count
- [ ] Explain with mode="majority" returns a string referencing "most votes"
- [ ] Explain with mode="smart" returns a string referencing at least one signal name
- [ ] Explain with mode="chaos" returns a string referencing "assignments"
- [ ] Explain never returns nil

---

### Testing Requirements

- Call SpinEngine.PickWeighted 100 times with the same seed and keys; verify same result every time
- Call SpinEngine.PickWeighted with a key having weight=0; verify it is never returned across 100 calls
- Start a raffle session, cast votes, close, call MajorityEngine.GetWinner; verify correct winner
- Craft a scenario where two keys tie; verify MajorityEngine still returns exactly one winner
- Score a set of keys with SmartEngine; verify a recently-selected key has lower weight than an unselected identical key
- Call Modes.Start for each of the 5 modes with 3 candidate keys; verify COUNCIL_RESULT fires for each
- Call ResultExplainer.Explain for all 5 modes; verify output is a non-empty string

---

## S-11 — Core UI

**Goal:**
The main window opens, displays keys, and closes. The minimap button works. Toasts display. The addon is usable for the first time by a real player.

---

### Modules

- `UI/MainFrame.lua`
- `UI/KeyList.lua`
- `UI/MinimapButton.lua`
- `UI/Toasts.lua`

---

### Dependencies

- S-01 through S-08 complete (all data layers must be populated)

---

### Delivery Order

1. `UI/Toasts.lua` — Show, queue management (max 5), auto-dismiss after 4 seconds, severity colors.
2. `UI/MinimapButton.lua` — Left click: MainFrame.Toggle. Right click: Settings.Show (stub until S-13). Draggable around minimap.
3. `UI/KeyList.lua` — Scrollable grid, columns (owner/dungeon/level/score/weekly/source), sort awareness, view filter, redraw on KEYS_CHANGED.
4. `UI/MainFrame.lua` — Root window, draggable/resizable, mode selector dropdown, action button (label-only for now), embed KeyList, subscribe to KEYS_CHANGED/SESSION_CHANGED/COUNCIL_RESULT.

---

### Acceptance Criteria

- [ ] `/kc` opens the main frame
- [ ] `/kc` again closes the main frame (toggle)
- [ ] MainFrame is draggable by the title bar
- [ ] MainFrame is resizable within bounds (620–940px wide, 330–760px tall)
- [ ] KeyList displays all keys currently in `KeyStore.GetAll()`
- [ ] KeyList updates immediately when a key is upserted to KeyStore
- [ ] KeyList shows owner name, dungeon name, level, score, weekly best, source for each row
- [ ] Mode selector dropdown contains spin, raffle, majority, smart, chaos
- [ ] Mode selector default is "spin"
- [ ] MinimapButton is visible when `profile.options.showMinimapButton = true`
- [ ] MinimapButton left click toggles MainFrame
- [ ] MinimapButton is draggable around the minimap perimeter
- [ ] `Toasts.Show("test message", "info")` displays a toast
- [ ] Toast auto-dismisses after 4 seconds
- [ ] Toast dismisses on click
- [ ] Sixth toast queued while 5 are displayed replaces the oldest

---

### Testing Requirements

- Open and close MainFrame 5 times rapidly; verify no frame errors
- Resize MainFrame to minimum and maximum dimensions; verify no content overflow
- Upsert 20 keys; verify KeyList scrolls and all rows are accessible
- Remove keys one at a time; verify KeyList updates on each removal
- Change sort mode via mode selector; verify KeyList re-sorts
- Queue 6 toasts; verify max 5 displayed; verify oldest dismissed
- Drag MinimapButton to 4 positions around minimap; verify it snaps correctly

---

## S-12 — Decision UI

**Goal:**
All decision flows are fully visible. Voting works. The winner is displayed. The spin animation plays. Streamer overlay is functional.

---

### Modules

- `UI/VotePanel.lua`
- `UI/ResultRenderer.lua`
- `UI/WinnerBanner.lua`
- `UI/StreamerOverlay.lua`
- `UI/Wheel.lua`

---

### Dependencies

- S-10 (Council layer), S-11 (Core UI) complete

---

### Delivery Order

1. `UI/ResultRenderer.lua` — RenderFull(parentFrame, result), RenderCompact(parentFrame, result). Accepts result struct; renders dungeon name, level, owner, mode, rationale. No frame creation.
2. `UI/Wheel.lua` — Spin(duration, onComplete), Stop. Animation plays during selection.
3. `UI/WinnerBanner.lua` — Show on COUNCIL_RESULT, render via ResultRenderer.RenderFull, auto-dismiss after 8 seconds, click to dismiss early.
4. `UI/VotePanel.lua` — Shows per-member vote choices and vote weight bars or counts. Redraws on SESSION_CHANGED.
5. `UI/StreamerOverlay.lua` — Toggle via `/kc streamer`. Compact key summary + ResultRenderer.RenderCompact. Lock position when not dragging.

---

### Acceptance Criteria

- [ ] Starting a raffle or majority session shows VotePanel in place of KeyList
- [ ] VotePanel shows each party member and their voted key (or "Not voted")
- [ ] Clicking a key in vote mode calls VoteEngine.Vote and updates VotePanel
- [ ] VotePanel updates immediately when a vote arrives from another party member
- [ ] Starting a spin triggers Wheel animation
- [ ] WinnerBanner appears after COUNCIL_RESULT with dungeon name, level, and owner visible
- [ ] WinnerBanner shows rationale text (from ResultExplainer)
- [ ] WinnerBanner auto-dismisses after 8 seconds
- [ ] WinnerBanner dismisses on click
- [ ] `/kc streamer` shows StreamerOverlay
- [ ] `/kc streamer` again hides StreamerOverlay
- [ ] StreamerOverlay updates when a new result is produced
- [ ] StreamerOverlay uses ResultRenderer.RenderCompact (no duplicate rendering code)
- [ ] WinnerBanner uses ResultRenderer.RenderFull (no duplicate rendering code)
- [ ] Both can display simultaneously without conflict

---

### Testing Requirements

- Start a raffle session alone (no party); verify VotePanel appears and shows player's name
- Vote on a key; verify vote is reflected in VotePanel immediately
- Start spin; verify Wheel animation plays; verify WinnerBanner shows after animation completes
- Verify WinnerBanner rationale differs between spin mode and smart mode results
- Enable StreamerOverlay; produce a result; verify compact result appears in overlay
- Verify WinnerBanner and StreamerOverlay can both be visible simultaneously

---

## S-13 — Support UI

**Goal:**
All secondary UI panels are complete. Users can inspect key details, check integration health, configure settings, view stats, and see sync peer status. TeleportButton works.

---

### Modules

- `UI/CandidateInspector.lua`
- `UI/IntegrationHealthPanel.lua`
- `UI/Settings.lua`
- `UI/StatsPanel.lua`
- `UI/PeerPanel.lua`
- `UI/TeleportButton.lua`
- `UI/DevPanel.lua`

---

### Dependencies

- S-10, S-11, S-12 complete

---

### Delivery Order

1. `UI/IntegrationHealthPanel.lua` — Render indicator per integration (Blizzard, AstralKeys, PartySync). Green/yellow/red. Tooltip. Refresh button. Embed in MainFrame top bar.
2. `UI/CandidateInspector.lua` — Show on key click in idle mode. All key metadata. Smart score breakdown (when mode=smart). "Why this key?" from ResultExplainer projected score.
3. `UI/Settings.lua` — All profile settings. Immediate write-through. Smart tuning sliders with labels. Key reporting toggles. Guild rank filter. Link to Diagnostics.
4. `UI/StatsPanel.lua` — Per-player and per-dungeon selection counts. Recent history list.
5. `UI/PeerPanel.lua` — Connected peers with version and last-seen. Version mismatch indicators.
6. `UI/TeleportButton.lua` — Show after result when portal available and not in combat. Click invokes portal.
7. `UI/DevPanel.lua` — Debug-gated. Fake key injection. IntegrationBus dump. Module status. Diagnostics export.

---

### Acceptance Criteria

- [ ] IntegrationHealthPanel shows at the top of MainFrame
- [ ] IntegrationHealthPanel shows green for Blizzard when ReadLocalKey succeeds
- [ ] IntegrationHealthPanel shows yellow for AstralKeys when schema mismatch is reported
- [ ] IntegrationHealthPanel shows red when a source reports "offline"
- [ ] Clicking the Refresh button in IntegrationHealthPanel triggers `/kc refresh`
- [ ] IntegrationHealthPanel updates in real time on INTEGRATION_HEALTH_CHANGED
- [ ] Clicking a key row in idle mode opens CandidateInspector
- [ ] CandidateInspector shows all key fields with no nil values displayed
- [ ] In smart mode, CandidateInspector shows the score breakdown per signal
- [ ] Settings panel shows all profile fields from Defaults.lua with no missing controls
- [ ] Changing a setting in Settings panel immediately updates the profile (no apply button)
- [ ] StatsPanel shows correct per-player and per-dungeon counts after 5 selections
- [ ] PeerPanel shows party members running KSC after BroadcastHello exchange
- [ ] PeerPanel highlights peers on incompatible protocol version
- [ ] TeleportButton is not visible when no result exists
- [ ] TeleportButton is not visible when in combat lockdown
- [ ] TeleportButton is visible after a result when a valid portal exists
- [ ] DevPanel is not visible when `profile.debug = false`
- [ ] DevPanel is visible when `profile.debug = true`
- [ ] DevPanel InjectFakeKeys populates KeyStore with test entries
- [ ] MinimapButton right-click now opens Settings (wired in this sprint)

---

### Testing Requirements

- Set IntegrationBus to each status for each source; verify panel colors update
- Click every key in KeyList; verify CandidateInspector opens without error
- Verify every Settings control maps to a profile field; change each; verify persistence after reload
- Record 10 selections; open StatsPanel; verify counts are accurate
- In a party with another KSC user: exchange HELLO; verify peer appears in PeerPanel
- After a result, move near a dungeon portal; verify TeleportButton appears
- Enable debug; open DevPanel; inject fake keys; verify they appear in KeyList

---

## S-14 — Release Candidate

**Goal:**
The addon is complete, clean, and passes all release criteria from the PRD. Migration from 0.9.x works. Diagnostics are fully operational. Dead code is removed. The .toc is final.

---

### Modules

- `Core/Diagnostics.lua` (complete rebuild)
- `Core/Quotes.lua` (trimmed)
- `Core/DevTools.lua` (finalized)
- `Core/Bootstrap.lua` (migration v4 added)
- `KeystoneCouncil.toc` (final audit)
- All deleted files removed

---

### Dependencies

- S-01 through S-13 complete

---

### Delivery Order

1. **Migration v4** — Add migration function to Bootstrap. Remove deprecated profile keys. Reset incomplete mode selections to "spin". Force-clear session vote state. Backfill `integrationVersion = "legacy"` on all existing ledger entries. Stamp `migrations["4"]`.
2. **File deletions** — Remove all files listed in Blueprint Section 10. Update .toc. Verify no remaining references in any Lua file.
3. **Diagnostics consolidation** — Rebuild `Core/Diagnostics.lua` with single `/kc diag` entry point and `--guild`, `--reset`, `--perf`, `--integrations` flags. All sub-checks from 0.9.x preserved; output format cleaned up.
4. **Quotes trim** — Reduce to 10 static generic quotes. Remove font-fitting logic. Remove guild-banter and rare-tier tables.
5. **DevTools finalize** — Remove any remaining password references. Confirm debug-flag gate is the only access control. Final review of all injected data shapes against current KeyRecord model.
6. **.toc final audit** — Verify load order matches blueprint folder structure. Confirm every file in .toc exists. Confirm no file exists on disk that is absent from .toc (except docs/). Confirm interface versions are current.
7. **PRD release criteria pass** — Walk through every item in PRD Section "Release Criteria" and confirm each passes.

---

### Acceptance Criteria

**Migration:**
- [ ] User on 0.9.x profile (v3) gets migrated to v4 on first load
- [ ] After migration, `profileVersion` is 4 and `migrations["4"]` is stamped
- [ ] Deprecated fields (`includeGuildMemeQuotes`, `countdownPrimaryAudio`, etc.) are absent after migration
- [ ] A profile with `mode = "majority"` (incomplete in 0.9.x) is reset to `"spin"` after migration
- [ ] `session.voteOpen` is false after migration regardless of prior state
- [ ] Existing ledger entries have `integrationVersion = "legacy"` after migration
- [ ] Users with no prior install (first-time) go directly to v4 without running earlier migrations

**File cleanliness:**
- [ ] No Lua file contains a reference to `DungeonRegistry`
- [ ] No Lua file contains a reference to `FileManifest`
- [ ] No Lua file contains a reference to `SharedKeyProvider`, `GroupKeyProvider`, `ExternalScoreProvider`, `CountdownProviderA`, `CountdownProviderB`
- [ ] No Lua file contains a reference to `ExternalKeyProvider` or `AstralBridge` (old module names)
- [ ] No Lua file contains `KC.Util` (split into Util/ directory)
- [ ] No Lua file contains a hardcoded password string
- [ ] All deleted files are absent from disk

**Diagnostics:**
- [ ] `/kc diag` runs the full health matrix and prints to chat
- [ ] `/kc diag --guild` includes guild roster audit output
- [ ] `/kc diag --reset` includes reset week validation output
- [ ] `/kc diag --perf` includes performance snapshot output
- [ ] `/kc diag --integrations` includes IntegrationBus health for all sources
- [ ] All prior 0.9.x diagnostic sub-commands (`/kc status`, `/kc modules`, `/kc readiness`, `/kc perf`, `/kc guildcheck`, `/kc resetcheck`, `/kc pipeline`) either route to `/kc diag` with appropriate flags or are cleanly removed
- [ ] `/kc export` produces a full diagnostic bundle suitable for copy-paste bug reports

**PRD Release Criteria (Functional):**
- [ ] Shared key discovery works: player, party, guild, AstralKeys keys all appear in KeyList
- [ ] Key browser works: sort by level, dungeon, owner, score, weekly, seen all function
- [ ] Spin Mode works: produces COUNCIL_RESULT with valid winner
- [ ] Raffle Mode works: vote session opens, votes recorded, weighted spin produces winner
- [ ] Majority Mode works: vote session opens, first-past-the-post winner selected
- [ ] Smart Mode works: multi-signal scoring produces winner with rationale
- [ ] Chaos Mode works: all party members receive assignments
- [ ] Result presentation works: WinnerBanner shows dungeon, level, owner, rationale
- [ ] Diagnostics work: `/kc diag` passes health matrix

**PRD Release Criteria (Reliability):**
- [ ] No critical startup errors on clean install
- [ ] No critical startup errors on upgrade from 0.9.x
- [ ] No persistent data corruption after 10 consecutive reload cycles
- [ ] No sync-breaking bugs with a 5-player party all running KSC 1.0
- [ ] No combat taint errors (`taint` logged) when opening/closing MainFrame from combat

**PRD Release Criteria (Usability):**
- [ ] A player who has never used KSC can open the addon, see keys, and complete a spin within 60 seconds without documentation
- [ ] The selected key is unambiguous to all party members after COUNCIL_RESULT
- [ ] All 5 modes are selectable and produce a result without a second action from the user

---

### Testing Requirements

- Fresh install (no SavedVariables): load addon; verify v4 profile created; verify all modes functional
- Upgrade from 0.9.x SavedVariables: load addon; verify migration v4 runs; verify no data loss for ledger, history, stats
- 10-reload stress test: produce 5 results; reload 10 times; verify SavedVariables consistent each time
- Full 5-player party test: all on KSC 1.0; complete one session of each mode; verify all players see the same result
- Combat taint test: enter combat; open and close MainFrame; verify no taint errors in combat log
- New-player usability test: hand addon to a player with no prior KSC experience; time them to first completed spin; target ≤60 seconds
- Grep codebase for all deleted module names; verify zero matches
- Final .toc audit: count files in .toc; count .lua files on disk (excluding docs/); verify counts match

---

## Completion Criteria

The implementation is complete when:

1. All sprints S-01 through S-14 pass their acceptance criteria
2. All PRD release criteria pass
3. The .toc references exactly the files in the blueprint folder structure
4. No deleted module is referenced anywhere in the codebase
5. `/kc diag` produces a clean health matrix with no failures
6. A 5-player party can complete all 5 modes in a single session without error

**Release candidate is cut after S-14 passes.**

---

*End of KSC 1.0 Implementation Plan*
*Next action: Begin S-01.*
