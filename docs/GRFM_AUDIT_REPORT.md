# GuildRadioFM Architecture Audit
**Addon:** GuildRadioFM  
**Version:** 0.6.4  
**Interface:** 120005 (Retail WoW, The War Within)  
**Audit Date:** 2026-06-11  
**Auditor:** CTO, Keystone Council  
**Status:** INFORMATIONAL — No sprint blocking this addon. Audit requested for architectural reference.

---

## 1. Executive Summary

GuildRadioFM is a 3,600-line WoW addon that functions as a local MP3 player for guilds. It plays audio files bundled with the addon through WoW's Dialog sound channel, provides metadata sharing via addon messages, and includes lyrics, seek simulation, a playback queue, playlists, favorites, and an easter-egg "Hidden Frequency" unlock system.

The addon is **feature-complete and functioning** at v0.6.4. The CHANGELOG shows six consecutive, well-scoped releases. The code is defensively written with pcall guards on every external API call.

The primary architectural concern is **monolith growth**. Two files account for 73% of all code: Core.lua (1,042 lines) and UI.lua (1,547 lines). Both files mix unrelated concerns onto a single global table. The addon is at the size boundary where adding one more major feature will make maintenance painful.

**Verdict:** Healthy for v0.6.x scope. Refactor-eligible at v0.7.0.

---

## 2. File Inventory

| File | Lines | Role |
|------|-------|------|
| GuildRadioFM.toc | — | Addon manifest, load order |
| SongList.lua | ~40 | Static song registry |
| Core.lua | 1,042 | Main engine: playback, state, playlists, favorites, volume, easter eggs |
| Audio.lua | 37 | PlaySoundFile wrapper |
| UI.lua | 1,547 | All 9 window frames + minimap button + options panel |
| Commands.lua | 93 | Slash command handler |
| Core/Lyrics.lua | 307 | LRC-style timestamped lyrics engine |
| Core/HiddenFrequency.lua | 115 | Easter egg unlock system + placeholder playlist |
| Core/Queue.lua | 142 | Ordered playback queue with persistence |
| Core/Seek.lua | 112 | Progress tracking and seek simulation |
| Core/Sharing.lua | 265 | Addon message metadata broadcast and inbox |
| **Total** | **~3,700** | |

**SavedVariables:** `GuildRadioFMDB` — single flat table, no schema versioning.

---

## 3. Systems Inventory

### 3.1 Core Systems

| System | File | Purpose |
|--------|------|---------|
| Playback Engine | Core.lua | Play, Stop, Next, Back, AutoNext tick, duration-based advance |
| Audio Layer | Audio.lua | PlaySoundFile("Dialog"), StopSound with pcall guard |
| Song Registry | SongList.lua | Static `GuildRadioFMSongList` table, 15 songs (1 hidden) |
| Song Pack API | Core.lua | `RegisterSongPack()` — external addon extensibility |
| Favorites | Core.lua | Persistent like/unlike per song, filtered library view |
| Playlists | Core.lua | Named playlists, saved per-character |
| Volume Control | Core.lua | Dialog channel volume via `SetCVar` |
| Queue | Core/Queue.lua | Ordered queue, persistent, FIFO pop on track end |
| Seek/Progress | Core/Seek.lua | Display-only elapsed time simulation |
| Lyrics | Core/Lyrics.lua | LRC-format timestamped lyrics, alias resolution |
| Hidden Frequency | Core/HiddenFrequency.lua | Session-only easter egg unlock, placeholder playlist |
| Sharing | Core/Sharing.lua | Addon message metadata broadcast and inbox |

### 3.2 UI Systems

| Window | Purpose |
|--------|---------|
| Maxi Player | Full player with progress bar, controls, lyrics |
| Mini Player | Compact combat-friendly bar |
| Library | Song list with favorites filter |
| Playlists | Playlist browser and management |
| Queue Window | Queue viewer with remove controls |
| Sharing Requests | Inbox for received metadata shares |
| Settings | In-addon settings panel |
| AddSongs | Song pack documentation/importer |
| Hidden Frequency | Unlockable easter egg window |
| Minimap Button | Draggable minimap icon |
| Options Panel | WoW Settings API integration with InterfaceOptions fallback |

