# KSC 1.0 Architecture Audit
**Keystone Council — v0.9.14-alpha**
**Audit Date:** 2026-06-11
**Auditor:** CTO, Keystone Council

---

## Table of Contents

1. [Current Systems Inventory](#1-current-systems-inventory)
2. [Current Module Inventory](#2-current-module-inventory)
3. [Current Data Flow](#3-current-data-flow)
4. [Current Network Flow](#4-current-network-flow)
5. [Current UI Flow](#5-current-ui-flow)
6. [Current Persistence Flow](#6-current-persistence-flow)
7. [Current External Integrations](#7-current-external-integrations)
8. [Current Technical Debt](#8-current-technical-debt)
9. [Systems to Keep](#9-systems-to-keep)
10. [Systems to Rebuild](#10-systems-to-rebuild)
11. [Systems to Delete](#11-systems-to-delete)
12. [Systems That Are Overengineered](#12-systems-that-are-overengineered)
13. [Systems That Are Underengineered](#13-systems-that-are-underengineered)
14. [KSC 1.0 Architecture Proposal](#14-ksc-10-architecture-proposal)

---

## 1. Current Systems Inventory

| System | Layer | Purpose | Status |
|--------|-------|---------|--------|
| **Bootstrap** | Core | Addon lifecycle entry point | Stable |
| **EventBus** | Core | Decoupled pub/sub dispatch | Stable |
| **Module Registry** | Core | Lifecycle management (init → enable) | Stable |
| **Logger** | Core | Chat output, debug, error tiers | Stable |
| **Constants** | Core | Global identifiers, color palette, event names | Stable |
| **Util** | Core | 500-line utility bag: social caching, name normalization, unit resolution | Stable, over-grown |
| **KeyReporter** | Core | Chat command responder for !keys | Stable |
| **Quotes** | Core | Flavor text display system | Stable |
| **Diagnostics** | Core | Health check, performance snapshot, export | Stable |
| **DevTools** | Core | Password-gated fake data injection | Stable |
| **DungeonRegistry** | Data | Hardcoded season dungeon map (ID → name) | Stable, brittle |
| **KeyStore** | Data | Live in-memory key cache with priority deduplication | Stable |
| **KeyLedger** | Data | Persistent SavedVariables key database | Stable |
| **SessionStore** | Data | Vote session state (open/closed, votes, token) | Stable |
| **HistoryStore** | Data | Last 50 key selections | Stable |
| **StatsStore** | Data | Aggregate selection counts by player and dungeon | Stable |
| **KC_SeasonBest** | Data | Per-dungeon personal best tracking | Stable |
| **Protocol** | Comm | Binary-adjacent message encoding/decoding | Stable |
| **PartySync** | Comm | Reliable party/raid broadcast with ACK + retry | Stable |
| **KeyNetwork** | Comm | Fire-and-forget guild broadcast | Stable |
| **BlizzardKeys** | Integration | Native WoW API wrapper | Stable |
| **ExternalKeyProvider** | Integration | AstralKeys SavedVariables importer | Fragile |
| **AstralBridge** | Integration | Guild channel AstralKeys listener/decoder | Fragile |
| **SharedKeyProvider** | Integration | LibKeystone broadcast receiver | Stub |
| **GroupKeyProvider** | Integration | OpenRaid-style broadcast receiver | Stub |
| **ExternalScoreProvider** | Integration | RaiderIO / external score enrichment | Stub |
| **CountdownProviderA/B** | Integration | Countdown audio triggers | Stub |
| **Modes** | Council | Mode orchestration (spin/raffle/majority/smart/chaos) | Stable |
| **VoteEngine** | Council | Raffle vote weighting | Stable |
| **SpinEngine** | Council | Weighted LCG random selection | Stable |
| **MajorityEngine** | Council | First-past-the-post selection | Partial |
| **SmartEngine** | Council | Multi-signal weighted scoring | Stable |
| **KC_ChaosMode** | Council | Random dungeon/key chaos assignment | Partial |
| **ReadyCheck** | Council | Pre-spin readiness gate | Partial |
| **MainFrame** | UI | Draggable/resizable root window | Stable |
| **KeyList** | UI | Scrollable key grid with sort | Stable |
| **VotePanel** | UI | Vote progress visualization | Stable |
| **CandidateInspector** | UI | Per-key detail overlay | Stable |
| **Settings** | UI | Options panel | Stable |
| **StatsPanel** | UI | Historical selection statistics | Stable |
| **PeerPanel** | UI | Party sync peer health display | Stable |
| **Wheel** | UI | Visual spinner animation | Stable |
| **StreamerOverlay** | UI | Floating minimal broadcast overlay | Stable |
| **WinnerBanner** | UI | Result announcement overlay | Stable |
| **Toasts** | UI | Transient notification system | Stable |
| **MinimapButton** | UI | Minimap icon launcher | Stable |
| **TeleportButton** | UI | Dungeon portal shortcut | Stable |
| **DevPanel** | UI | Developer dashboard | Stable |
| **KC_PortalActions** | UI | Portal interaction helper | Partial |

**Total:** 48 identified systems across 7 layers.

---

## 2. Current Module Inventory

### Core Layer (11 modules)
- `Bootstrap.lua` — Entry point, slash command routing, C_Timer tick loop
- `Constants.lua` — ADDON_NAME, VERSION, PROTOCOL_VERSION, COMM_PREFIX, event names, color palette
- `Logger.lua` — Print / Debug / Error with tier gating
- `Util.lua` — 500+ lines: name normalization, social cache (guild/friend/party), unit resolution, key enrichment, keystone link formatting
- `EventBus.lua` — Pub/sub: On(name, owner, fn), Emit(name, ...)
- `Module.lua` — Registry: Register, InitializeAll, EnableAll, status tracking
- `KeyReporter.lua` — !keys chat listener, throttled responder, announce-on-change
- `Quotes.lua` — Quote packs (generic/guild/rare), random selection, font scaling
- `Diagnostics.lua` — Health matrix, performance snapshot, export, guild/reset validation
- `DevTools.lua` — Password gate, fake data injection, test commands
- `FileManifest.lua` — Load order declaration (mirrors .toc)

### Config Layer (1 module)
- `Defaults.lua` — Profile v3 defaults: mode, scale, announce, sort, smart tuning, key reporting

### Data Layer (7 modules)
- `DungeonRegistry.lua` — Static season map: dungeonID → {name, shortName, mapID}
- `KeyStore.lua` — Live cache: Upsert, GetAll, GetByView, Normalize, DeduplicateByOwner, priority scoring
- `KeyLedger.lua` — Persistent DB: Record, GetAll, Cleanup, HydrateStore, stale detection, 500-row cap
- `SessionStore.lua` — Vote session: StartVoteSession, SetVote, SetVoteOpen, RecordSelection, closed-token replay protection
- `HistoryStore.lua` — Last 50 selections with timestamp
- `StatsStore.lua` — Player and dungeon aggregate counts
- `KC_SeasonBest.lua` — Personal season-best by dungeonID

### Comm Layer (3 modules)
- `Protocol.lua` — Encode/Decode: KEY, LEDGER, VOTE, VOTE_OPEN, HELLO, ACK, RESULT message types, 0x1F separator, 900-byte cap
- `PartySync.lua` — PARTY/RAID/INSTANCE reliable delivery: ACK counting, retry (2× @ 3s), 40-pending/10-failed caps
- `KeyNetwork.lua` — GUILD fire-and-forget with peer TTL (3600s)

### Integrations Layer (8 modules)
- `BlizzardKeys.lua` — C_MythicPlus, C_ChallengeMode wrapper: ReadLocalKey, GetOverallScore, GetCurrentWeekBestLevel, GetRunHistoryWeeklyBestLevel
- `ExternalKeyProvider.lua` — AstralKeys SavedVariables probe (5 fallback data structures)
- `AstralBridge.lua` — Guild channel decoder, 45 msg/min rate cap, bucket assignment
- `SharedKeyProvider.lua` — Stub
- `GroupKeyProvider.lua` — Stub
- `ExternalScoreProvider.lua` — Stub
- `CountdownProviderA.lua` — Stub
- `CountdownProviderB.lua` — Stub

### Council Layer (7 modules)
- `Modes.lua` — Mode orchestrator: GetCandidateKeys, Start, GetMode, emit COUNCIL_RESULT
- `VoteEngine.lua` — Weight +3 per vote, Vote(keyID) with validation
- `SpinEngine.lua` — LCG RNG (server time seed), PickWeighted, BuildResult
- `MajorityEngine.lua` — First-past-the-post (partial)
- `SmartEngine.lua` — Multi-signal scorer: base + scoreBonus + vaultBonus + seasonBestBonus + historyMultiplier + intentBonus
- `KC_ChaosMode.lua` — Random chaos assignments (partial)
- `ReadyCheck.lua` — Pre-spin gate (partial)

### UI Layer (15 modules)
- `MainFrame.lua` — Root window (620–940px × 330–760px), draggable/resizable, mode selector
- `KeyList.lua` — Scrollable grid: owner/dungeon/level/score/weekly/source columns, sort-aware
- `VotePanel.lua` — Vote progress, per-member vote display, weight bars
- `CandidateInspector.lua` — Per-key detail flyout
- `Settings.lua` — Options panel: all profile toggles and tuning sliders
- `StatsPanel.lua` — Historical stats table
- `PeerPanel.lua` — PartySync peer health display
- `Wheel.lua` — Animated spinner visual
- `StreamerOverlay.lua` — Minimal floating broadcast panel
- `WinnerBanner.lua` — Full-width result announcement
- `Toasts.lua` — Transient notification queue
- `MinimapButton.lua` — Minimap launcher icon
- `TeleportButton.lua` — Dungeon portal launcher
- `DevPanel.lua` — Dev dashboard (fake keys, status)
- `KC_PortalActions.lua` — Portal interaction helper (partial)

---

## 3. Current Data Flow

```
INGESTION
─────────────────────────────────────────────────────────
BlizzardKeys (priority 100)
  └─► KeyStore.Upsert(key, source="Blizzard")

PartySync.OnAddonMessage (priority 95)
  └─► Protocol.Decode(payload)
        ├─► KEY message  → KeyStore.Upsert + KeyLedger.Record
        └─► LEDGER message → KeyLedger bulk-record (shareLedger ON)

ExternalKeyProvider.Import (priority 60)
  └─► Probe AstralKeys SavedVariables
        └─► KeyStore.Upsert(key, source="ExternalKeyProvider")

AstralBridge.OnGuildMessage (priority 55)
  └─► Decode sync6 format
        └─► KeyStore.Upsert(key, source="AstralBridge")

KeyLedger.HydrateStore (on login)
  └─► KeyStore.Upsert(ledger entries, priority=92)

NORMALIZATION
─────────────────────────────────────────────────────────
KeyStore.Normalize(input)
  ├─► DungeonRegistry lookup (dungeonID → name)
  ├─► Util.EnrichKeyData (score, weeklyBest from live unit)
  ├─► Util.NormalizePlayerName (lowercase, trim)
  └─► Build id: "ownerGUID:dungeonID"

DEDUPLICATION
─────────────────────────────────────────────────────────
KeyStore.DeduplicateByOwner(keys)
  └─► Group by normalized ownerName
        └─► Score each entry: priority × freshness × realm-match bonus
              └─► Keep highest-scoring entry per owner

STORAGE
─────────────────────────────────────────────────────────
KeyStore (live)      → emits KEYS_CHANGED
KeyLedger (persist)  → writes KeystoneCouncilDB.global.keyLedger

SELECTION
─────────────────────────────────────────────────────────
Modes.Start()
  ├─► GetCandidateKeys() → KeyStore.GetByView("party")
  ├─► SessionStore.StartVoteSession(mode, token)    [if vote mode]
  ├─► VoteEngine.GetWeights(keys)                   [raffle: +3 per vote]
  ├─► SmartEngine.Score(keys)                       [smart: multi-signal]
  └─► SpinEngine.PickWeighted(keys, weights, seed)
        └─► BuildResult → emit COUNCIL_RESULT

POST-SELECTION
─────────────────────────────────────────────────────────
COUNCIL_RESULT
  ├─► SessionStore.RecordSelection(result)
  ├─► HistoryStore.Record(result)
  ├─► StatsStore.Record(result)
  └─► PartySync.BroadcastResult(result) [if announceWinnerToParty]
```

---

## 4. Current Network Flow

```
PROTOCOL LAYER
─────────────────────────────────────────────────────────
Prefix:    "KCNL"
Separator: 0x1F (unit separator character)
Max size:  900 bytes
Encoding:  pipe-delimited field strings

MESSAGE TYPES
─────────────────────────────────────────────────────────
TYPE     │ CHANNEL        │ DIRECTION   │ ACK  │ RETRY
─────────┼────────────────┼─────────────┼──────┼───────
KEY      │ PARTY/RAID/IN  │ Broadcast   │ Yes  │ 2×@3s
LEDGER   │ PARTY/RAID/IN  │ Broadcast   │ Yes  │ 2×@3s
VOTE     │ PARTY/RAID/IN  │ Broadcast   │ No   │ No
VOTE_OPEN│ PARTY/RAID/IN  │ Leader→All  │ No   │ No
HELLO    │ PARTY/RAID/IN  │ Broadcast   │ No   │ No
ACK      │ PARTY/RAID/IN  │ Broadcast   │ N/A  │ N/A
RESULT   │ PARTY/RAID/IN  │ Leader→All  │ No   │ No
KEY      │ GUILD          │ Broadcast   │ No   │ No
HELLO    │ GUILD          │ Broadcast   │ No   │ No

CHANNELS
─────────────────────────────────────────────────────────
PartySync  → PARTY / RAID / INSTANCE_CHAT
             Uses WoW SendAddonMessage API
             ACK reliability: pending queue (max 40), failed (max 10)
             Retry loop: C_Timer.After(3, ProcessRetries)

KeyNetwork → GUILD only
             Fire-and-forget
             Peer TTL: 3600 seconds

AstralBridge → GUILD (receive only)
               Listens for AstralKeys sync6 format messages
               Rate limit: 45 messages/minute

TOPOLOGY
─────────────────────────────────────────────────────────
Each client ─► PARTY channel (broadcast to group)
Leader ──────► RESULT / VOTE_OPEN messages
All ─────────► GUILD channel (KeyNetwork, AstralBridge receive)

No server-side component. All P2P via WoW addon messaging API.
```

---

## 5. Current UI Flow

```
ENTRY POINTS
─────────────────────────────────────────────────────────
/kc, /ksc, /key, /keys  → MainFrame.Toggle()
MinimapButton click      → MainFrame.Toggle()

MAIN FRAME STATES
─────────────────────────────────────────────────────────
IDLE (no vote session open)
  ├─► KeyList: displays all visible keys, sorted per setting
  ├─► Mode selector: spin / raffle / majority / smart / chaos
  ├─► Quote/subtitle ticker
  └─► [Spin / Start Vote] button

VOTING (session open)
  ├─► KeyList: keys are clickable vote targets
  ├─► VotePanel: vote counts, per-member vote display
  └─► [Close Vote / Force Spin] button (leader only)

RESULT
  ├─► WinnerBanner overlay (full-width, auto-dismisses)
  ├─► StatsPanel (optional, via tab)
  └─► Reset to IDLE

SECONDARY PANELS (via tabs or buttons)
  ├─► CandidateInspector  — flyout on key click (IDLE mode)
  ├─► Settings panel      — /kc settings
  ├─► StatsPanel          — historical stats
  ├─► PeerPanel           — sync peer health
  ├─► DevPanel            — dev tools (password-gated)
  └─► StreamerOverlay     — /kc streamer toggle

NOTIFICATIONS
  ├─► Toasts: transient overlays for sync events, errors
  ├─► WinnerBanner: result display
  └─► ChatFrame: Logger.Print for all announcements

MINIMAP
  └─► MinimapButton → left click: MainFrame.Toggle
                    → right click: settings or context menu

TELEPORT
  └─► TeleportButton → KC_PortalActions (invoke dungeon portal)
```

---

## 6. Current Persistence Flow

```
STORAGE LOCATION
─────────────────────────────────────────────────────────
WoW SavedVariables: KeystoneCouncilDB
  Stored in: WTF/Account/<acct>/SavedVariables/KeystoneCouncil.lua
  Scope: Per account (global table), not per character

STRUCTURE
─────────────────────────────────────────────────────────
KeystoneCouncilDB
  ├─► .profile         (user settings, version-migrated)
  ├─► .profileVersion  (integer, current = 3)
  ├─► .global
  │     ├─► .keyLedger  (max 500 entries, keyed by "ownerGUID:dungeonID")
  │     ├─► .history    (last 50 selections)
  │     ├─► .stats      (player/dungeon aggregate counts)
  │     ├─► .seasonBest (per-dungeonID personal bests)
  │     └─► .migrations (applied version stamps)
  └─► .session
        ├─► voteOpen, voteMode, voteToken
        ├─► closedVoteTokens (last 20, replay protection)
        └─► selections (last 50 per-session results)

WRITE EVENTS
─────────────────────────────────────────────────────────
KeyLedger.Record()       → writes on every new key upsert
StatsStore.Record()      → writes on every council result
HistoryStore.Record()    → writes on every council result
SessionStore.RecordSelection() → writes on every result
KC_SeasonBest            → writes when new dungeon best detected
Profile changes          → write-through on settings change
WoW shutdown             → WoW engine flushes to disk

READ EVENTS
─────────────────────────────────────────────────────────
Bootstrap (OnInitialize)
  └─► KeyLedger.HydrateStore()  → populates KeyStore from ledger
  └─► Migrations.Apply()        → upgrades profile schema

MIGRATION SYSTEM
─────────────────────────────────────────────────────────
v1 → v2: Source name renaming (3 providers)
v2 → v3: countdownAudio fields, smart mode defaults, score field rename

CLEANUP
─────────────────────────────────────────────────────────
/kc cleanup  → KeyLedger.Cleanup()
  ├─► Remove entries older than 8 days
  ├─► Remove entries from previous reset week
  ├─► Remove duplicate display names (keep freshest)
  └─► Enforce 500-row cap (drop oldest)
```

---

## 7. Current External Integrations

| Integration | Type | Mechanism | Reliability | Notes |
|-------------|------|-----------|-------------|-------|
| **Blizzard WoW API** | Native | C_MythicPlus, C_ChallengeMode, C_PlayerInfo | High | First-party, version-gated per .toc |
| **AstralKeys (SavedVariables)** | Import | Probe 5 fallback data structures in memory | Fragile | No contract; breaks on AstralKeys schema changes |
| **AstralKeys (Guild broadcast)** | Passive listen | Decode sync6 wire format from GUILD channel | Fragile | Undocumented protocol, reverse-engineered |
| **LibKeystone / BigWigs** | Request | Broadcast request via SharedKeyProvider | Stub | Not implemented |
| **OpenRaid / GroupKeyProvider** | Request | Broadcast request via GroupKeyProvider | Stub | Not implemented |
| **RaiderIO / ExternalScoreProvider** | Enrichment | Score overlay per player | Stub | Not implemented |
| **CountdownProviderA/B** | Audio | Countdown triggers | Stub | Not implemented |

**Risk summary:** Two of seven integrations are functional. Five are stubs. The two live integrations (AstralKeys) have no versioning contract and are reverse-engineered from observed behavior.

---

## 8. Current Technical Debt

### Critical Debt

**D1 — Util.lua God Object (500+ lines)**
A single file handles: social caching, name normalization, unit resolution, key enrichment, keystone link formatting, group leader detection, and more. No clear domain. Grows by accretion. Every module imports it.

**D2 — DungeonRegistry is Season-Hardcoded**
14 dungeons hardcoded by ID. Every WoW season requires a manual code edit. No mechanism to extend, override, or hot-patch. Will silently produce nil lookups for any new dungeon added mid-season.

**D3 — AstralKeys Integration is Reverse-Engineered**
Both `ExternalKeyProvider` and `AstralBridge` parse AstralKeys data via undocumented, unstable contracts. Five fallback probe paths exist precisely because the contract breaks. Any AstralKeys update can silently zero-out key discovery.

**D4 — Four Stub Modules Shipped to Alpha Users**
`SharedKeyProvider`, `GroupKeyProvider`, `ExternalScoreProvider`, `CountdownProviderA/B` are dead code. They occupy slots in the priority system, appear in diagnostics, and set user expectations that cannot be met.

**D5 — Dev Password Hardcoded in Source**
`"BlameChopper"` is plain text in `DevTools.lua`. While not a security vulnerability in a WoW addon context, it sets a bad precedent. Any user can unlock dev mode.

**D6 — MajorityEngine, ReadyCheck, KC_ChaosMode are Partial**
Three Council modules shipped in incomplete state. Selecting `majority` mode or `chaos` mode may produce undefined behavior or silent no-ops.

### Structural Debt

**D7 — Protocol Has No Versioning at the Field Level**
`PROTOCOL_VERSION = 2` is a single integer. Adding a field to any message type requires a version bump and backward-compat handling for every message type simultaneously, not just the one that changed.

**D8 — KeyStore Priority System Has No Documentation**
Numeric priorities (100, 95, 92, 90, 85, 60, 55, 10) are scattered across source files with no central registry. Adding a new source requires knowing the existing priority table by memory.

**D9 — Session State Spans SavedVariables Restart Boundary**
`KeystoneCouncilDB.session` persists across logout. Vote sessions can theoretically survive a reload and re-open in a stale state. Stale token protection (20 closed tokens) is the only defense.

**D10 — Social Cache Has No Invalidation on Roster Events**
Guild/friend caches use a 10-second TTL but are not invalidated by `GUILD_ROSTER_UPDATE` or `FRIENDLIST_UPDATE` events. A player who joins mid-session may not be recognized for up to 10 seconds.

**D11 — FileManifest.lua Duplicates the .toc File**
Both `KeystoneCouncil.toc` and `Core/FileManifest.lua` maintain load-order lists. They can diverge silently.

**D12 — No Automated Tests**
DevTools inject fake data manually. There is no repeatable test suite, no assertion framework, and no CI. All validation is manual diagnostics.

### Minor Debt

**D13 — Quotes System is Feature-Unrelated Complexity**
90+ quotes, font-fitting logic, guild-banter packs, and a rare-quote tier represent non-trivial code for zero-value functionality to a significant portion of users.

**D14 — WinnerBanner and StreamerOverlay Partially Overlap**
Both show result state. Responsibility boundary is unclear. StreamerOverlay appears to be a subset of WinnerBanner with no shared abstraction.

**D15 — Ledger Cleanup is Manual-Only**
`KeyLedger.Cleanup()` requires explicit `/kc cleanup` invocation. No automatic cleanup on login or weekly reset detection.

---

## 9. Systems to Keep

These systems are well-designed, stable, and core to the product.

| System | Rationale |
|--------|-----------|
| **EventBus** | Clean pub/sub, error-isolated callbacks, no WoW-specific coupling |
| **Module Registry** | Clear lifecycle, status tracking, extensible |
| **Constants** | Well-organized, single source of truth for identifiers |
| **KeyStore** | Priority deduplication model is correct and flexible |
| **KeyLedger** | Two-tier persistence (live + persistent) is the right design |
| **Protocol** | Compact encoding, sensible message types, separator is correct choice |
| **PartySync** | ACK/retry on party channel is the correct reliability model for WoW |
| **BlizzardKeys** | Correct abstraction over native APIs |
| **SpinEngine** | LCG seeded by server time is auditable and deterministic |
| **VoteEngine** | Simple, correct, transparent |
| **SmartEngine** | Multi-signal scoring is the product differentiator — keep the design |
| **SessionStore** | Closed-token replay protection is important; keep the concept |
| **Diagnostics** | Excellent for support and debugging; keep expanding |
| **MinimapButton** | Required UX convention for WoW addons |
| **MainFrame** | Root window structure is sound |
| **KeyList** | Core display widget, well-factored |

---

## 10. Systems to Rebuild

These systems have correct intent but flawed execution.

| System | Problem | Rebuild Goal |
|--------|---------|--------------|
| **Util.lua** | God object, no domain boundary | Split into: `Social.lua` (roster caching), `Names.lua` (normalization), `Keys.lua` (keystone link, enrichment), `Group.lua` (leader/role checks) |
| **DungeonRegistry** | Hardcoded season data | Replace with data-driven table loaded from a versioned config file; expose an override mechanism for season transitions |
| **ExternalKeyProvider** | 5-path brittle probe | Define a formal import contract; fail loudly with structured error on schema mismatch instead of silent fallback cascade |
| **AstralBridge** | Reverse-engineered wire format | Isolate decoding behind a versioned adapter; version-stamp each decode attempt; emit `INTEGRATION_DEGRADED` event on failure |
| **MajorityEngine** | Incomplete | Complete: first-past-the-post, tie-break by spin, clear winner announcement |
| **KC_ChaosMode** | Incomplete | Complete or remove from mode selector until complete |
| **ReadyCheck** | Incomplete | Complete: all-players-ready gate before spin, timeout fallback |
| **SessionStore** | Session survives reload boundary | Reset session on `PLAYER_LOGIN`; retain closed-token history but clear open vote state |
| **Settings UI** | Unclear (not fully audited) | Ensure all smart tuning sliders map 1:1 to documented Defaults; remove any orphaned toggles |
| **KeyLedger Cleanup** | Manual-only | Auto-cleanup on login and on weekly reset detection (`C_MythicPlus.GetCurrentWeek` change) |

---

## 11. Systems to Delete

These systems provide no value and add noise.

| System | Rationale |
|--------|-----------|
| **SharedKeyProvider** (stub) | Dead code. No LibKeystone contract exists. Remove or defer to a future integration sprint. |
| **GroupKeyProvider** (stub) | Dead code. OpenRaid is not an active ecosystem target. Remove. |
| **ExternalScoreProvider** (stub) | Dead code. Score enrichment should come from BlizzardKeys first, RaiderIO second if contracted. Remove the stub. |
| **CountdownProviderA** (stub) | Dead code. Remove. |
| **CountdownProviderB** (stub) | Dead code. Remove. |
| **FileManifest.lua** | Duplicate of .toc load order. Single source of truth should be the .toc. Remove FileManifest. |
| **DevTools password** | Remove the password gate entirely. Gate on `DEBUG` build flag or on `profile.debug = true`. |

---

## 12. Systems That Are Overengineered

| System | Overengineering Pattern |
|--------|------------------------|
| **KeyStore priority system** | 8 numeric priority tiers for 3 functional sources. The remaining 5 tiers serve stubs or legacy. Simplify to: Native (1), Peer (2), Ledger (3), External (4). |
| **AstralBridge rate limiter (45 msg/min)** | Rate limiting a passive listener that cannot control message rate is defensive but adds state. Simpler: deduplicate by sender+key composite within a 5-second window. |
| **Closed vote token cache (last 20)** | Token replay protection is correct, but 20 tokens across sessions is more than needed. Within a session, 5 is sufficient. Cross-session replay risk is negligible given token format includes timestamp. |
| **PartySync pending/failed caps (40/10)** | A party has at most 4 members. A pending queue of 40 messages is 10× overshoot. Cap at 10 pending, 5 failed. |
| **Quotes system** | 90+ quotes, font-fitting, guild-banter packs, rare tier (1% probability path) for flavor text. Non-trivial complexity for zero product value. A 10-quote static table is sufficient. |
| **Diagnostics export** | The full diagnostic dump is valuable. The `/kc guildcheck`, `/kc resetcheck`, `/kc pipeline`, `/kc perf` as separate commands adds slash-command surface area. Consolidate into `/kc diag [--guild] [--reset] [--perf]`. |

---

## 13. Systems That Are Underengineered

| System | Underengineering Pattern |
|--------|--------------------------|
| **DungeonRegistry** | No season abstraction, no override path, no unknown-ID handling. Will produce nil-crash or silent failure on any dungeon not in the hardcoded list. |
| **Error handling on COUNCIL_RESULT** | Result broadcast to party has no failure handling. If `BroadcastResult` fails, the group never sees the winner. Needs a local fallback display path. |
| **Integration health monitoring** | AstralKeys, BlizzardKeys, and protocol all have silent failure modes. No single dashboard surface tells a user "your external key source is not working." PeerPanel covers party sync but nothing covers integrations. |
| **Leader authority model** | VOTE_OPEN and RESULT messages are leader-only, but leadership is checked at send time only. No message authentication. A non-leader client can broadcast VOTE_OPEN and hijack a session. |
| **Session concurrency** | Two leaders in a split party (e.g., after group reform) can both broadcast VOTE_OPEN with different tokens. No conflict resolution exists. |
| **Smart mode explainability** | SmartEngine produces a numeric winner but no explanation visible to the group. Users cannot audit why a key was chosen. A "why this key?" display would reduce trust friction. |
| **Weekly reset detection** | Stale detection uses manual timestamp math against `C_MythicPlus.GetCurrentWeek()`. There is no event listener for the reset itself. Stale keys can persist until manual `/kc cleanup` or next login. |
| **Dungeon pool for Smart/Chaos modes** | Smart and Chaos modes have no concept of "current eligible dungeons." They operate on whatever keys are visible. A dungeon pool concept (forced set of eligible dungeons) would enable organized group play patterns. |

---

## 14. KSC 1.0 Architecture Proposal

### Vision

Keystone Council 1.0 is the first production-quality release. It is reliable, auditable, season-agnostic, and extensible. It ships only what works. It fails loudly where it cannot succeed silently.

---

### Guiding Principles

1. **Dead code ships as delete.** No stubs in production.
2. **Every integration has a health state.** Users know when data is stale or missing.
3. **Every decision is auditable.** Users can see why the Smart engine chose a key.
4. **Season data is data, not code.** Adding a new dungeon season requires no Lua change.
5. **Communication is bounded.** Party size is 5. All queue caps reflect that.
6. **Failure is local, not global.** One broken integration does not degrade others.

---

### Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│                        UI LAYER                         │
│  MainFrame · KeyList · VotePanel · WinnerBanner         │
│  CandidateInspector · Settings · StatsPanel             │
│  StreamerOverlay · MinimapButton · Toasts               │
│  IntegrationHealthPanel (NEW)                           │
└────────────────────┬────────────────────────────────────┘
                     │ KEYS_CHANGED · SESSION_CHANGED
                     │ COUNCIL_RESULT · HEALTH_CHANGED
┌────────────────────▼────────────────────────────────────┐
│                    COUNCIL LAYER                        │
│  Modes · VoteEngine · SpinEngine                        │
│  MajorityEngine (complete) · SmartEngine                │
│  ChaosMode (complete) · ReadyCheck (complete)           │
│  ResultExplainer (NEW)                                  │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│                     DATA LAYER                          │
│  KeyStore · KeyLedger · SessionStore                    │
│  HistoryStore · StatsStore · SeasonBest                 │
│  SeasonRegistry (rebuilt) · SourcePriorityMap (NEW)     │
└──────────┬──────────────────────────────────────────────┘
           │                         │
┌──────────▼──────────┐   ┌──────────▼──────────────────┐
│    COMM LAYER        │   │     INTEGRATION LAYER        │
│  Protocol (v3)       │   │  BlizzardKeys                │
│  PartySync           │   │  AstralKeys (versioned)      │
│  KeyNetwork          │   │  IntegrationBus (NEW)        │
└─────────────────────┘   └─────────────────────────────┘
           │                         │
┌──────────▼─────────────────────────▼───────────────────┐
│                      CORE LAYER                         │
│  Bootstrap · Constants · EventBus · Module              │
│  Logger · Social · Names · Keys · Group (split Util)    │
│  Diagnostics · DevTools · Quotes (trimmed)              │
└─────────────────────────────────────────────────────────┘
```

---

### Module Specification

#### Core Layer

**Bootstrap**
- No changes to lifecycle. Add: reset session state on `PLAYER_LOGIN`.

**Constants**
- Add: `INTEGRATION_HEALTH_CHANGED` event.
- Add: `SOURCE_PRIORITY` table (single authoritative registry of all source priorities).

**EventBus**
- No changes.

**Module Registry**
- No changes.

**Logger**
- Add `Warn` tier (yellow) between Debug and Error.

**Social** *(split from Util)*
- Owns: guild cache, friend cache, BNet account resolution, IsGuildMember, IsFriend, IsPartyMember, IsOwnerOnline.
- Listens: `GUILD_ROSTER_UPDATE`, `FRIENDLIST_UPDATE` → invalidate relevant cache immediately.
- TTL remains as secondary safety net only.

**Names** *(split from Util)*
- Owns: PlayerFullName, NormalizePlayerName, GetUnitFullName, FindUnitTokenByName.

**Keys** *(split from Util)*
- Owns: KeySignature, FormatKeystoneLink, EnrichKeyData, GetOwnedKey.

**Group** *(split from Util)*
- Owns: IsCurrentPlayerLeader, GetGroupSize, GetGroupMembers, GetGroupChannel.

**Diagnostics**
- Consolidate slash commands: `/kc diag` with optional `--guild`, `--reset`, `--perf`, `--integrations` flags.
- Add: integration health matrix to output.

**DevTools**
- Remove password gate. Gate on `profile.debug = true`.
- Retain fake data injection; remove password from source entirely.

**Quotes**
- Trim to 10-quote static table. Remove guild-banter pack. Remove rare tier. Remove font-fitting logic.

---

#### Data Layer

**SeasonRegistry** *(rebuilt from DungeonRegistry)*
- Data structure: `seasons/<seasonKey>.lua` files loaded by .toc per-season.
- Each season file: `{ seasonKey, name, dungeons = { {id, name, shortName, mapID}, ... } }`.
- Active season set by `Constants.ACTIVE_SEASON`.
- SeasonRegistry exposes: `GetDungeon(id)`, `GetAllDungeons()`, `GetCurrentSeason()`.
- Unknown dungeon IDs return a safe fallback `{id=id, name="Unknown Dungeon #"..id}` — no nil crash.
- Season transitions: add new season file, update `ACTIVE_SEASON`. Zero Lua logic changes.

**SourcePriorityMap** *(new)*
- Single table in Constants or Data layer: `{ Blizzard=100, PartySync=95, LedgerReplay=92, GroupKey=90, SharedKey=85, ExternalKey=60, AstralBridge=55, Dev=10 }`.
- All sources import from this table. No magic numbers scattered across files.

**KeyStore**
- No structural changes. Import priority from `SourcePriorityMap`.
- Reduce pending/failed caps to match real party size.

**KeyLedger**
- Add: auto-cleanup on `PLAYER_LOGIN` (after HydrateStore).
- Add: listen for weekly reset sentinel (compare stored `resetWeek` to current on login) and auto-prune stale entries on reset.

**SessionStore**
- On `PLAYER_LOGIN`: clear `voteOpen`, `voteMode`, `voteToken`. Retain `closedVoteTokens` (replay protection persists).
- Reduce `closedVoteTokens` cap from 20 to 8.

---

#### Comm Layer

**Protocol v3**
- Add per-message `fieldVersion` suffix so individual message types can evolve independently.
- Format: `TYPE | PROTOCOL_VERSION | FIELD_VERSION | fields...`
- Decoders must check `FIELD_VERSION` before parsing type-specific fields.
- Backward compat: unknown field version → decode known fields, ignore remainder.

**PartySync**
- Reduce pending cap: 10. Reduce failed cap: 5.
- No other structural changes.

**KeyNetwork**
- No changes.

---

#### Integration Layer

**IntegrationBus** *(new)*
- Central health state registry: `{ sourceName: { status="ok"|"degraded"|"offline", lastSeenAt, errorMessage } }`.
- Each integration reports health on every import attempt.
- Emits `INTEGRATION_HEALTH_CHANGED` on state transition.
- UI `IntegrationHealthPanel` subscribes to this event.

**BlizzardKeys**
- Register with IntegrationBus as source `"Blizzard"`.
- Report `status="ok"` on successful read, `"degraded"` on API nil returns.

**AstralKeys Integration** *(versioned adapter replacing ExternalKeyProvider + AstralBridge)*
- Consolidate two AstralKeys modules into one: `AstralKeys.lua`.
- Responsibilities: SavedVariables import (on `/kc refresh`), guild channel passive listener.
- Versioned decode: `AstralKeys.SUPPORTED_FORMATS = { "sync6" }`. On unknown format, log warn and skip. Do not probe 5 fallback structures. Require one known schema; fail loudly on mismatch.
- Register with IntegrationBus. Report `status="degraded"` on schema mismatch, `"offline"` if AstralKeys is not loaded.

**Remove:** SharedKeyProvider, GroupKeyProvider, ExternalScoreProvider, CountdownProviderA, CountdownProviderB.

---

#### Council Layer

**Modes**
- All five modes fully gated: `spin`, `raffle`, `majority`, `smart`, `chaos` must be complete before appearing in the mode selector.
- `majority` and `chaos` blocked from selector in 1.0 until their engines are complete.

**MajorityEngine** *(complete)*
- First-past-the-post: key with most votes wins.
- Tie-break: SpinEngine.PickWeighted among tied keys (equal weights).
- Minimum vote quorum: at least 1 vote required; fallback to spin if zero votes when closing.

**ChaosMode** *(complete)*
- Random dungeon assignment per player from the visible key pool.
- Each player gets a different dungeon if pool is large enough.
- If pool < group size, assign from pool with repetition.

**ReadyCheck** *(complete)*
- Broadcast `READY_REQUEST` to party before spin.
- Wait for `READY_ACK` from each member (15-second timeout).
- Absent after timeout = treated as ready (do not block indefinitely).
- Gate the spin behind full ready state.

**ResultExplainer** *(new)*
- After SmartEngine produces a winner, generate a human-readable rationale string.
- Example: "Ara-Kara +18 chosen: highest vault upgrade opportunity (+6) for Jaxen, who has the lowest M+ score in the group (+4)."
- Rationale included in RESULT broadcast and displayed in WinnerBanner.

---

#### UI Layer

**IntegrationHealthPanel** *(new)*
- A small status row in the main frame (or collapsible panel).
- Shows: Blizzard (green/yellow/red), AstralKeys (green/yellow/red), PartySync peers (N/M).
- Subscribes to `INTEGRATION_HEALTH_CHANGED` and updates in real time.
- One-click `/kc refresh` button.

**CandidateInspector**
- Add: "Why this key?" button visible when mode=smart. Shows ResultExplainer output for the hovered key's projected score contribution.

**WinnerBanner**
- Show ResultExplainer rationale below winner name (if smart mode).

**StreamerOverlay**
- Extract shared result-display logic into `ResultRenderer.lua`. Both WinnerBanner and StreamerOverlay use it. No duplicate state.

**DevPanel**
- Add: IntegrationBus health dump. Remove: password field.

---

### Data Model Changes (v3 → v4 Migration)

| Field | Change |
|-------|--------|
| `profile.debug` | Now gates DevTools (replaces password) |
| `profile.mode` | Remove `"majority"` and `"chaos"` from valid set until engines complete; migrate existing values to `"spin"` |
| `global.keyLedger` | Add `integrationVersion` field per entry (tracks which adapter version recorded it) |
| `session.voteOpen` | Force to `false` on migration (login resets session) |
| `migrations["4"]` | Stamp applied at first run of 1.0 |

---

### Season 1.0 File Layout

```
KeystoneCouncil/
├── KeystoneCouncil.toc
├── Core/
│   ├── Bootstrap.lua
│   ├── Constants.lua
│   ├── EventBus.lua
│   ├── Module.lua
│   ├── Logger.lua
│   ├── Social.lua          ← split from Util
│   ├── Names.lua           ← split from Util
│   ├── Keys.lua            ← split from Util
│   ├── Group.lua           ← split from Util
│   ├── Diagnostics.lua
│   ├── DevTools.lua
│   └── Quotes.lua
│
├── Config/
│   └── Defaults.lua
│
├── Seasons/
│   ├── Season_TWW2.lua     ← active season data
│   └── Season_TWW1.lua     ← historical (optional, for ledger display)
│
├── Data/
│   ├── SeasonRegistry.lua  ← rebuilt
│   ├── SourcePriorityMap.lua ← new
│   ├── KeyStore.lua
│   ├── KeyLedger.lua
│   ├── SessionStore.lua
│   ├── HistoryStore.lua
│   ├── StatsStore.lua
│   └── SeasonBest.lua
│
├── Comm/
│   ├── Protocol.lua        ← v3 field-level versioning
│   ├── PartySync.lua
│   └── KeyNetwork.lua
│
├── Integrations/
│   ├── IntegrationBus.lua  ← new
│   ├── BlizzardKeys.lua
│   └── AstralKeys.lua      ← consolidated adapter
│
├── Council/
│   ├── Modes.lua
│   ├── VoteEngine.lua
│   ├── SpinEngine.lua
│   ├── MajorityEngine.lua  ← complete
│   ├── SmartEngine.lua
│   ├── ChaosMode.lua       ← complete
│   ├── ReadyCheck.lua      ← complete
│   └── ResultExplainer.lua ← new
│
└── UI/
    ├── MainFrame.lua
    ├── KeyList.lua
    ├── VotePanel.lua
    ├── CandidateInspector.lua
    ├── Settings.lua
    ├── StatsPanel.lua
    ├── PeerPanel.lua
    ├── IntegrationHealthPanel.lua ← new
    ├── Wheel.lua
    ├── ResultRenderer.lua  ← new (shared result display)
    ├── StreamerOverlay.lua ← uses ResultRenderer
    ├── WinnerBanner.lua    ← uses ResultRenderer
    ├── Toasts.lua
    ├── MinimapButton.lua
    ├── TeleportButton.lua
    └── DevPanel.lua
```

**Total: 50 files. Down from 57 (7 deleted, 8 new, net -7 with better coverage).**

---

### Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| AstralKeys schema changes again | High | Medium | IntegrationBus health state makes degradation visible; single adapter isolates blast radius |
| New WoW season mid-development | Medium | Low | SeasonRegistry data files decouple dungeon data from code |
| Protocol v3 incompatible with pre-1.0 clients | High | Medium | Version gate: ignore messages with unknown protocol version; display peer incompatibility in PeerPanel |
| ReadyCheck blocking group when one player is AFK | Medium | Medium | 15-second timeout + "treat absent as ready" fallback |
| SmartEngine rationale is confusing or contested | Medium | Medium | ResultExplainer output is visible to all; keep math simple and documented |
| Session state corruption on hard reload | Low | Low | PLAYER_LOGIN session reset eliminates cross-session state inheritance |

---

### KSC 1.0 Definition of Done

- [ ] Zero stub modules in production build
- [ ] All five modes functional and selectable
- [ ] Integration health visible in UI
- [ ] Smart mode produces human-readable rationale
- [ ] SeasonRegistry data-driven; season transition requires no Lua change
- [ ] Protocol v3 field versioning in place
- [ ] Session resets cleanly on login
- [ ] Weekly reset auto-cleanup runs on login
- [ ] Social cache invalidated by WoW roster events
- [ ] Diagnostics consolidated to single command with flags
- [ ] DevTools gated by debug flag, not hardcoded password
- [ ] FileManifest.lua deleted
- [ ] All stub integrations deleted
- [ ] Migration v4 applied and tested

---

*End of Audit — Keystone Council v0.9.14-alpha → KSC 1.0*
