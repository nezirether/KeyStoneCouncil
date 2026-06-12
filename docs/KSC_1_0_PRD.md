# Keystone Council 1.0 Product Requirements Document (PRD)

## Product Name

Keystone Council (KSC)

Version Target: 1.0

---

# Mission

Keystone Council exists to solve one problem:

**Help Mythic+ groups decide which key to run next.**

The addon provides a shared pre-dungeon lobby experience where players can view available keys, compare options, vote, randomize, discuss, and select a dungeon before entering.

KSC is not a dungeon gameplay addon.

KSC's responsibility ends when the group decides what key to run.

---

# Product Vision

A Mythic+ group should be able to form, open Keystone Council, choose a key in less than 60 seconds, and enter the dungeon without confusion, spam, or manual coordination.

The addon should become the standard "group lobby" experience for Mythic+ players.

---

# Target Users

## Primary Users

### Guild Groups

Players regularly running Mythic+ with guild members.

Typical behavior:

* Multiple players possess keys
* Group discusses options
* Decision process takes time
* Existing key visibility is fragmented

### Friend Groups

Small recurring groups pushing Mythic+ together.

Typical behavior:

* Same players every week
* Want faster decision making
* Prefer lightweight tools

### Static Push Teams

Dedicated teams optimizing key progression.

Typical behavior:

* Interested in selecting the best available key
* Want objective recommendations
* Need transparency in decision making

---

## Secondary Users

### PUG Leaders

Players forming groups manually.

### Community Event Organizers

Guild officers and community leaders organizing multiple key groups.

---

# Jobs To Be Done

## JTBD 1

"When my group forms, I want to instantly see what keys are available so I do not need to ask everyone manually."

Success:
All visible keys are presented in one place.

---

## JTBD 2

"When multiple keys are available, I want help choosing which key to run."

Success:
The group reaches a decision quickly.

---

## JTBD 3

"When group members disagree, I want a fair way to decide."

Success:
Voting and randomization reduce arguments.

---

## JTBD 4

"When I am the leader, I want to guide the decision without manually tracking everyone's key."

Success:
The addon performs coordination work automatically.

---

## JTBD 5

"When a decision is made, I want everyone in the group to clearly understand the chosen key."

Success:
The result is visible and unambiguous.

---

# Core Product Principles

## Principle 1

KSC is a decision-making addon.

Not a gameplay addon.

---

## Principle 2

KSC is a lobby tool.

Not a dungeon tool.

---

## Principle 3

KSC helps groups decide.

KSC does not tell players how to play.

---

## Principle 4

Every recommendation should be explainable.

Players should understand why a key was selected.

---

## Principle 5

The addon should become more useful as more players use it.

---

# Core Features

## Shared Key Discovery

Display visible keys from:

* Player
* Party
* Guild
* Supported external sources

Outcome:

One unified key list.

---

## Key Browser

Allow players to:

* View available keys
* Sort keys
* Filter keys
* Inspect key details

Outcome:

Faster comparison.

---

## Spin Mode

Randomly select a key from available candidates.

Outcome:

Instant decision.

---

## Raffle Mode

Allow players to vote on keys.

Votes influence selection odds.

Outcome:

Fair weighted decision.

---

## Majority Mode

Select the key with the most votes.

Outcome:

Democratic decision.

---

## Smart Mode

Recommend the best key using available group information.

Outcome:

Decision assistance.

---

## Chaos Mode

Provide fun optional randomization experiences.

Outcome:

Entertainment and replayability.

---

## Result Presentation

Clearly display:

* Winning key
* Owner
* Dungeon
* Level

Outcome:

Everyone understands the decision.

---

## Historical Tracking

Track:

* Previous selections
* Usage trends
* Group history

Outcome:

Useful context and transparency.

---

## Diagnostics

Allow users to verify:

* Addon health
* Sync health
* Integration health

Outcome:

Faster troubleshooting.

---

# Non-Features

The following are explicitly outside the scope of Keystone Council.

## No Dungeon Guidance

No:

* Routes
* Pull plans
* Strategy guides
* Encounter advice

---

## No Combat Assistance

No:

* Rotations
* Cooldowns
* WeakAura replacement
* Boss timers

---

## No Performance Analysis

No:

* Damage meters
* Healing meters
* Ranking systems
* Player grading

---

## No Group Finder

No:

* Recruitment tools
* Applicant evaluation
* Raider.IO replacement

---

## No Raid Systems

No:

* Raid planning
* Raid coordination
* Raid assignments

---

# User Flows

## Flow 1: Quick Spin

1. Group forms.
2. Open KSC.
3. Keys appear.
4. Select Spin Mode.
5. Spin.
6. Winner displayed.
7. Group enters dungeon.

Target time:
Less than 30 seconds.

---

## Flow 2: Group Vote

1. Group forms.
2. Open KSC.
3. Leader starts vote.
4. Players vote.
5. Vote closes.
6. Winner displayed.
7. Group enters dungeon.

Target time:
Less than 2 minutes.

---

## Flow 3: Smart Recommendation

1. Group forms.
2. Open KSC.
3. Smart Mode evaluates available keys.
4. Recommendation displayed.
5. Group accepts recommendation.
6. Group enters dungeon.

Target time:
Less than 1 minute.

---

## Flow 4: Troubleshooting

1. User encounters issue.
2. Run diagnostics.
3. Verify system status.
4. Identify failed component.
5. Correct issue.

Target time:
Less than 5 minutes.

---

# Success Metrics

## User Success Metrics

### Decision Time

Average time from group formation to key selection.

Goal:

Under 60 seconds.

---

### Adoption

Percentage of group members using KSC.

Goal:

Majority adoption within participating guilds.

---

### Usage Frequency

Sessions per active user per week.

Goal:

Used during most Mythic+ sessions.

---

### Decision Completion Rate

Percentage of sessions resulting in a completed selection.

Goal:

Greater than 95%.

---

## Product Health Metrics

### Sync Reliability

Successful sync events.

Goal:

Greater than 99%.

---

### Data Accuracy

Displayed keys match actual keys.

Goal:

Greater than 99%.

---

### Error Rate

Critical addon errors.

Goal:

Near zero.

---

### Diagnostic Pass Rate

Users reporting healthy status.

Goal:

Greater than 95%.

---

# Release Criteria

KSC 1.0 may launch when all criteria are met.

## Functional

* Shared key discovery works
* Key browser works
* Spin Mode works
* Raffle Mode works
* Majority Mode works
* Smart Mode works
* Chaos Mode works
* Result presentation works
* Diagnostics work

---

## Reliability

* No critical startup errors
* No persistent data corruption
* No known sync-breaking bugs
* No critical combat taint issues

---

## Usability

* New user can understand the addon without documentation
* Decision process is intuitive
* Result visibility is clear

---

## Product Integrity

All features support the core mission:

"Help Mythic+ groups decide which key to run next."

Any feature that does not support this mission is excluded from KSC 1.0.

---

# Product Definition

Keystone Council is a Mythic+ key decision platform.

It gathers available keys, helps groups evaluate options, provides structured decision-making tools, and produces a clear selection outcome.

Its responsibility ends when the group decides what key to run.

Once the dungeon begins, Keystone Council gets out of the way.
