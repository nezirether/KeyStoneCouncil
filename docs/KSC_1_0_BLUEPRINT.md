# Keystone Council 1.0 — Engineering Blueprint

**Status:** Approved for Implementation
**Authority:** Architecture Audit (KSC_1_0_ARCHITECTURE_AUDIT.md) + PRD (KSC_1_0_PRD.md)
**Date:** 2026-06-11

---

## Table of Contents

1. [Folder Structure](#1-folder-structure)
2. [Module Boundaries](#2-module-boundaries)
3. [Data Models](#3-data-models)
4. [Network Architecture](#4-network-architecture)
5. [UI Architecture](#5-ui-architecture)
6. [Persistence Architecture](#6-persistence-architecture)
7. [Seasonal Content Architecture](#7-seasonal-content-architecture)
8. [Portal Architecture](#8-portal-architecture)
9. [Integration Architecture](#9-integration-architecture)
10. [Migration Plan from 0.9.x](#10-migration-plan-from-09x)
11. [Module Status Index](#11-module-status-index)

---

## 1. Folder Structure

```
KeystoneCouncil/
│
├── KeystoneCouncil.toc                  # Addon manifest and load order
│
├── docs/                                # Architecture and product documents
│   ├── KSC_1_0_ARCHITECTURE_AUDIT.md
│   ├── KSC_1_0_PRD.md
│   └── KSC_1_0_BLUEPRINT.md
│
├── Core/                                # Foundation — loaded first
│   ├── Constants.lua                    # Global identifiers, events, priorities
│   ├── EventBus.lua                     # Pub/sub dispatcher
│   ├── Module.lua                       # Lifecycle registry
│   ├── Logger.lua                       # Print / Warn / Debug / Error
│   ├── Bootstrap.lua                    # Addon entry point, slash commands
│   ├── Diagnostics.lua                  # Health checks, export
│   ├── DevTools.lua                     # Debug-gated fake data tools
│   └── Quotes.lua                       # Flavor text (trimmed)
│
├── Util/                                # Domain utilities — loaded after Core
│   ├── Names.lua                        # Name normalization and resolution
│   ├── Social.lua                       # Roster caches (guild/friend/party)
│   ├── Keys.lua                         # Keystone link formatting, enrichment
│   └── Group.lua                        # Group state, leader, channel resolution
│
├── Config/
│   └── Defaults.lua                     # Profile v4 defaults
│
├── Seasons/                             # Season data files — loaded by .toc
│   ├── Season_TWW1.lua                  # The War Within Season 1 (historical)
│   └── Season_TWW2.lua                  # The War Within Season 2 (active)
│
├── Data/                                # Storage layer
│   ├── SeasonRegistry.lua               # Season-aware dungeon lookup
│   ├── SourcePriorityMap.lua            # Canonical source priority table
│   ├── KeyStore.lua                     # Live in-memory key cache
│   ├── KeyLedger.lua                    # Persistent key database
│   ├── SessionStore.lua                 # Active vote session state
│   ├── HistoryStore.lua                 # Past 50 selection records
│   ├── StatsStore.lua                   # Aggregate selection counts
│   └── SeasonBest.lua                   # Personal dungeon bests
│
├── Comm/                                # Network layer
│   ├── Protocol.lua                     # Message encoding/decoding (v3)
│   ├── PartySync.lua                    # Reliable party/raid broadcast
│   └── KeyNetwork.lua                   # Guild fire-and-forget broadcast
│
├── Integrations/                        # External data sources
│   ├── IntegrationBus.lua               # Health state registry
│   ├── BlizzardKeys.lua                 # Native WoW API wrapper
│   └── AstralKeys.lua                   # AstralKeys consolidated adapter
│
├── Council/                             # Decision engines
│   ├── Modes.lua                        # Orchestrator — entry point for all modes
│   ├── VoteEngine.lua                   # Raffle vote weighting
│   ├── SpinEngine.lua                   # Weighted LCG random selection
│   ├── MajorityEngine.lua               # First-past-the-post
│   ├── SmartEngine.lua                  # Multi-signal scorer
│   ├── ChaosMode.lua                    # Random chaos assignments
│   ├── ReadyCheck.lua                   # Pre-spin readiness gate
│   └── ResultExplainer.lua              # Human-readable result rationale
│
└── UI/                                  # Presentation layer
    ├── MainFrame.lua                    # Root window
    ├── KeyList.lua                      # Scrollable key grid
    ├── VotePanel.lua                    # Vote progress display
    ├── CandidateInspector.lua           # Per-key detail flyout
    ├── ResultRenderer.lua               # Shared result display component
    ├── WinnerBanner.lua                 # Full result overlay (uses ResultRenderer)
    ├── StreamerOverlay.lua              # Minimal broadcast overlay (uses ResultRenderer)
    ├── IntegrationHealthPanel.lua       # Source health status row
    ├── Settings.lua                     # Options panel
    ├── StatsPanel.lua                   # Historical stats
    ├── PeerPanel.lua                    # Sync peer health
    ├── Wheel.lua                        # Spinner animation
    ├── Toasts.lua                       # Transient notifications
    ├── MinimapButton.lua                # Minimap icon
    ├── TeleportButton.lua               # Portal launcher
    └── DevPanel.lua                     # Developer tools UI
```

**Load order in .toc:**
Core → Util → Config → Seasons → Data → Comm → Integrations → Council → UI

**Files removed from 0.9.x:**
- `Core/FileManifest.lua` — deleted (duplicate of .toc)
- `Data/DungeonRegistry.lua` — replaced by SeasonRegistry + Seasons/
- `Integrations/ExternalKeyProvider.lua` — merged into AstralKeys.lua
- `Integrations/AstralBridge.lua` — merged into AstralKeys.lua
- `Integrations/SharedKeyProvider.lua` — deleted (stub)
- `Integrations/GroupKeyProvider.lua` — deleted (stub)
- `Integrations/ExternalScoreProvider.lua` — deleted (stub)
- `Integrations/CountdownProviderA.lua` — deleted (stub)
- `Integrations/CountdownProviderB.lua` — deleted (stub)
- `Core/Util.lua` — split into Util/Names.lua, Util/Social.lua, Util/Keys.lua, Util/Group.lua
- `UI/KC_PortalActions.lua` — renamed to UI/TeleportButton.lua (unified)

---

## 2. Module Boundaries

### Layer Rules

- **Core** has no dependencies on any other layer.
- **Util** depends on Core only.
- **Config** depends on Core only.
- **Seasons** depends on nothing (pure data tables).
- **Data** depends on Core, Util, Config, Seasons.
- **Comm** depends on Core, Util, Data.
- **Integrations** depends on Core, Util, Data, Comm.
- **Council** depends on Core, Util, Data, Integrations.
- **UI** depends on all layers. UI never writes to Data directly — it calls Council or emits events.

Violations of these rules are build errors. No circular dependencies.

---

### Core Layer

---

#### `Core/Constants.lua`

**Purpose:**
Single source of truth for all global identifiers. No logic. No state.

**Responsibilities:**
- Define `KC.ADDON_NAME`, `KC.VERSION`, `KC.PROTOCOL_VERSION`, `KC.FIELD_VERSION`
- Define `KC.COMM_PREFIX`
- Define all event name constants
- Define `KC.COLORS` palette
- Define `KC.MODES` enum: spin, raffle, majority, smart, chaos
- Define `KC.SOURCE_PRIORITY` table (replaces scattered magic numbers)

**Dependencies:** None.

**Public API:**
```
KC.ADDON_NAME         string
KC.VERSION            string
KC.PROTOCOL_VERSION   number  -- wire protocol version
KC.FIELD_VERSION      table   -- { KEY=1, LEDGER=1, VOTE=1, HELLO=1, ACK=1, RESULT=1 }
KC.COMM_PREFIX        string
KC.EVENTS             table   -- all event name constants
KC.COLORS             table   -- color palette
KC.MODES              table   -- valid mode identifiers
KC.SOURCE_PRIORITY    table   -- { Blizzard=100, PartySync=95, ... }
```

---

#### `Core/EventBus.lua`

**Purpose:**
Decoupled pub/sub event dispatcher. Modules communicate through events, not direct calls.

**Responsibilities:**
- Register listeners per named event
- Emit events with arbitrary arguments
- Isolate listener errors (pcall per callback; one failure does not cancel others)
- No WoW event coupling — this is an internal bus only

**Dependencies:** Core/Constants.lua (event name validation, optional)

**Public API:**
```
KC.EventBus.On(eventName, owner, callback)
KC.EventBus.Emit(eventName, ...)
KC.EventBus.Off(eventName, owner)
```

---

#### `Core/Module.lua`

**Purpose:**
Lifecycle registry for all addon modules. Manages initialization and enable ordering.

**Responsibilities:**
- Accept module registrations with optional explicit ordering
- Call `OnInitialize` on all modules after SavedVariables are loaded
- Call `OnEnable` on all modules after initialization completes
- Track module status: registered → initialized → enabled → error
- Expose module health for Diagnostics

**Dependencies:** Core/EventBus.lua, Core/Logger.lua

**Public API:**
```
KC.Module.Register(name, module)
KC.Module.InitializeAll()
KC.Module.EnableAll()
KC.Module.GetStatus(name)       -- "registered"|"initialized"|"enabled"|"error"
KC.Module.GetAll()              -- { name: status }
```

---

#### `Core/Logger.lua`

**Purpose:**
Structured chat output with tier filtering.

**Responsibilities:**
- Print: always visible, white text
- Warn: always visible, yellow text
- Debug: only when `profile.debug = true`, gray text
- Error: always visible, red text
- Prefix all output with addon name tag

**Dependencies:** Core/Constants.lua

**Public API:**
```
KC.Logger.Print(message)
KC.Logger.Warn(message)
KC.Logger.Debug(message)
KC.Logger.Error(message)
```

---

#### `Core/Bootstrap.lua`

**Purpose:**
Addon entry point. Owns the WoW frame lifecycle, slash command routing, and the main tick loop.

**Responsibilities:**
- Register `ADDON_LOADED` frame event
- On load: initialize SavedVariables, apply migrations, call `Module.InitializeAll()`, then `Module.EnableAll()`
- On `PLAYER_LOGIN`: reset session state, trigger social cache warm-up, call `KeyLedger.AutoCleanup()`
- Register all slash commands: `/kc`, `/ksc`, `/key`, `/keys`
- Route slash commands to the correct handler
- Run C_Timer tick loop for PartySync retry processing

**Dependencies:** Core/Module.lua, Core/Logger.lua, Core/Constants.lua

**Public API:**
None. Bootstrap owns the WoW frame; other modules do not call it.

---

#### `Core/Diagnostics.lua`

**Purpose:**
Unified health check, status reporting, and diagnostic export.

**Responsibilities:**
- `PrintReadiness()` — pass/warn/fail matrix for all systems
- `PrintStatus()` — module statuses, memory, pending sync counts
- `PrintIntegrations()` — IntegrationBus health states
- `PrintGuildValidation()` — roster audit, duplicate owners, realm variants
- `PrintResetValidation()` — stale entry detection
- `PrintPerformanceSnapshot()` — memory usage, queue depths
- `BuildReport()` — full diagnostic bundle as string
- `Export()` — prints full report to chat for copy-paste
- Accept `--guild`, `--reset`, `--perf`, `--integrations` flags to filter output

**Dependencies:** Core/Module.lua, Core/Logger.lua, Data/KeyStore.lua, Data/KeyLedger.lua, Comm/PartySync.lua, Integrations/IntegrationBus.lua

**Public API:**
```
KC.Diagnostics.Run(flags)       -- flags: table of filter strings
KC.Diagnostics.Export()
KC.Diagnostics.BuildReport()    -- returns string
```

---

#### `Core/DevTools.lua`

**Purpose:**
Developer utilities for testing, gated behind `profile.debug = true`. Not present in non-debug sessions.

**Responsibilities:**
- Inject fake party keys (5 entries)
- Inject fake ledger keys (6 entries)
- Inject stale keys for cleanup testing
- Clear all injected keys
- No password. Active only when `profile.debug = true`.

**Dependencies:** Core/Constants.lua, Data/KeyStore.lua, Data/KeyLedger.lua, Core/Logger.lua

**Public API:**
```
KC.DevTools.InjectFakeKeys()
KC.DevTools.InjectLedgerKeys()
KC.DevTools.InjectStaleKeys()
KC.DevTools.ClearDevKeys()
```

---

#### `Core/Quotes.lua`

**Purpose:**
Flavor text display for the main frame subtitle. Non-functional; purely cosmetic.

**Responsibilities:**
- Maintain a static table of 10 generic quotes
- Return a random quote on demand
- No guild-banter pack. No rare tier. No font-fitting logic.

**Dependencies:** None.

**Public API:**
```
KC.Quotes.GetRandom()    -- returns string
```

---

### Util Layer

---

#### `Util/Names.lua`

**Purpose:**
All player name normalization, formatting, and unit resolution.

**Responsibilities:**
- `PlayerFullName()` — returns "Name-Realm" for the local player
- `NormalizePlayerName(name)` — lowercase, trim, remove spaces
- `GetUnitFullName(unit)` — resolve WoW unit token to "Name-Realm"
- `FindUnitTokenByName(name)` — search party1-5, raid1-40 for a name match
- `SplitFullName(fullName)` — returns name, realm as separate values
- `IsSamePlayer(a, b)` — compares two name strings across realm variants

**Dependencies:** Core/Constants.lua

**Public API:**
```
KC.Names.PlayerFullName()
KC.Names.NormalizePlayerName(name)
KC.Names.GetUnitFullName(unit)
KC.Names.FindUnitTokenByName(name)
KC.Names.SplitFullName(fullName)
KC.Names.IsSamePlayer(a, b)
```

---

#### `Util/Social.lua`

**Purpose:**
Roster membership caches. Answers "is this player in my guild / friend list / party?"

**Responsibilities:**
- Maintain guild roster cache with immediate invalidation on `GUILD_ROSTER_UPDATE`
- Maintain friend cache (including BNet) with immediate invalidation on `FRIENDLIST_UPDATE`
- TTL (10 seconds) as a secondary safety net only — roster events are primary invalidation
- `RebuildGuildCache(force)` — force rebuild ignoring TTL
- `RebuildFriendCache(force)`
- `IsGuildMember(nameOrGUID)`
- `IsFriend(nameOrGUID)`
- `IsPartyMember(nameOrGUID)`
- `IsOwnerOnline(key)` — checks all three rosters
- `GetGuildRank(nameOrGUID)` — returns rank name or nil
- Expose cache for filtering by guild rank

**Dependencies:** Core/EventBus.lua, Util/Names.lua

**Public API:**
```
KC.Social.IsGuildMember(nameOrGUID)
KC.Social.IsFriend(nameOrGUID)
KC.Social.IsPartyMember(nameOrGUID)
KC.Social.IsOwnerOnline(key)
KC.Social.GetGuildRank(nameOrGUID)
KC.Social.RebuildGuildCache(force)
KC.Social.RebuildFriendCache(force)
```

---

#### `Util/Keys.lua`

**Purpose:**
Keystone-specific utility functions. Enrichment, linking, and signature generation.

**Responsibilities:**
- `KeySignature(key)` — returns `"ownerGUID:dungeonID"` as canonical ID
- `FormatKeystoneLink(key)` — returns WoW `|Hkeystone:...|` hyperlink string
- `EnrichKeyData(key)` — populates score, weeklyBest from live unit data if available
- `GetOwnedKey()` — delegates to BlizzardKeys.ReadLocalKey()
- `GetUnitMythicPlusScore(unit)` — C_PlayerInfo wrapper
- `GetUnitMythicPlusWeeklyBest(unit, mapID)` — parse summary runs

**Dependencies:** Core/Constants.lua, Util/Names.lua, Integrations/BlizzardKeys.lua

**Public API:**
```
KC.Keys.KeySignature(key)
KC.Keys.FormatKeystoneLink(key)
KC.Keys.EnrichKeyData(key)
KC.Keys.GetOwnedKey()
KC.Keys.GetUnitMythicPlusScore(unit)
KC.Keys.GetUnitMythicPlusWeeklyBest(unit, mapID)
```

---

#### `Util/Group.lua`

**Purpose:**
Group state resolution. Answers questions about the current group structure.

**Responsibilities:**
- `IsCurrentPlayerLeader()` — UnitIsGroupLeader("player")
- `GetGroupSize()` — returns 1 (solo), 2–5 (party), 6–40 (raid)
- `GetGroupMembers()` — returns list of unit tokens for current group
- `GetGroupChannel()` — returns "PARTY", "RAID", or "INSTANCE_CHAT" for current context
- `IsInInstance()` — whether player is inside an instance

**Dependencies:** Core/Constants.lua

**Public API:**
```
KC.Group.IsCurrentPlayerLeader()
KC.Group.GetGroupSize()
KC.Group.GetGroupMembers()
KC.Group.GetGroupChannel()
KC.Group.IsInInstance()
```

---

### Config Layer

---

#### `Config/Defaults.lua`

**Purpose:**
Canonical default values for profile version 4. Single source of truth for all settings.

**Responsibilities:**
- Define `KC.Defaults.PROFILE_VERSION = 4`
- Define default profile table with all fields documented inline
- Define default global table structure
- No logic — data only

**Dependencies:** Core/Constants.lua

**Public API:**
```
KC.Defaults.PROFILE_VERSION    number
KC.Defaults.Profile            table   -- default profile settings
KC.Defaults.Global             table   -- default global structure
```

**Profile v4 fields:**

```
profile = {
  debug = false,
  mode = "spin",                       -- spin|raffle|majority|smart|chaos
  scale = 1.0,                         -- 0.75–1.4
  streamerMode = false,
  announce = true,
  announceChannel = "PARTY",           -- PARTY|RAID|AUTO
  announceSelf = true,
  announceWinnerToParty = true,

  options = {
    showMinimapButton = true,
    syncFriends = true,
    showOfflinePlayers = true,
    displayOfflineBelowOnline = true,
    showCurrentKeyTooltip = true,
    showOtherFaction = true,
    shareLedger = true,
    keySortMode = "level",             -- level|dungeon|owner|score|weekly|seen
    guildRankFilter = {},
  },

  keyReporting = {
    chatCommand = "!keys",
    announceNewKeyGuild = true,
    announceNewKeyParty = true,
    respondGuild = true,
    respondParty = true,
    respondRaid = true,
    respondInstance = true,
    respondSay = true,
    includeNoKey = true,
    respondAllVisibleKeys = false,
  },

  smart = {
    preferUntimed = true,
    preferLowestScore = true,
    preferVaultNeeds = true,
    recentPenalty = 0.65,
    scoreGapBonus = 4,
    vaultNeedBonus = 6,
    seasonBestBonus = 3,
    duplicateDungeonPenalty = 0.75,
    intent = "balanced",               -- balanced|farm|push
  },

  -- REMOVED from 0.9.x:
  -- useExternalScores (no ExternalScoreProvider in 1.0)
  -- includeGuildMemeQuotes (no guild banter pack in 1.0)
  -- includeRareQuotes (no rare quote tier in 1.0)
  -- countdownPrimaryAudio / countdownSecondaryAudio (no CountdownProviders in 1.0)
}
```

---

### Seasons Layer

---

#### `Seasons/Season_TWW2.lua` (active)

**Purpose:**
Data file for The War Within Season 2. No logic.

**Responsibilities:**
- Define season identifier
- Define dungeon list with all required fields per dungeon

**Dependencies:** None.

**Structure:**
```
KC.SeasonData["TWW2"] = {
  key = "TWW2",
  name = "The War Within Season 2",
  dungeons = {
    { id=499, name="Priory of the Sacred Flame",  shortName="PRIORY",   mapID=2669 },
    { id=500, name="The Rookery",                 shortName="ROOKERY",  mapID=2773 },
    { id=501, name="The Stonevault",              shortName="SV",       mapID=2648 },
    { id=502, name="City of Threads",             shortName="COT",      mapID=2773 },
    { id=503, name="Ara-Kara, City of Echoes",    shortName="AK",       mapID=2530 },
    { id=504, name="Darkflame Cleft",             shortName="DFC",      mapID=2651 },
    { id=505, name="The Dawnbreaker",             shortName="DB",       mapID=2662 },
    { id=506, name="Cinderbrew Meadery",          shortName="CBM",      mapID=2652 },
    { id=507, name="Grim Batol",                  shortName="GB",       mapID=669  },
    { id=508, name="Siege of Boralus",            shortName="SOB",      mapID=1170 },
    { id=509, name="Mists of Tirna Scithe",       shortName="MOTS",     mapID=2290 },
    { id=510, name="The Necrotic Wake",           shortName="NW",       mapID=2289 },
    { id=511, name="Operation: Floodgate",        shortName="FLOOD",    mapID=2773 },
    { id=512, name="Theater of Pain",             shortName="TOP",      mapID=2284 },
  }
}
```

#### `Seasons/Season_TWW1.lua` (historical, optional)

Same structure as TWW2. Used only for displaying historical ledger entries with correct dungeon names. Not required for 1.0 release; include if historical ledger display is desired.

---

### Data Layer

---

#### `Data/SeasonRegistry.lua`

**Purpose:**
Season-aware dungeon lookup. Replaces hardcoded DungeonRegistry.

**Responsibilities:**
- Load active season from `KC.ACTIVE_SEASON` (set in Constants)
- Build indexed lookup tables from loaded `KC.SeasonData` tables
- `GetDungeon(id)` — returns dungeon record or safe fallback (never nil)
- `GetAllDungeons()` — returns all dungeons in active season
- `GetCurrentSeason()` — returns current season record
- `GetDungeonFromSeason(id, seasonKey)` — cross-season lookup for ledger display
- Safe fallback: `{ id=id, name="Dungeon #"..id, shortName="???", mapID=0 }`

**Dependencies:** Core/Constants.lua, Seasons/*.lua (data only)

**Public API:**
```
KC.SeasonRegistry.GetDungeon(id)
KC.SeasonRegistry.GetAllDungeons()
KC.SeasonRegistry.GetCurrentSeason()
KC.SeasonRegistry.GetDungeonFromSeason(id, seasonKey)
```

---

#### `Data/SourcePriorityMap.lua`

**Purpose:**
Single authoritative table of all key source priorities. No magic numbers anywhere else in the codebase.

**Responsibilities:**
- Define numeric priority for every recognized source
- Expose lookup by source name

**Dependencies:** None.

**Public API:**
```
KC.SourcePriority = {
  Blizzard        = 100,
  PartySync       = 95,
  LedgerReplay    = 92,
  AstralKeysSV    = 60,   -- SavedVariables import
  AstralBridge    = 55,   -- Guild channel passive
  Dev             = 10,
}
KC.SourcePriority.Get(sourceName)    -- returns number or 0
```

---

#### `Data/KeyStore.lua`

**Purpose:**
Live in-memory key cache. Authoritative source for all UI rendering and Council decisions.

**Responsibilities:**
- Accept key upserts from all sources with priority scoring
- Deduplicate by owner (highest priority + freshest wins per owner)
- Normalize all incoming keys through SeasonRegistry and Util/Keys
- Sort on every upsert per current `profile.options.keySortMode`
- Filter by view: `"party"`, `"guild"`, `"friends"`, `"all"`
- Apply offline-player filter per profile settings
- Emit `KC.EVENTS.KEYS_CHANGED` after every mutation
- Expose read-only access — no writes from UI

**Dependencies:** Core/Constants.lua, Core/EventBus.lua, Data/SourcePriorityMap.lua, Data/SeasonRegistry.lua, Util/Names.lua, Util/Social.lua, Util/Keys.lua

**Public API:**
```
KC.KeyStore.Upsert(keyData, source)
KC.KeyStore.Remove(keyID)
KC.KeyStore.GetAll()
KC.KeyStore.GetByView(view)         -- "party"|"guild"|"friends"|"all"
KC.KeyStore.GetByID(keyID)
KC.KeyStore.Clear(source)           -- clear all keys from one source
KC.KeyStore.Normalize(input)
KC.KeyStore.DeduplicateByOwner(keys)
KC.KeyStore.Count()
```

---

#### `Data/KeyLedger.lua`

**Purpose:**
Persistent key database. Records every seen key across sessions. Used to hydrate KeyStore on login and to provide historical context.

**Responsibilities:**
- Record incoming keys to `KeystoneCouncilDB.global.keyLedger`
- Key: `"ownerGUID:dungeonID"`
- Track: firstSeenAt, lastSeenAt, resetWeek, bucket, source, integrationVersion
- On `PLAYER_LOGIN`: call `HydrateStore()` then `AutoCleanup()`
- On weekly reset detection (compare stored resetWeek to current): auto-prune stale entries
- `HydrateStore()` — push ledger entries into KeyStore at priority `LedgerReplay`
- `AutoCleanup()` — prune stale (>8 days or previous reset week) and enforce 500-row cap
- `GetAuditSummary()` — for Diagnostics
- `EntryMatchesView(entry, view)` — bucket + live roster check

**Dependencies:** Core/EventBus.lua, Data/KeyStore.lua, Data/SourcePriorityMap.lua, Util/Social.lua

**Public API:**
```
KC.KeyLedger.Record(keyData)
KC.KeyLedger.GetAll()
KC.KeyLedger.GetByView(view)
KC.KeyLedger.HydrateStore()
KC.KeyLedger.AutoCleanup()
KC.KeyLedger.GetAuditSummary()
KC.KeyLedger.Count()
```

---

#### `Data/SessionStore.lua`

**Purpose:**
Active vote session state. Scoped to the current login session. Always resets on `PLAYER_LOGIN`.

**Responsibilities:**
- Store: voteOpen, voteMode, voteToken, votes (playerName → keyID)
- Store: closedVoteTokens (last 8) for replay protection
- `StartVoteSession(mode, token)` — open a new session, clear previous votes
- `SetVote(unitName, keyID)` — record one vote
- `SetVoteOpen(isOpen)` — close session, mark token as closed
- `RecordSelection(result)` — append to selections (last 50)
- On `PLAYER_LOGIN`: reset voteOpen=false, voteMode="", voteToken="". Retain closedVoteTokens.
- Emit `KC.EVENTS.SESSION_CHANGED` on every mutation

**Dependencies:** Core/EventBus.lua, Core/Constants.lua

**Public API:**
```
KC.SessionStore.StartVoteSession(mode, token)
KC.SessionStore.SetVote(unitName, keyID)
KC.SessionStore.SetVoteOpen(isOpen)
KC.SessionStore.RecordSelection(result)
KC.SessionStore.GetVotes()
KC.SessionStore.IsVoteOpen()
KC.SessionStore.GetMode()
KC.SessionStore.GetToken()
KC.SessionStore.IsClosedToken(token)
KC.SessionStore.GetSelections()
```

---

#### `Data/HistoryStore.lua`

**Purpose:**
Recent selection history. Used by SmartEngine for recent-penalty scoring and by StatsPanel for display.

**Responsibilities:**
- Store last 50 selection results with full result data
- `Record(result)` — prepend, cap at 50
- `GetRecent(n)` — returns last n results (default 3, used by SmartEngine penalty)
- `GetAll()` — full list for StatsPanel

**Dependencies:** Core/EventBus.lua

**Public API:**
```
KC.HistoryStore.Record(result)
KC.HistoryStore.GetRecent(n)
KC.HistoryStore.GetAll()
KC.HistoryStore.Count()
```

---

#### `Data/StatsStore.lua`

**Purpose:**
Aggregate selection statistics by player and dungeon. Used by StatsPanel.

**Responsibilities:**
- Track: totalSelections, per-player selection count, per-dungeon selection count
- `Record(result)` — increment relevant counters
- `GetPlayerStats()` — sorted by selection count desc
- `GetDungeonStats()` — sorted by selection count desc
- `GetTotal()`

**Dependencies:** None.

**Public API:**
```
KC.StatsStore.Record(result)
KC.StatsStore.GetPlayerStats()
KC.StatsStore.GetDungeonStats()
KC.StatsStore.GetTotal()
KC.StatsStore.Reset()
```

---

#### `Data/SeasonBest.lua`

**Purpose:**
Personal season-best tracking per dungeon. Used by SmartEngine for seasonBestBonus scoring.

**Responsibilities:**
- Store: per-dungeonID best record (level, timed, timestamp, source)
- `Record(dungeonID, level, timed)` — update if new record
- `Get(dungeonID)` — returns best record or nil
- `GetAll()` — for display
- Detect and record from BlizzardKeys on login

**Dependencies:** Core/Constants.lua, Integrations/BlizzardKeys.lua

**Public API:**
```
KC.SeasonBest.Record(dungeonID, level, timed)
KC.SeasonBest.Get(dungeonID)
KC.SeasonBest.GetAll()
```

---

### Comm Layer

---

#### `Comm/Protocol.lua`

**Purpose:**
Message encoding and decoding. Owns the wire format. No I/O — pure transformation.

**Responsibilities:**
- Encode outgoing payloads as `TYPE|PROTOCOL_VERSION|FIELD_VERSION|fields...`
- Decode incoming payloads, validate type and version compatibility
- Unknown FIELD_VERSION: decode known fields, ignore remainder (forward compat)
- Unknown PROTOCOL_VERSION: return nil with reason "version_mismatch"
- Separator: `0x1F`
- Max payload: 900 bytes (enforce on encode, check on decode)
- Message types: KEY, LEDGER, VOTE, VOTE_OPEN, HELLO, ACK, RESULT
- `FIELD_VERSION` per type: allows individual message types to evolve independently

**Dependencies:** Core/Constants.lua, Data/SeasonRegistry.lua

**Public API:**
```
KC.Protocol.Encode(messageType, fields)     -- returns string or nil, error
KC.Protocol.Decode(payload)                 -- returns { type, fields } or nil, reason
KC.Protocol.VERSION_COMPATIBLE(version)     -- returns bool
```

**Wire format:**
```
KEY:
  TYPE | PROTO_VER | FIELD_VER | ownerGUID | ownerName | ownerRealm | classFile |
  dungeonID | dungeonName | level | updatedAt | score | weeklyBest | source | resetWeek

LEDGER: (same as KEY + integrationVersion)

VOTE:
  TYPE | PROTO_VER | FIELD_VER | unitName | keyID

VOTE_OPEN:
  TYPE | PROTO_VER | FIELD_VER | mode | token | playerName

HELLO:
  TYPE | PROTO_VER | FIELD_VER | addonVersion | playerName

ACK:
  TYPE | PROTO_VER | FIELD_VER | ackKind | token | playerName

RESULT:
  TYPE | PROTO_VER | FIELD_VER | winnerKeyID | mode | seed | reason |
  timestamp | ownerName | dungeonName | level | rationale
```

---

#### `Comm/PartySync.lua`

**Purpose:**
Reliable broadcast to party/raid/instance. Handles ACK-based delivery confirmation and retry.

**Responsibilities:**
- Send addon messages on the appropriate channel (PARTY/RAID/INSTANCE_CHAT)
- Track pending messages (cap: 10) awaiting ACK
- Retry unacknowledged messages (2 attempts, 3-second interval)
- Track failed messages (cap: 5)
- Receive and dispatch incoming addon messages to the appropriate handler
- Discover and track peers via HELLO messages
- On peer incompatible version: log warn, emit `KC.EVENTS.PEER_VERSION_MISMATCH`
- `BroadcastHello()` — advertise addon version on group join
- `BroadcastKey(key)` — share owned key
- `BroadcastLedger()` — share ledger entries (if shareLedger=true)
- `BroadcastVote(keyID)`
- `BroadcastVoteOpen(mode, token)`
- `BroadcastResult(result)`

**Dependencies:** Core/Constants.lua, Core/EventBus.lua, Comm/Protocol.lua, Util/Group.lua

**Public API:**
```
KC.PartySync.Send(messageType, fields)
KC.PartySync.BroadcastHello()
KC.PartySync.BroadcastKey(key)
KC.PartySync.BroadcastLedger()
KC.PartySync.BroadcastVote(keyID)
KC.PartySync.BroadcastVoteOpen(mode, token)
KC.PartySync.BroadcastResult(result)
KC.PartySync.GetPeers()             -- { playerName: { version, lastSeenAt } }
KC.PartySync.GetPendingCount()
KC.PartySync.GetFailedCount()
KC.PartySync.ProcessRetries()
```

---

#### `Comm/KeyNetwork.lua`

**Purpose:**
Fire-and-forget guild broadcast. No ACK, no retry. Used for passive guild key sharing.

**Responsibilities:**
- Broadcast KEY and HELLO messages to GUILD channel
- Track peers with 3600-second TTL
- Receive and dispatch guild KEY messages to KeyStore via IntegrationBus

**Dependencies:** Core/Constants.lua, Core/EventBus.lua, Comm/Protocol.lua

**Public API:**
```
KC.KeyNetwork.BroadcastKey(key)
KC.KeyNetwork.BroadcastHello()
KC.KeyNetwork.GetPeers()
```

---

### Integrations Layer

---

#### `Integrations/IntegrationBus.lua`

**Purpose:**
Central integration health registry. Every external source reports its status here. UI reads from here for the health panel.

**Responsibilities:**
- Maintain health state per source: `{ status, lastAttemptAt, lastSuccessAt, errorMessage }`
- Status values: `"ok"` | `"degraded"` | `"offline"` | `"unknown"`
- `Report(sourceName, status, errorMessage)` — called by each integration
- Emit `KC.EVENTS.INTEGRATION_HEALTH_CHANGED` on any status transition
- `GetAll()` — returns all health states for UI rendering
- `GetStatus(sourceName)` — single source status
- No I/O. Health state only.

**Dependencies:** Core/EventBus.lua, Core/Constants.lua

**Public API:**
```
KC.IntegrationBus.Report(sourceName, status, errorMessage)
KC.IntegrationBus.GetStatus(sourceName)
KC.IntegrationBus.GetAll()
```

---

#### `Integrations/BlizzardKeys.lua`

**Purpose:**
Wrapper over native WoW Mythic+ APIs. The highest-priority and most reliable key source.

**Responsibilities:**
- `ReadLocalKey()` — read player's owned keystone via C_MythicPlus
- `GetOverallScore()` — player's current M+ rating
- `GetCurrentWeekBestLevel(mapID)` — vault-relevant weekly best
- `GetRunHistoryWeeklyBestLevel(mapID)` — parse C_MythicPlus.GetRunHistory
- `GetCurrentWeek()` — weekly reset week number
- On any API returning nil: report `"degraded"` to IntegrationBus
- On successful read: report `"ok"` to IntegrationBus
- Auto-read local key on `PLAYER_LOGIN` and `CHALLENGE_MODE_COMPLETED`

**Dependencies:** Core/Constants.lua, Integrations/IntegrationBus.lua, Data/SourcePriorityMap.lua

**Public API:**
```
KC.BlizzardKeys.ReadLocalKey()
KC.BlizzardKeys.GetOverallScore()
KC.BlizzardKeys.GetCurrentWeekBestLevel(mapID)
KC.BlizzardKeys.GetRunHistoryWeeklyBestLevel(mapID)
KC.BlizzardKeys.GetCurrentWeek()
```

---

#### `Integrations/AstralKeys.lua`

**Purpose:**
Consolidated adapter for all AstralKeys data. Replaces ExternalKeyProvider and AstralBridge. Single integration point, single schema contract.

**Responsibilities:**
- **SavedVariables import** (triggered by `/kc refresh`):
  - Probe AstralKeys data using one documented schema path; fail with `Report("degraded")` on mismatch
  - No five-path fallback cascade
  - On schema mismatch: emit `Logger.Warn` with current expected schema version
- **Guild channel passive listener**:
  - Listen to GUILD channel for AstralKeys sync6 messages
  - Rate limit: deduplicate by sender+key within 5-second window (replaces 45 msg/min cap)
  - Supported formats: `{ "sync6" }` — unknown formats are silently ignored
  - On decode success: upsert to KeyStore at priority `AstralBridge`
- Report `"ok"` to IntegrationBus on any successful import
- Report `"offline"` if AstralKeys addon is not loaded
- Report `"degraded"` on schema mismatch or decode failure
- Expose `SUPPORTED_FORMATS` table for diagnostics

**Dependencies:** Core/Constants.lua, Core/Logger.lua, Integrations/IntegrationBus.lua, Data/KeyStore.lua, Data/SourcePriorityMap.lua, Util/Names.lua, Util/Social.lua

**Public API:**
```
KC.AstralKeys.ImportSavedVariables()     -- manual trigger on /kc refresh
KC.AstralKeys.RequestBroadcast()         -- send guild ping for AstralKeys data
KC.AstralKeys.GetStatus()               -- returns IntegrationBus status for this source
KC.AstralKeys.SUPPORTED_FORMATS         -- table of known format strings
```

---

### Council Layer

---

#### `Council/Modes.lua`

**Purpose:**
Decision orchestrator. The single entry point for all selection modes. Owns the flow from "start" to "result."

**Responsibilities:**
- `Start(mode)` — validate mode, gather candidates, route to correct engine
- `GetCandidateKeys()` — fetch from `KeyStore.GetByView("party")`, filter stale
- `GetMode()` — return current active mode from profile
- `SetMode(mode)` — update profile.mode, emit SESSION_CHANGED
- Validate that the requested mode engine is complete before starting
- On result: populate result struct, emit `KC.EVENTS.COUNCIL_RESULT`
- Post-result: call `SessionStore.RecordSelection`, `HistoryStore.Record`, `StatsStore.Record`
- Post-result: call `PartySync.BroadcastResult` if `announceWinnerToParty = true`

**Dependencies:** Core/EventBus.lua, Data/KeyStore.lua, Data/SessionStore.lua, Data/HistoryStore.lua, Data/StatsStore.lua, Council/VoteEngine.lua, Council/SpinEngine.lua, Council/MajorityEngine.lua, Council/SmartEngine.lua, Council/ChaosMode.lua, Council/ReadyCheck.lua, Council/ResultExplainer.lua, Comm/PartySync.lua

**Public API:**
```
KC.Modes.Start(mode)
KC.Modes.GetCandidateKeys()
KC.Modes.GetMode()
KC.Modes.SetMode(mode)
KC.Modes.Cancel()
```

---

#### `Council/VoteEngine.lua`

**Purpose:**
Raffle voting. Each vote adds weight to a key's selection odds.

**Responsibilities:**
- `Vote(keyID)` — validate key exists and vote is open; record via SessionStore; broadcast via PartySync
- `GetWeights(keys)` — returns `{ keyID: weight }` where base=1, voted=base+3 per vote
- `GetVoteSummary()` — returns per-key vote counts for VotePanel display

**Dependencies:** Core/EventBus.lua, Data/SessionStore.lua, Data/KeyStore.lua, Comm/PartySync.lua

**Public API:**
```
KC.VoteEngine.Vote(keyID)
KC.VoteEngine.GetWeights(keys)
KC.VoteEngine.GetVoteSummary()
```

---

#### `Council/SpinEngine.lua`

**Purpose:**
Weighted random selection. Shared by all modes as the final selection step.

**Responsibilities:**
- `PickWeighted(keys, weights, seed)` — LCG random selection respecting weights
- `GenerateSeed()` — based on server time
- `BuildResult(mode, keys, weights, winnerKeyID, seed, rationale)` — constructs standardized result struct
- Deterministic: same seed + same keys + same weights always produces same winner

**Dependencies:** Core/Constants.lua

**Public API:**
```
KC.SpinEngine.PickWeighted(keys, weights, seed)
KC.SpinEngine.GenerateSeed()
KC.SpinEngine.BuildResult(mode, keys, weights, winnerKeyID, seed, rationale)
```

**Result struct:**
```
{
  resultID       = "mode:seed:winnerKeyID",
  mode           = string,
  seed           = number,
  winnerKeyID    = string,
  winnerKey      = KeyRecord,
  weights        = table,
  timestamp      = number,
  rationale      = string,     -- from ResultExplainer
}
```

---

#### `Council/MajorityEngine.lua`

**Purpose:**
First-past-the-post democratic selection. The key with the most votes wins.

**Responsibilities:**
- `GetWinner(keys)` — count votes from SessionStore; return key with highest count
- Tie-break: call `SpinEngine.PickWeighted` with equal weights among tied keys
- Minimum quorum: if zero votes when session closes, fall back to spin (equal weights)
- `GetVoteCounts()` — per-key vote totals for VotePanel

**Dependencies:** Data/SessionStore.lua, Data/KeyStore.lua, Council/SpinEngine.lua

**Public API:**
```
KC.MajorityEngine.GetWinner(keys)
KC.MajorityEngine.GetVoteCounts()
```

---

#### `Council/SmartEngine.lua`

**Purpose:**
Multi-signal weighted scorer. Produces an objective recommendation using group data.

**Responsibilities:**
- Score each candidate key using the signal matrix (see below)
- Return scored weights suitable for SpinEngine.PickWeighted
- Surface per-key score breakdown for ResultExplainer
- Respect `profile.smart` tuning values

**Signal matrix:**
```
Base score:              10 + min(level, 20)          Always applied
scoreGapBonus:           +N (configurable, default 4)  If owner has lowest M+ score
vaultNeedBonus:          +N (configurable, default 6)  If key level > owner's weekly best
seasonBestBonus:         +N (configurable, default 3)  If key level > owner's season best
recentPenalty:           × M (configurable, default 0.65)  If dungeon in last 3 selections
duplicateDungeonPenalty: × M (configurable, default 0.75)  If same dungeon as higher-score key
intentBonus:             +0–4 (push) / +2 (farm, if timed)  Based on profile.smart.intent
```

**Dependencies:** Data/KeyStore.lua, Data/HistoryStore.lua, Data/SeasonBest.lua, Integrations/BlizzardKeys.lua

**Public API:**
```
KC.SmartEngine.Score(keys)                    -- returns { keyID: weight }
KC.SmartEngine.GetScoreBreakdown(keys)        -- returns { keyID: { signal: contribution } }
```

---

#### `Council/ChaosMode.lua`

**Purpose:**
Random dungeon assignment for chaos play. Each player gets assigned a different key/dungeon.

**Responsibilities:**
- `Assign(keys, players)` — randomly assign one key per player, no repeats where pool allows
- If pool size < player count: assign from pool with repetition, minimize repeats
- Return assignment map: `{ playerName: key }`
- `BroadcastAssignments(assignments)` — send via PartySync as RESULT messages (one per player)
- `BuildResult(assignments)` — constructs chaos result struct for ResultRenderer

**Dependencies:** Council/SpinEngine.lua, Comm/PartySync.lua, Util/Group.lua

**Public API:**
```
KC.ChaosMode.Assign(keys, players)
KC.ChaosMode.BroadcastAssignments(assignments)
KC.ChaosMode.BuildResult(assignments)
```

---

#### `Council/ReadyCheck.lua`

**Purpose:**
Pre-spin readiness gate. Ensures all party members acknowledge before selection begins.

**Responsibilities:**
- Broadcast `READY_REQUEST` to party (leader only)
- Collect `READY_ACK` responses per member
- 15-second timeout — absent members treated as ready after timeout (never block indefinitely)
- `GetReadyState()` — returns `{ playerName: "ready"|"pending"|"timeout" }`
- Emit `KC.EVENTS.READY_COMPLETE` when all members are accounted for
- Emit `KC.EVENTS.READY_TIMEOUT` when timeout fires with missing members

**Dependencies:** Core/EventBus.lua, Comm/PartySync.lua, Util/Group.lua

**Public API:**
```
KC.ReadyCheck.Start()
KC.ReadyCheck.GetReadyState()
KC.ReadyCheck.Cancel()
```

---

#### `Council/ResultExplainer.lua`

**Purpose:**
Human-readable rationale for every selection decision. Satisfies PRD Principle 4: "Every recommendation should be explainable."

**Responsibilities:**
- `Explain(result, scoreBreakdown)` — produce plain English rationale string
- Format varies by mode:
  - Spin: "Ara-Kara +18 chosen at random from 4 eligible keys."
  - Raffle: "Ara-Kara +18 chosen — 3 of 5 players voted for it."
  - Majority: "Ara-Kara +18 chosen — received the most votes (3 of 5)."
  - Smart: "Ara-Kara +18 chosen — vault upgrade opportunity (+6) for Jaxen, lowest M+ score in group (+4)."
  - Chaos: "Chaos assignments complete — each player receives a different dungeon."
- Output is included in RESULT wire message (truncated to 200 chars for wire)
- Full rationale available locally for WinnerBanner display

**Dependencies:** Data/SeasonRegistry.lua

**Public API:**
```
KC.ResultExplainer.Explain(result, scoreBreakdown)    -- returns string
```

---

### UI Layer

---

#### `UI/MainFrame.lua`

**Purpose:**
Root window. Container and coordinator for all primary UI panels.

**Responsibilities:**
- Create draggable, resizable root frame (620–940px × 330–760px)
- Embed KeyList, VotePanel, IntegrationHealthPanel
- Mode selector dropdown bound to `Modes.SetMode()`
- [Spin / Start Vote / Accept / Chaos] button wired to `Modes.Start()`
- Scale support (0.75–1.4×)
- Quote subtitle ticker from `Quotes.GetRandom()`
- Subscribe to `KEYS_CHANGED`, `SESSION_CHANGED`, `COUNCIL_RESULT` to trigger redraws
- Delegate panel visibility to session state (idle vs. voting vs. result)

**Dependencies:** Core/EventBus.lua, Council/Modes.lua, UI/KeyList.lua, UI/VotePanel.lua, UI/IntegrationHealthPanel.lua, UI/Toasts.lua, Core/Quotes.lua

**Public API:**
```
KC.MainFrame.Show()
KC.MainFrame.Hide()
KC.MainFrame.Toggle()
KC.MainFrame.SetMode(mode)
```

---

#### `UI/KeyList.lua`

**Purpose:**
Scrollable, sortable grid of visible keys. Core display widget.

**Responsibilities:**
- Render one row per key: owner, dungeon, level, score, weekly best, source
- Respect current sort mode and view filter
- Click on row: in idle mode → open CandidateInspector; in vote mode → call VoteEngine.Vote
- Highlight voted key per local player
- Show online/offline state per row
- Redraw on `KEYS_CHANGED`

**Dependencies:** Core/EventBus.lua, Data/KeyStore.lua, Council/VoteEngine.lua, UI/CandidateInspector.lua

**Public API:**
```
KC.KeyList.Refresh()
KC.KeyList.SetView(view)
KC.KeyList.SetSortMode(mode)
```

---

#### `UI/VotePanel.lua`

**Purpose:**
Vote progress display during raffle and majority sessions.

**Responsibilities:**
- Show per-member vote choices (name → dungeon voted)
- Show vote weight bars (raffle) or vote counts (majority)
- Show unvoted members
- Redraw on `SESSION_CHANGED`

**Dependencies:** Core/EventBus.lua, Data/SessionStore.lua, Council/VoteEngine.lua, Council/MajorityEngine.lua

**Public API:**
```
KC.VotePanel.Refresh()
```

---

#### `UI/CandidateInspector.lua`

**Purpose:**
Per-key detail flyout. Shows full key metadata including Smart score breakdown.

**Responsibilities:**
- Display: owner, dungeon, level, score, weekly best, vault upgrade delta, season best delta, source
- If mode = smart: show score signal contributions from SmartEngine.GetScoreBreakdown
- "Why this key?" section: surfaces ResultExplainer projected rationale for the hovered key
- Triggered by KeyList row click in idle mode

**Dependencies:** Data/KeyStore.lua, Council/SmartEngine.lua, Council/ResultExplainer.lua, Data/SeasonRegistry.lua

**Public API:**
```
KC.CandidateInspector.Show(keyID)
KC.CandidateInspector.Hide()
```

---

#### `UI/ResultRenderer.lua`

**Purpose:**
Shared result display component. Single implementation used by both WinnerBanner and StreamerOverlay.

**Responsibilities:**
- Accept a result struct and render: dungeon name, level, owner, mode, rationale
- Format varies by display context (full banner vs. minimal overlay)
- `RenderFull(result)` — for WinnerBanner
- `RenderCompact(result)` — for StreamerOverlay
- No frame creation — accepts a parent frame and renders into it

**Dependencies:** Data/SeasonRegistry.lua, Council/ResultExplainer.lua

**Public API:**
```
KC.ResultRenderer.RenderFull(parentFrame, result)
KC.ResultRenderer.RenderCompact(parentFrame, result)
```

---

#### `UI/WinnerBanner.lua`

**Purpose:**
Full-width result announcement overlay. Auto-dismisses after 8 seconds.

**Responsibilities:**
- Show on `COUNCIL_RESULT` event
- Render result via `ResultRenderer.RenderFull`
- Auto-dismiss after 8 seconds
- Manual dismiss on click

**Dependencies:** Core/EventBus.lua, UI/ResultRenderer.lua

**Public API:**
```
KC.WinnerBanner.Show(result)
KC.WinnerBanner.Hide()
```

---

#### `UI/StreamerOverlay.lua`

**Purpose:**
Minimal floating overlay for streaming contexts. Does not replace WinnerBanner — both can coexist.

**Responsibilities:**
- Show current group key summary (compact)
- Show last result via `ResultRenderer.RenderCompact`
- Toggle via `/kc streamer`
- Lock position when not in Edit mode

**Dependencies:** Core/EventBus.lua, Data/KeyStore.lua, UI/ResultRenderer.lua

**Public API:**
```
KC.StreamerOverlay.Show()
KC.StreamerOverlay.Hide()
KC.StreamerOverlay.Toggle()
```

---

#### `UI/IntegrationHealthPanel.lua`

**Purpose:**
Real-time integration status row. Shows users when data sources are healthy, degraded, or offline.

**Responsibilities:**
- Render one indicator per integration: Blizzard, AstralKeys, PartySync
- Colors: green (ok), yellow (degraded), red (offline), gray (unknown)
- Tooltip on hover: last success time, error message if degraded
- One-click `/kc refresh` button for manual re-import
- Redraw on `INTEGRATION_HEALTH_CHANGED`

**Dependencies:** Core/EventBus.lua, Integrations/IntegrationBus.lua

**Public API:**
```
KC.IntegrationHealthPanel.Refresh()
```

---

#### `UI/Settings.lua`

**Purpose:**
Options panel. All profile settings in one place.

**Responsibilities:**
- Render controls for every `profile` field (toggles, dropdowns, sliders)
- Smart mode: sliders for all tuning parameters with visible labels
- Key reporting: toggles per channel
- Guild rank filter: checklist per rank
- All changes write through to `profile` immediately — no apply/cancel
- Link to Diagnostics from within the panel

**Dependencies:** Config/Defaults.lua, Core/EventBus.lua

**Public API:**
```
KC.Settings.Show()
KC.Settings.Hide()
KC.Settings.Toggle()
```

---

#### `UI/StatsPanel.lua`

**Purpose:**
Historical selection stats display. Shows player and dungeon selection frequency.

**Responsibilities:**
- Render per-player selection counts (sorted desc)
- Render per-dungeon selection counts (sorted desc)
- Show total selections
- Render recent selection history list

**Dependencies:** Data/StatsStore.lua, Data/HistoryStore.lua

**Public API:**
```
KC.StatsPanel.Show()
KC.StatsPanel.Hide()
KC.StatsPanel.Refresh()
```

---

#### `UI/PeerPanel.lua`

**Purpose:**
Party sync peer health display.

**Responsibilities:**
- Show connected peers: name, addon version, last seen
- Highlight version mismatches (peer on incompatible protocol)
- Redraw on `PEER_VERSION_MISMATCH` and on HELLO messages

**Dependencies:** Comm/PartySync.lua, Core/EventBus.lua

**Public API:**
```
KC.PeerPanel.Show()
KC.PeerPanel.Hide()
KC.PeerPanel.Refresh()
```

---

#### `UI/Wheel.lua`

**Purpose:**
Visual spinner animation played during selection.

**Responsibilities:**
- Animate spin for configurable duration
- Stop on winner with visual emphasis
- Triggered by Modes.Start() before result is displayed

**Dependencies:** Core/EventBus.lua

**Public API:**
```
KC.Wheel.Spin(duration, onComplete)
KC.Wheel.Stop()
```

---

#### `UI/Toasts.lua`

**Purpose:**
Transient notification queue. Non-blocking alerts for sync events, errors, and state changes.

**Responsibilities:**
- Queue toast messages with severity (info/warn/error)
- Display one at a time, auto-dismiss after 4 seconds
- Click to dismiss early
- Maximum 5 queued

**Dependencies:** Core/EventBus.lua

**Public API:**
```
KC.Toasts.Show(message, severity)
```

---

#### `UI/MinimapButton.lua`

**Purpose:**
Standard minimap icon. WoW addon convention.

**Responsibilities:**
- Left click: MainFrame.Toggle
- Right click: Settings.Show
- Draggable around minimap perimeter
- Visibility gated by `profile.options.showMinimapButton`

**Dependencies:** UI/MainFrame.lua, UI/Settings.lua

**Public API:**
```
KC.MinimapButton.Show()
KC.MinimapButton.Hide()
```

---

#### `UI/TeleportButton.lua`

**Purpose:**
Dungeon portal shortcut. Consolidates KC_PortalActions into a single clean module.

**Responsibilities:**
- Display when player has a portal available for the selected dungeon
- Click: invoke portal action
- Gated by: result exists + player is at a valid portal location

**Dependencies:** Core/Constants.lua, Data/KeyStore.lua

**Public API:**
```
KC.TeleportButton.Show(dungeonID)
KC.TeleportButton.Hide()
```

---

#### `UI/DevPanel.lua`

**Purpose:**
Developer dashboard. Visible only when `profile.debug = true`.

**Responsibilities:**
- Inject fake keys, ledger entries, stale entries
- Show IntegrationBus health dump
- Show module status table
- Run diagnostics export inline

**Dependencies:** Core/DevTools.lua, Integrations/IntegrationBus.lua, Core/Module.lua, Core/Diagnostics.lua

**Public API:**
```
KC.DevPanel.Show()
KC.DevPanel.Hide()
KC.DevPanel.Toggle()
```

---

## 3. Data Models

### KeyRecord

The canonical shape of a key at rest and in transit.

```
KeyRecord = {
  -- Identity
  id               string    "ownerGUID:dungeonID"  -- canonical key
  ownerGUID        string    WoW player GUID
  ownerName        string    "Name-Realm" normalized lowercase
  ownerRealm       string    realm name
  classFile        string    WoW class file identifier

  -- Dungeon
  dungeonID        number    WoW challenge map ID
  dungeonName      string    resolved from SeasonRegistry
  dungeonShort     string    short name from SeasonRegistry
  level            number    keystone level

  -- Scores
  score            number    owner's current M+ rating (may be 0)
  weeklyBest       number    owner's best level this reset for this dungeon (may be 0)
  seasonBest       number    owner's all-time best for this dungeon (may be 0)

  -- Provenance
  source           string    source identifier from SourcePriorityMap
  priority         number    numeric priority from SourcePriorityMap
  integrationVersion string  which adapter version recorded this entry
  resetWeek        string    WoW weekly reset identifier when recorded

  -- Timestamps
  firstSeenAt      number    Unix timestamp
  lastSeenAt       number    Unix timestamp
  updatedAt        number    Unix timestamp (most recent update)

  -- Social
  bucket           string    "party"|"guild"|"friends"|"other"
  isOnline         boolean   resolved at render time, not stored
}
```

---

### ResultRecord

The output of any Council mode. Standardized across all engines.

```
ResultRecord = {
  resultID         string    "mode:seed:winnerKeyID"
  mode             string    "spin"|"raffle"|"majority"|"smart"|"chaos"
  seed             number    LCG seed used (0 for majority/chaos)
  winnerKeyID      string    canonical key ID
  winnerKey        KeyRecord full key record at time of selection
  weights          table     { keyID: weight } at time of selection
  timestamp        number    Unix timestamp
  rationale        string    ResultExplainer output (full)
  rationaleWire    string    ResultExplainer output (truncated to 200 chars for wire)

  -- Chaos-specific (nil for other modes)
  assignments      table     { playerName: KeyRecord }
}
```

---

### SessionRecord

The active vote session state.

```
SessionRecord = {
  voteOpen         boolean
  voteMode         string    "raffle"|"majority"|""
  voteToken        string    "mode:timestamp:random"
  votes            table     { playerName: keyID }
  closedVoteTokens table     { token: true }  -- last 8
  closedVoteOrder  table     [ token, ... ]   -- insertion order
  selections       table     [ ResultRecord, ... ]  -- last 50
}
```

---

### IntegrationHealthRecord

```
IntegrationHealthRecord = {
  sourceName       string
  status           string    "ok"|"degraded"|"offline"|"unknown"
  lastAttemptAt    number    Unix timestamp
  lastSuccessAt    number    Unix timestamp or nil
  errorMessage     string    nil unless degraded/offline
}
```

---

### PeerRecord

```
PeerRecord = {
  playerName       string
  addonVersion     string
  protocolVersion  number
  lastSeenAt       number    Unix timestamp
  compatible       boolean   protocolVersion == KC.PROTOCOL_VERSION
}
```

---

### LedgerEntry

Stored in `KeystoneCouncilDB.global.keyLedger`. Superset of KeyRecord with persistence metadata.

```
LedgerEntry = KeyRecord + {
  integrationVersion  string    adapter version that wrote this entry
  -- All other KeyRecord fields present
}
```

---

### SmartScoreBreakdown

Output of SmartEngine.GetScoreBreakdown. Used by ResultExplainer and CandidateInspector.

```
SmartScoreBreakdown = {
  [keyID] = {
    base              number
    scoreGapBonus     number    (0 if not applied)
    vaultNeedBonus    number    (0 if not applied)
    seasonBestBonus   number    (0 if not applied)
    recentPenalty     number    (0 if not applied; negative contribution)
    duplicatePenalty  number    (0 if not applied; negative contribution)
    intentBonus       number    (0 if not applied)
    total             number
  }
}
```

---

## 4. Network Architecture

### Topology

```
All clients (P2P via WoW addon message API)

Player A ──PARTY──► Player B, C, D, E
Player A ──GUILD──► All guild members online
Player A ──INSTANCE_CHAT──► All players in instance

No server. No relay. No external network calls.
```

### Channel Assignment

```
Context             Channel Used
────────────────────────────────────────────────
In party (no raid)  PARTY
In raid             RAID
In instance         INSTANCE_CHAT (takes precedence)
Guild broadcast     GUILD
```

### Message Lifecycle

```
Send path:
Modes / VoteEngine / PartySync
  → Protocol.Encode(type, fields)
  → WoW SendAddonMessage(prefix, payload, channel)

Receive path:
CHAT_MSG_ADDON frame event
  → PartySync.OnAddonMessage(prefix, payload, channel, sender)
  → Protocol.Decode(payload)
  → Dispatch to handler by message type
```

### Reliability Model

```
Message Type    Reliability     Mechanism
────────────────────────────────────────────────────────────────
KEY             Reliable        ACK + retry (2× @ 3s), pending cap 10
LEDGER          Reliable        ACK + retry (2× @ 3s)
VOTE            Best-effort     No ACK. Vote source of truth is local.
VOTE_OPEN       Best-effort     Repeated on each retry of leader's HELLO
HELLO           Best-effort     Sent on group join; no retry needed
ACK             Best-effort     Response to reliable messages
RESULT          Best-effort     WinnerBanner provides local fallback
```

### Version Compatibility

```
Incoming message:
  PROTOCOL_VERSION matches local  → process normally
  PROTOCOL_VERSION mismatch       → reject, log warn, emit PEER_VERSION_MISMATCH
  FIELD_VERSION unknown for type  → decode known fields, ignore unknown fields
  Payload > 900 bytes             → reject on decode

Outgoing message:
  Always encode at current PROTOCOL_VERSION and per-type FIELD_VERSION
  Enforce 900-byte cap on encode; split if needed (LEDGER bulk)
```

### Rate Limits

```
AstralBridge receive:   Deduplicate by sender+key within 5-second window
KeyReporter response:   4-second cooldown per sender+channel
PartySync send:         No explicit rate limit; WoW API enforces
Guild broadcast:        No explicit rate limit; fire-and-forget
```

---

## 5. UI Architecture

### Frame Hierarchy

```
MinimapButton           (independent, always present if enabled)
MainFrame               (root window)
  ├── IntegrationHealthPanel   (top bar, always visible in MainFrame)
  ├── KeyList                  (primary content area)
  │     └── CandidateInspector (flyout, overlays KeyList)
  ├── VotePanel                (replaces KeyList during vote session)
  ├── Mode Selector            (embedded in MainFrame header)
  └── Action Button            (Spin / Start Vote / Accept / Chaos)

WinnerBanner            (independent overlay, shown on COUNCIL_RESULT)
StreamerOverlay         (independent overlay, toggle via /kc streamer)
Toasts                  (independent overlay, queued notifications)
Settings                (child of MainFrame or independent panel)
StatsPanel              (tab or child of MainFrame)
PeerPanel               (tab or child of MainFrame)
DevPanel                (child of MainFrame, debug-gated)
Wheel                   (child of MainFrame, shown during spin animation)
TeleportButton          (independent button, shown near MainFrame)
```

### State Machine

```
MainFrame states:

IDLE
  KeyList visible, VotePanel hidden
  Action button label: "Spin" (spin/smart/chaos) or "Start Vote" (raffle/majority)
  CandidateInspector available on key click

READY_CHECK (if ReadyCheck enabled)
  ReadyCheck panel visible
  Action button: "Cancel"
  Transition → SPINNING when all ready

SPINNING
  Wheel animation plays
  Action button hidden
  Transition → RESULT when Wheel.onComplete fires

VOTING (raffle / majority)
  VotePanel visible
  KeyList shows clickable vote targets
  Action button label: "Close Vote" (leader only)
  Transition → SPINNING when vote closed

RESULT
  WinnerBanner displayed
  MainFrame shows last key list (no interaction)
  Transition → IDLE after 8 seconds or on banner dismiss
```

### Event Subscriptions

```
Module                      Listens To
────────────────────────────────────────────────────────────
MainFrame                   KEYS_CHANGED, SESSION_CHANGED, COUNCIL_RESULT
KeyList                     KEYS_CHANGED
VotePanel                   SESSION_CHANGED
IntegrationHealthPanel      INTEGRATION_HEALTH_CHANGED
PeerPanel                   PEER_VERSION_MISMATCH (+ HELLO messages via PartySync)
WinnerBanner                COUNCIL_RESULT
StreamerOverlay             KEYS_CHANGED, COUNCIL_RESULT
Toasts                      INTEGRATION_HEALTH_CHANGED, PEER_VERSION_MISMATCH
```

### Rendering Rules

- UI never reads from SavedVariables directly. All reads go through Data layer public APIs.
- UI never writes to Data layer directly. All mutations go through Council or EventBus.
- UI redraws are triggered by EventBus events, not by polling.
- Scale changes immediately re-render the entire MainFrame.

---

## 6. Persistence Architecture

### Storage Location

```
WoW SavedVariables: KeystoneCouncilDB
File: WTF/Account/<account>/SavedVariables/KeystoneCouncil.lua
Scope: Account-wide (shared across all characters on the account)
```

### Top-Level Structure

```
KeystoneCouncilDB = {
  profileVersion   number   (current: 4)
  profile          table    (user settings)
  global           table    (shared data)
  session          table    (current session state — resets on login)
  migrations       table    { "4": timestamp }
}
```

### Write Events

```
Event                           Writer                  Frequency
──────────────────────────────────────────────────────────────────
New key seen                    KeyLedger.Record        Per key upsert
Council result                  StatsStore.Record       Per selection
Council result                  HistoryStore.Record     Per selection
Council result                  SessionStore.RecordSelection  Per selection
New season best                 SeasonBest.Record       Rare
Settings change                 Settings panel          User-driven
WoW shutdown                    WoW engine flush        Once
```

### Read Events

```
Event                           Reader                  Notes
──────────────────────────────────────────────────────────────────
PLAYER_LOGIN                    KeyLedger.HydrateStore  Populates KeyStore
PLAYER_LOGIN                    Migrations.Apply        Schema upgrade
PLAYER_LOGIN                    SessionStore reset      Clears voteOpen
Any UI render                   Data layer APIs         Via public API only
```

### Cleanup

```
Trigger                         Action
──────────────────────────────────────────────────────────────────
PLAYER_LOGIN                    KeyLedger.AutoCleanup()
  - Remove entries > 8 days old
  - Remove entries from previous reset week
  - Enforce 500-row cap (drop oldest/stalest)
  - Detect weekly reset (compare resetWeek to BlizzardKeys.GetCurrentWeek)
  - If reset detected: prune all entries from prior week

/kc cleanup (manual)            KeyLedger.AutoCleanup() (same logic, on demand)
```

### Data Limits

```
Ledger entries:         500 max (hard cap)
History records:        50 max
Session selections:     50 max
Closed vote tokens:     8 max
StatsStore:             Unbounded (aggregate counters only — small)
PeerPanel peers:        Unbounded (TTL-expired naturally)
```

---

## 7. Seasonal Content Architecture

### Design Goal

Adding or transitioning a WoW season requires **zero Lua logic changes**. Only a data file changes.

### Season File Contract

Every season file must conform to:

```
KC.SeasonData["SEASON_KEY"] = {
  key       string    unique season identifier (e.g. "TWW2")
  name      string    human-readable season name
  dungeons  table     array of DungeonRecord:
    {
      id        number    WoW challenge map ID
      name      string    full dungeon name
      shortName string    3–6 char abbreviation
      mapID     number    WoW map ID for portal/teleport
    }
}
```

### Active Season Selection

`KC.ACTIVE_SEASON` is set in `Core/Constants.lua`. Changing the season requires updating this one constant and ensuring the corresponding Season file is in the .toc load order.

### SeasonRegistry Behavior

```
GetDungeon(id):
  1. Look up in active season index
  2. If not found, look up in all loaded historical season indexes
  3. If still not found, return safe fallback:
     { id=id, name="Dungeon #"..id, shortName="???", mapID=0 }
  4. Never return nil. Never error.

GetAllDungeons():
  Returns active season dungeons only.

GetDungeonFromSeason(id, seasonKey):
  Look up in specific season (for historical ledger display).
  Returns fallback if not found.
```

### Season Transition Procedure

```
1. Create Seasons/Season_<NewKey>.lua with dungeon data
2. Add Season_<NewKey>.lua to KeystoneCouncil.toc (load order)
3. Update KC.ACTIVE_SEASON = "<NewKey>" in Constants.lua
4. Historical season file remains for ledger display
5. No other changes required
```

### Historical Ledger Display

Ledger entries store `dungeonID` and `resetWeek`. When displaying a ledger entry from a prior season, `SeasonRegistry.GetDungeonFromSeason(id, seasonKey)` resolves the name from the correct historical season file.

---

## 8. Portal Architecture

### Scope

Portal actions are a convenience feature. They are within KSC's mission (reducing friction before entering the dungeon) but are not a core decision feature.

### Design

`UI/TeleportButton.lua` is a single, clean module. It replaces the partial `KC_PortalActions.lua` from 0.9.x.

### Behavior

```
Visible when:
  - A Council result exists (result stored in SessionStore.GetSelections())
  - Player is not inside an instance
  - A portal exists for the result dungeon (WoW API check)

Action on click:
  - Invoke the appropriate dungeon portal via WoW's C_ChallengeMode or item use API
  - Display error toast if portal not available

Hidden when:
  - No result
  - Player is inside an instance
  - No portal available
```

### Portal Availability Check

```
KC.TeleportButton uses:
  C_ChallengeMode.GetMapTable() → verify mapID is current season
  C_Spell.GetSpellInfo(portalSpellID) → check if portal spell known
  OR
  Item-based portal (keystone item use)
```

### Constraints

- TeleportButton never forces a portal action. User always clicks.
- TeleportButton is not available in combat (`InCombatLockdown()` check).
- If portal API is unavailable (missing API in a patch), button is hidden with no error.

---

## 9. Integration Architecture

### Integration Principles

1. Every integration has a named source identifier in `SourcePriorityMap`.
2. Every integration reports health to `IntegrationBus` on every attempt.
3. Every integration fails loudly with a structured message, not silently.
4. No integration can crash the addon. All integration calls are pcall-wrapped.
5. Integrations are additive. Removing any integration degrades data richness, not core function.

### Integration Registry

```
Source          Priority  Module              Health Reporting
──────────────────────────────────────────────────────────────────
Blizzard        100       BlizzardKeys.lua    On every API call
AstralKeysSV    60        AstralKeys.lua      On every import
AstralBridge    55        AstralKeys.lua      On decode success/failure
LedgerReplay    92        KeyLedger.lua       N/A (internal, always "ok")
PartySync       95        PartySync.lua       Via PeerPanel (version compat)
Dev             10        DevTools.lua        N/A (debug only)
```

### AstralKeys Integration Detail

```
Two access modes within one module:

Mode 1: SavedVariables Import (on /kc refresh)
  Trigger: Manual user action
  Source priority: AstralKeysSV (60)
  Schema: One documented schema path. Fail loudly on mismatch.
  Health: Report "ok" on success, "degraded" on schema mismatch, "offline" if addon missing

Mode 2: Guild Channel Passive Listener
  Trigger: Incoming GUILD message
  Source priority: AstralBridge (55)
  Format: sync6 only. Unknown formats silently skipped.
  Dedup: sender+key within 5 seconds
  Health: Report "ok" on successful decode
```

### Adding a New Integration in the Future

```
1. Create Integrations/<Name>.lua
2. Register source name and priority in SourcePriorityMap
3. Call IntegrationBus.Report on every attempt
4. Upsert to KeyStore with correct source and priority
5. Add to Diagnostics.PrintIntegrations output
6. Add health indicator to IntegrationHealthPanel
7. Document supported data schema version
```

### Removing an Integration

```
1. Remove from SourcePriorityMap
2. Remove module file
3. Remove from .toc
4. Remove from IntegrationHealthPanel
5. Any ledger entries with removed source remain valid — source field is stored,
   SeasonRegistry still resolves dungeon names
```

---

## 10. Migration Plan from 0.9.x

### Overview

Migration from 0.9.x to 1.0 is handled by the existing migration system extended with a new `v4` migration step. Migrations run on `PLAYER_LOGIN` before `KeyLedger.HydrateStore`.

### Schema Changes: v3 → v4

```
Profile changes:
  REMOVE: profile.includeGuildMemeQuotes    (no guild banter in 1.0)
  REMOVE: profile.includeRareQuotes         (no rare quote tier in 1.0)
  REMOVE: profile.countdownPrimaryAudio     (no CountdownProviders in 1.0)
  REMOVE: profile.countdownSecondaryAudio   (no CountdownProviders in 1.0)
  REMOVE: profile.options.useExternalScores (no ExternalScoreProvider in 1.0)
  MODIFY: profile.mode — if stored value is "majority" or "chaos", reset to "spin"
           (these modes were incomplete in 0.9.x; players on them should not stay broken)

Global changes:
  NONE — keyLedger, history, stats, seasonBest schemas are backward compatible

Session changes:
  RESET: session.voteOpen = false           (force-clear any lingering vote state)
  RESET: session.voteMode = ""
  RESET: session.voteToken = ""
  RETAIN: session.closedVoteTokens          (replay protection history preserved)
  RETAIN: session.selections                (history preserved)

Ledger changes:
  ADD: integrationVersion field to all existing entries (backfill with "legacy")
```

### Migration Code Location

All migration logic lives in `Bootstrap.lua` inside a `Migrations` table:

```
Migrations = {
  ["1"] = function() ... end,    -- (existing)
  ["2"] = function() ... end,    -- (existing)
  ["3"] = function() ... end,    -- (existing)
  ["4"] = function()             -- NEW for 1.0
    -- Remove deprecated profile keys
    -- Reset incomplete mode selections
    -- Force-clear session vote state
    -- Backfill integrationVersion on ledger entries
    -- Stamp KC.Defaults.PROFILE_VERSION = 4
  end,
}
```

### File Deletions

These files must be removed from the .toc and deleted from disk before the 1.0 build:

```
DELETE: Core/FileManifest.lua
DELETE: Data/DungeonRegistry.lua
DELETE: Integrations/ExternalKeyProvider.lua
DELETE: Integrations/AstralBridge.lua
DELETE: Integrations/SharedKeyProvider.lua
DELETE: Integrations/GroupKeyProvider.lua
DELETE: Integrations/ExternalScoreProvider.lua
DELETE: Integrations/CountdownProviderA.lua
DELETE: Integrations/CountdownProviderB.lua
DELETE: Core/Util.lua                           (replaced by Util/ directory)
DELETE: UI/KC_PortalActions.lua                 (replaced by UI/TeleportButton.lua)
```

### New Files

These files must be created and added to the .toc:

```
ADD: Util/Names.lua
ADD: Util/Social.lua
ADD: Util/Keys.lua
ADD: Util/Group.lua
ADD: Seasons/Season_TWW2.lua
ADD: Seasons/Season_TWW1.lua         (optional, for historical display)
ADD: Data/SeasonRegistry.lua
ADD: Data/SourcePriorityMap.lua
ADD: Integrations/IntegrationBus.lua
ADD: Integrations/AstralKeys.lua
ADD: Council/ChaosMode.lua           (complete implementation)
ADD: Council/ReadyCheck.lua          (complete implementation)
ADD: Council/ResultExplainer.lua
ADD: UI/ResultRenderer.lua
ADD: UI/IntegrationHealthPanel.lua
```

### Rollback Consideration

WoW SavedVariables do not support rollback. Once migration v4 runs, the profile schema is v4. If a user downgrades to 0.9.x after running 1.0, the 0.9.x addon will encounter unknown profile fields and fall back to defaults, which is the correct behavior. The keyLedger, history, and stats tables are all backward compatible — no data loss.

### Migration Checklist

```
[ ] Profile v4 migration written and tested
[ ] Deprecated fields removed from profile after migration
[ ] Incomplete mode selections reset to "spin"
[ ] Session vote state force-cleared on migration
[ ] LedgerEntry.integrationVersion backfilled to "legacy"
[ ] Migration stamp "4" written to migrations table
[ ] All deleted files removed from .toc
[ ] All new files added to .toc in correct load order
[ ] FileManifest.lua removed
[ ] DevTools password removed; debug flag gate implemented
[ ] AstralKeys consolidated adapter tested against live AstralKeys SavedVariables
[ ] SeasonRegistry safe-fallback tested with unknown dungeonID
[ ] SessionStore PLAYER_LOGIN reset tested
[ ] KeyLedger AutoCleanup tested on login
[ ] Social cache immediate invalidation on GUILD_ROSTER_UPDATE tested
[ ] All five modes functional and selectable
[ ] IntegrationHealthPanel displays correct status for all three sources
[ ] ResultExplainer produces output for all five modes
[ ] WinnerBanner and StreamerOverlay both use ResultRenderer (no duplicate logic)
[ ] PeerPanel shows version mismatch on protocol incompatibility
[ ] CandidateInspector shows Smart score breakdown
[ ] Diagnostics consolidation: /kc diag with flags
[ ] TeleportButton replaces KC_PortalActions, tested in non-combat state
```

---

## 11. Module Status Index

| Module | Status | Action |
|--------|--------|--------|
| Core/Constants.lua | Keep + Extend | Add INTEGRATION_HEALTH_CHANGED, PEER_VERSION_MISMATCH, SOURCE_PRIORITY, FIELD_VERSION |
| Core/EventBus.lua | Keep | No changes |
| Core/Module.lua | Keep | No changes |
| Core/Logger.lua | Keep + Extend | Add Warn tier |
| Core/Bootstrap.lua | Keep + Extend | Add PLAYER_LOGIN session reset; add migration v4 |
| Core/Diagnostics.lua | Keep + Rebuild | Consolidate slash commands; add integration health output |
| Core/DevTools.lua | Keep + Rebuild | Remove password; gate on profile.debug |
| Core/Quotes.lua | Keep + Trim | Remove guild-banter, rare tier, font-fitting; 10 static quotes |
| Core/FileManifest.lua | **Delete** | Duplicate of .toc |
| Core/Util.lua | **Delete** | Split into Util/ directory |
| Core/KeyReporter.lua | Keep | No changes |
| Util/Names.lua | **New** | Split from Util.lua |
| Util/Social.lua | **New** | Split from Util.lua + add roster event invalidation |
| Util/Keys.lua | **New** | Split from Util.lua |
| Util/Group.lua | **New** | Split from Util.lua |
| Config/Defaults.lua | Keep + Extend | Remove deprecated fields; add v4 stamp |
| Seasons/Season_TWW2.lua | **New** | Active season data file |
| Seasons/Season_TWW1.lua | **New** (optional) | Historical season data file |
| Data/DungeonRegistry.lua | **Delete** | Replaced by SeasonRegistry + Seasons/ |
| Data/SeasonRegistry.lua | **New** | Data-driven dungeon lookup with safe fallback |
| Data/SourcePriorityMap.lua | **New** | Canonical priority table |
| Data/KeyStore.lua | Keep + Extend | Import priority from SourcePriorityMap |
| Data/KeyLedger.lua | Keep + Extend | Add AutoCleanup on PLAYER_LOGIN; weekly reset detection; integrationVersion field |
| Data/SessionStore.lua | Keep + Rebuild | Add PLAYER_LOGIN reset; reduce closed-token cap to 8 |
| Data/HistoryStore.lua | Keep | No changes |
| Data/StatsStore.lua | Keep | No changes |
| Data/SeasonBest.lua (KC_SeasonBest) | Keep | No changes |
| Comm/Protocol.lua | Keep + Extend | Add FIELD_VERSION per message type; add RESULT.rationale field |
| Comm/PartySync.lua | Keep + Rebuild | Reduce pending cap to 10, failed cap to 5; emit PEER_VERSION_MISMATCH |
| Comm/KeyNetwork.lua | Keep | No changes |
| Integrations/IntegrationBus.lua | **New** | Health state registry |
| Integrations/BlizzardKeys.lua | Keep + Extend | Report to IntegrationBus |
| Integrations/ExternalKeyProvider.lua | **Delete** | Merged into AstralKeys.lua |
| Integrations/AstralBridge.lua | **Delete** | Merged into AstralKeys.lua |
| Integrations/AstralKeys.lua | **New** | Consolidated adapter |
| Integrations/SharedKeyProvider.lua | **Delete** | Stub — no implementation |
| Integrations/GroupKeyProvider.lua | **Delete** | Stub — no implementation |
| Integrations/ExternalScoreProvider.lua | **Delete** | Stub — no implementation |
| Integrations/CountdownProviderA.lua | **Delete** | Stub — no implementation |
| Integrations/CountdownProviderB.lua | **Delete** | Stub — no implementation |
| Council/Modes.lua | Keep + Extend | Add ReadyCheck gate; add ResultExplainer call |
| Council/VoteEngine.lua | Keep | No changes |
| Council/SpinEngine.lua | Keep + Extend | Add rationale parameter to BuildResult |
| Council/MajorityEngine.lua | **Rebuild** | Complete implementation |
| Council/SmartEngine.lua | Keep + Extend | Add GetScoreBreakdown() for explainability |
| Council/ChaosMode.lua (KC_ChaosMode) | **Rebuild** | Complete implementation |
| Council/ReadyCheck.lua | **Rebuild** | Complete implementation |
| Council/ResultExplainer.lua | **New** | Per-mode human-readable rationale |
| UI/MainFrame.lua | Keep + Extend | Add IntegrationHealthPanel embed; mode gate for incomplete modes |
| UI/KeyList.lua | Keep | No changes |
| UI/VotePanel.lua | Keep | No changes |
| UI/CandidateInspector.lua | Keep + Extend | Add Smart score breakdown; add "Why this key?" |
| UI/ResultRenderer.lua | **New** | Shared result display component |
| UI/WinnerBanner.lua | Keep + Rebuild | Use ResultRenderer; show rationale |
| UI/StreamerOverlay.lua | Keep + Rebuild | Use ResultRenderer |
| UI/IntegrationHealthPanel.lua | **New** | Source health status row |
| UI/Settings.lua | Keep | Audit for orphaned toggles matching deleted features |
| UI/StatsPanel.lua | Keep | No changes |
| UI/PeerPanel.lua | Keep + Extend | Show version mismatch indicators |
| UI/Wheel.lua | Keep | No changes |
| UI/Toasts.lua | Keep | No changes |
| UI/MinimapButton.lua | Keep | No changes |
| UI/TeleportButton.lua | Keep + Rebuild | Replaces KC_PortalActions; clean implementation |
| UI/KC_PortalActions.lua | **Delete** | Replaced by TeleportButton.lua |
| UI/DevPanel.lua | Keep + Extend | Add IntegrationBus dump; remove password UI |

**Summary:**
- Keep (no changes): 14
- Keep + Extend/Rebuild: 22
- New: 13
- Delete: 12
- **Total 1.0 modules: 49**

---

*End of KSC 1.0 Engineering Blueprint*
*Authority: KSC_1_0_ARCHITECTURE_AUDIT.md + KSC_1_0_PRD.md*
*Next: Implementation sprints begin from this document.*