---

## 4. Architecture Pattern

GuildRadioFM uses a **single mixin object** pattern. Every file begins with:

```lua
GuildRadioFM = GuildRadioFM or {}
```

All methods attach to this one table. There is no module registry, no event bus, no namespace separation. Modules communicate by direct method calls on `self`.

This pattern is correct for this scale. It is the standard WoW addon pattern. The risk is that it has no natural seam for growth — adding the ninth window was as easy as adding the first, which means there was no friction preventing the files from growing to their current size.

### Object Model

```
GuildRadioFM (global table)
├── State fields (isPlaying, currentIndex, startedAt, soundHandle, ...)
├── DB reference (self.db → GuildRadioFMDB SavedVariables)
├── Queue reference (self.Queue → self.db.queue)
├── Playback methods (Play, Stop, Next, Back, ...)
├── UI methods (CreateMainWindow, UpdateMainWindow, ToggleMainWindow, ...)
├── Lyrics methods (StartLyrics, GetCurrentLyric, UpdateLyrics, ...)
├── Sharing methods (SendSharingMessage, HandleAddonMessage, ...)
├── Queue methods (AddToQueue, PlayNextInQueue, ...)
├── Seek methods (SeekTo, SeekBy, GetCurrentElapsed, ...)
└── Hidden Frequency methods (TuneFrequency, UnlockHiddenFrequency, ...)
```

---

## 5. Data Architecture

### SavedVariables Schema (GuildRadioFMDB)

```
GuildRadioFMDB = {
    currentIndex          -- number: active song index
    isPlaying             -- bool: playback state
    shuffle               -- bool
    repeat_               -- bool (Lua keyword workaround)
    autoNext              -- bool
    muted                 -- bool
    volume                -- number 0–100
    favorites             -- table: { [songID] = true }
    playlists             -- table: { [name] = { songs = {...} } }
    libraryView           -- string: "all"|"favorites"|"secret"
    queue                 -- table: array of queue entries
    seek                  -- { offset, lastPercent }
    sharing = {
        enabled           -- bool: metadata send toggle
        inbox             -- array: up to 30 received entries
    }
    allowMetadataSharing  -- bool: metadata receive toggle
    hiddenFrequencyUnlocked -- bool: UNUSED (see TD-08)
    profile = {
        debug             -- bool
    }
    -- Window positions and sizes (one entry per window)
    mainFrame_pos, miniFrame_pos, libraryFrame_pos, ...
}
```

**No schema version field.** No migration path if structure changes.

### Song Record

```lua
{
    id       = string,    -- unique identifier
    title    = string,
    artist   = string,    -- optional
    duration = number,    -- seconds, required for auto-advance
    file     = string,    -- Interface\\AddOns\\GuildRadioFM\\Songs\\filename.mp3
    hidden   = bool,      -- optional, gates Secret Frequency display
}
```

### Queue Entry

```lua
{
    songID        = string,
    title         = string,
    artist        = string,
    sourcePlaylist = string,
    file          = string,
}
```

### Sharing Inbox Entry

```lua
{
    kind       = "NOW"|"REQ",
    version    = string,
    title      = string,
    artist     = string,
    file       = string,
    songID     = string,
    channel    = string,
    sender     = string,
    receivedAt = timestamp,
}
```

---

## 6. Notable Technical Decisions

### 6.1 Audio via Dialog Channel
`PlaySoundFile(song.file, "Dialog")` uses WoW's Dialog sound channel. This is the correct choice — Dialog is a distinct channel users can control separately from Music, SFX, and Ambience, avoiding interference with game audio. The returned `soundHandle` is stored for `StopSound()` cleanup.

### 6.2 Duration-Based Auto-Advance
WoW provides no "track finished" event for `PlaySoundFile`. GuildRadioFM schedules a C_Timer tick and compares `GetTime() - startedAt` against `song.duration`. This is the correct approach. The consequence: inaccurate `duration` values in SongList.lua will cause early or late track switching.

