# WorldWright Roadmap

This roadmap captures the current concept. Dates are intentionally omitted.

## Stage 1 — Playable Builder Prototype

**Goal: Build a small adventure by playing it.**

Rooms/descriptions, exits/movement, basic objects, inventory and containment; player commands such as LOOK, EXAMINE, TAKE, DROP, INVENTORY and directions; builder commands such as @ROOM, @DESCRIBE, @OBJECT, @CONNECT, @MOVE, @RENAME and @DELETE; SQLite persistence; simple Lazarus/LCL interface; core tests independent of the GUI.

Success criterion: create, save, reload and play a small multi-room adventure primarily from the command interface.

## Stage 2 — Useful World Builder

**Goal: Build a substantial physical world while playing it.**

Containers/supporters, doors/locks/keys, common object properties and states, improved vocabulary/synonyms, pronouns/disambiguation, world tree, property inspector, visual map, undo/redo foundation and project validation foundation.

## Stage 3 — Serious IF Authoring

**Goal: Build complete adventures with puzzles and characters.**

General rules/events, conditions/actions, variables/game state, NPCs, NPC inventory/movement, conversations, puzzles, rich validation/debugging, Inform 7 export, and target-specific advanced-code escape hatches where appropriate.

## Stage 4 — Polished 1.0

**Goal: A distributable authoring environment another author can use without developer assistance.**

Mature project management, autosave/backups/recovery, complete undo/redo, large-world search/navigation, documentation/help, project-format migration, cross-platform packaging, accessibility, improved Inform 7 export, TADS 3 export, and optional provider-independent AI-assisted prose refinement and brainstorming.

## Early non-goals

- Reimplement all of Inform or TADS internally.
- Require network services.
- Make AI part of the game engine.
- Use generated target-specific source as the canonical project representation.
- Support every advanced IF construct in the first releases.