### 6.3 Seek Is Display-Only
`SeekTo(seconds)` manipulates `self.startedAt = GetTime() - elapsed`. This shifts the elapsed-time calculation without affecting audio playback. WoW cannot seek inside an in-progress `PlaySoundFile` MP3 stream. The function explicitly prints: *"Seek display moved to X. WoW cannot truly seek inside MP3 playback."*

This is honest, but the UI controls (seek bar, -10/+10 buttons) create a false affordance. A user seeing the bar move will expect the audio to follow.

### 6.4 Build Attribution via Caesar Cipher
Core.lua contains `BUILD_OWNER`, `BUILD_TRACE`, and `BUILD_NOTE` byte arrays where each value is `character - 3`. Decoded with the inline loop `value - 3`. This is obfuscation for authorship attribution, not security. WoW addon Lua is always readable by anyone. The comment acknowledges this explicitly.

### 6.5 Hidden Frequency Is Session-Only by Design
`hiddenFrequencyUnlocked` is reset to `false` on every Initialize call in Core.lua. The flag is also saved to `GuildRadioFMDB` via `UnlockHiddenFrequency()`, but that saved value is never read back — Initialize() always clobbers it. The comment in HiddenFrequency.lua: *"Hidden Frequency is intentionally session-only."* This is a deliberate design choice, not a bug.

### 6.6 Two-Tier Metadata Sharing Opt-In
`sharing.enabled` controls whether metadata is **sent** (defaults to `true`).  
`allowMetadataSharing` controls whether metadata is **received** (defaults to `false`).  
Sending is on by default. Receiving is opt-in. This is a defensible privacy choice but the naming is confusing — "sharing" implies both directions.

### 6.7 Song Pack External API
`RegisterSongPack(pack)` in Core.lua provides a public API for companion addons to inject additional songs. This is a genuine extension point. Format is documented in the AddSongs window. External packs can also call `RegisterLyrics()` to attach synchronized lyrics to any song.

---

## 7. Technical Debt

| ID | Description | Severity | Location |
|----|-------------|----------|----------|
| TD-01 | **Core.lua is 1,042 lines with mixed concerns** — playback, state, playlists, favorites, volume, easter-egg handlers, and RefreshAll orchestration all coexist. Any bug in one area requires reading all of them. | High | Core.lua |
| TD-02 | **UI.lua is 1,547 lines with no component abstraction** — 9 `MakeWindow()` calls, all inline. No shared window base class. Repeated patterns (ApplyPanel, MakeText, MakeButton) are helpers but not encapsulated. | High | UI.lua |
| TD-03 | **No SavedVariables schema version** — if GuildRadioFMDB structure changes, stale saves will be silently misread. No migration, no version check, no safe reset path. | High | Core.lua:Initialize |
| TD-04 | **Seek creates a false affordance** — UI controls imply seekable audio. Audio is not seeked. The print message corrects this at the command level but the UI does not communicate the limitation. | Medium | Core/Seek.lua, UI.lua |
| TD-05 | **`hiddenFrequencyUnlocked` saved but never restored** — the DB key is written on unlock but overwritten by Initialize(). The saved value is dead. Either persist it properly or remove the DB write. | Medium | Core.lua:Initialize, Core/HiddenFrequency.lua |
| TD-06 | **Hidden Frequency playlist has 5 songs with empty `file` fields** — they display as locked but any attempt to play them would fail at Audio.lua with a missing file error. These are content placeholders that could confuse users. | Medium | Core/HiddenFrequency.lua |
| TD-07 | **Split sharing opt-in semantics** — `sharing.enabled` (send) and `allowMetadataSharing` (receive) are named inconsistently and initialized separately, creating a split that is easy to misconfigure. | Low | Core/Sharing.lua |
| TD-08 | **Commands.lua uses flat if/return chain** — 40+ branches evaluated linearly on every command. A dispatch table would be O(1) and easier to extend. | Low | Commands.lua |
| TD-09 | **No isolation between modules** — all methods on one table means a crash in Lyrics can block a Sharing call. pcall guards external WoW APIs but not internal method calls. | Low | Architecture-wide |
| TD-10 | **Duration required but unvalidated** — auto-advance is silent if `song.duration` is 0 or nil. The song just plays forever. No warning is shown to the song author. | Low | Core.lua:HandlePlaybackTick |

---

## 8. Strengths

| Strength | Evidence |
|----------|----------|
| Defensive external API usage | Every C_ChatInfo, PlaySoundFile, StopSound, RegisterAddonMessagePrefix call is wrapped in pcall with nil guards |
| Input sanitization in sharing | CleanField enforces per-field max lengths, strips control characters; SplitMessage rejects oversized payloads and limits field count |
| Dual-direction rate limiting | Sender: 10s rate limit. Receiver: 10s per-sender rate limit + duplicate payload suppression |
| Lyrics system quality | LRC-format parsing, alias resolution, multi-candidate song ID lookup, 200ms refresh throttle |
| Graceful API fallbacks | C_ChatInfo with RegisterAddonMessagePrefix fallback, WoW Settings API with InterfaceOptions fallback, resize-bound fallbacks |
| World transition cleanup | PLAYER_LEAVING_WORLD, PLAYER_LOGOUT, LOADING_SCREEN_ENABLED all stop audio and clear handles |
| Song Pack extensibility | RegisterSongPack() and RegisterLyrics() provide real extension points without requiring core modification |
| Honest seek behavior | SeekTo prints its limitation explicitly; code comment in Seek.lua documents the constraint |
| Hidden Frequency comment | Explicitly states "This is not DRM or real security; WoW addon code can always be inspected" |
| CHANGELOG discipline | Six releases, each scoped and described — shows intentional release management |

---

## 9. Load Order Analysis

```
SongList.lua          -- data only, no dependencies
Core.lua              -- main engine, reads SongList
Core/Lyrics.lua       -- attaches to GuildRadioFM
Core/HiddenFrequency.lua
Core/Queue.lua
Core/Seek.lua
Core/Sharing.lua
Audio.lua             -- called by Core.lua:PlayLocalTrack
UI.lua                -- reads Core state, calls Core methods
Commands.lua          -- entry point, calls everything
```

Load order is **correct**. Data before engine, engine before submodules, submodules before UI, UI before commands. No circular dependencies detected.

---

## 10. WoW API Compliance

| API | Usage | Notes |
|-----|-------|-------|
| PlaySoundFile(file, "Dialog") | Audio.lua | Correct channel choice |
| StopSound(handle) | Audio.lua | pcall guarded |
| C_ChatInfo.RegisterAddonMessagePrefix | Sharing.lua | Fallback to legacy API present |
| C_ChatInfo.SendAddonMessage | Sharing.lua | Fallback to legacy SendAddonMessage |
| CHAT_MSG_ADDON event | Core.lua | Routes to HandleAddonMessage |
| C_Timer.After | Core.lua | Used for auto-advance tick |
| GetTime() | Seek.lua, Lyrics.lua | Correct for frame-relative timing |
| time() | Sharing.lua | Correct for wall-clock inbox timestamps |
| IsInGroup, IsInRaid, IsInGuild | Sharing.lua | Channel selection, correctly ordered |
| UnitName("player") | Sharing.lua | Self-message suppression |

No deprecated or removed APIs detected. All calls include legacy fallbacks where the API changed between expansion cycles.

---

## 11. Scalability Assessment

The current architecture supports the current feature set. The growth limit is visible:

- **Adding a tenth window** to UI.lua would push it past 1,700 lines with no structural boundary to prevent it.
- **Adding a new playback source** (e.g., streaming URL) to Core.lua requires understanding 1,000 lines to find the right insertion point.
- **Adding per-song metadata** requires touching SongList.lua, Core.lua (multiple methods), UI.lua (rendering), and Sharing.lua (payload) with no single abstraction layer to modify.

The addon is **not broken**. It is at the natural inflection point where a refactor would prevent future pain rather than fix present pain.

---

## 12. Recommendations

### 12.1 For v0.7.0 — Before Adding Features

**Split Core.lua into four files:**

| New File | Responsibility |
|----------|---------------|
| Playback.lua | Play, Stop, Next, Back, HandlePlaybackTick, AutoNext |
| State.lua | Initialize, DB schema, Reset, RefreshAll |
| Library.lua | Favorites, Playlists, Library views |
| SongPackAPI.lua | RegisterSongPack, GetSong, GetSongList |

**Split UI.lua into per-window files:**

| New File | Window |
|----------|--------|
| UI/MainWindow.lua | Maxi Player |
| UI/MiniWindow.lua | Mini Player |
| UI/LibraryWindow.lua | Library |
| UI/PlaylistWindow.lua | Playlists |
| UI/QueueWindow.lua | Queue |
| UI/SharingWindow.lua | Sharing Requests |
| UI/SettingsWindow.lua | Settings + Options |
| UI/HiddenFrequencyWindow.lua | Hidden Frequency |
| UI/MinimapButton.lua | Minimap |
| UI/Shared.lua | ApplyPanel, MakeText, MakeButton, helpers |

### 12.2 Add SavedVariables Schema Version

```lua
local CURRENT_DB_VERSION = 1
if not GuildRadioFMDB.dbVersion or GuildRadioFMDB.dbVersion < CURRENT_DB_VERSION then
    -- migrate or wipe
    GuildRadioFMDB.dbVersion = CURRENT_DB_VERSION
end
```

### 12.3 Fix or Remove the Seek Affordance

Option A: Remove the seek bar from UI entirely. Replace with a read-only progress display. Honest.  
Option B: Label the seek controls "Display Only" in the UI with a tooltip explaining the WoW limitation. Informative.  
Option C: Leave it for future companion-app integration (noted in v0.5.0 CHANGELOG as the roadmap intent).

Recommendation: Option B now, Option C if a companion app materializes.

### 12.4 Fix hiddenFrequencyUnlocked Persistence

Either:
- Read `self.db.hiddenFrequencyUnlocked` in Initialize() and skip the reset if it's `true` (make it truly persistent).
- Or remove the `self.db.hiddenFrequencyUnlocked = true` write in UnlockHiddenFrequency() and make no pretense of persistence.

Currently it does neither cleanly.

### 12.5 Replace if/return chain in Commands.lua

```lua
local COMMANDS = {
    play = function(self) self:Play() end,
    stop = function(self) self:Stop() end,
    -- ...
}
local handler = COMMANDS[lower]
if handler then handler(GuildRadioFM) return end
```

---

## 13. Summary Classification

| Category | Assessment |
|----------|-----------|
| Feature completeness | Complete for stated scope |
| Code quality | Good — defensive, consistent, readable |
| Architecture pattern | Correct for current size, at growth limit |
| WoW API compliance | Compliant, with proper fallbacks |
| Release process | Disciplined — six clean changelog entries |
| Test coverage | None (not possible for WoW addons without standalone harness) |
| Documentation | CHANGELOG present, no inline module docs |
| Primary risk | Monolith growth — two files will become unmaintainable |
| Recommended action | Feature freeze + refactor split before v0.7.0 |

---

## 14. File Count and Line Distribution

```
Core.lua              1,042 lines  (28%)
UI.lua                1,547 lines  (42%)
Core/Lyrics.lua         307 lines   (8%)
Core/Sharing.lua        265 lines   (7%)
Core/Queue.lua          142 lines   (4%)
Core/Seek.lua           112 lines   (3%)
Core/HiddenFrequency.lua 115 lines  (3%)
Commands.lua             93 lines   (2%)
Audio.lua                37 lines   (1%)
SongList.lua             ~40 lines  (1%)
──────────────────────────────────────
Total                ~3,700 lines
```

Core.lua + UI.lua = **70% of all code in two files.**  
A healthy split would be no single file above 400 lines.

---

*End of GuildRadioFM Architecture Audit — v0.6.4*
