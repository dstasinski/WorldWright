# WorldWright Roadmap

This roadmap captures the current concept. Dates are intentionally omitted.

## Stage 1 — Playable Builder Prototype

**Goal: Build a small adventure by playing it.**

Rooms/descriptions, exits/movement, basic objects, inventory and containment; player commands such as LOOK, EXAMINE, TAKE, DROP, INVENTORY and directions; builder commands such as @ROOM, @DESCRIBE, @OBJECT, @CONNECT, @MOVE, @RENAME and @DELETE; SQLite persistence; an initial versioned WorldWright-native interchange specification and importer/exporter for the Stage 1 model; simple Lazarus/LCL interface; core tests independent of the GUI.

Success criterion: create, save, reload and play a small multi-room adventure primarily from the command interface. The same Stage 1 world must also be constructible from a validated WorldWright interchange document so external tools and future AI services have a stable, documented entry point from the beginning.

## Stage 2 — Useful World Builder

**Goal: Build a substantial physical world while playing it.**

Containers/supporters, doors/locks/keys, common object properties and states, improved vocabulary/synonyms, pronouns/disambiguation, world tree, property inspector, visual map, undo/redo foundation and project validation foundation.

## Stage 3 — Serious IF Authoring

**Goal: Build complete adventures with puzzles and characters.**

General rules/events, conditions/actions, variables/game state, NPCs, NPC inventory/movement, conversations, puzzles, rich validation/debugging, Inform 7 export, and target-specific advanced-code escape hatches where appropriate.

## Stage 4 — Polished 1.0

**Goal: A distributable authoring environment another author can use without developer assistance.**

Mature project management, autosave/backups/recovery, complete undo/redo, large-world search/navigation, documentation/help, project-format migration, cross-platform packaging, accessibility, improved Inform 7 export, TADS 3 export, and optional provider-independent AI-assisted prose refinement and brainstorming.

## Post-1.0 / Advanced Interchange

**Goal: Bring existing interactive-fiction projects into WorldWright where practical.**

Add source importers for established IF authoring systems, beginning with formats that can be mapped reliably into WorldWright's neutral world model. Inform 7 and TADS 3 are primary candidates; other source formats may be considered later.

Import should be conservative and transparent:

- Recover rooms, connections, objects, containment, properties, descriptions, vocabulary, NPCs and other structural information where mappings are reliable.
- Translate rules, actions, conversations and game state only when their semantics can be represented safely.
- Preserve unsupported or target-specific source where practical rather than silently discarding it.
- Produce an import report listing converted, partially converted and unsupported constructs.
- Never imply that arbitrary Inform/TADS source can be losslessly round-tripped through WorldWright.
- Keep importers separate from the neutral world model so external language syntax does not dictate core architecture.

Importer work should follow mature exporters: generating correct target source will first force WorldWright's model and target mappings to become well understood, making reverse mapping substantially safer.

## Early non-goals

- Reimplement all of Inform or TADS internally.
- Require network services.
- Make AI part of the game engine.
- Use generated target-specific source as the canonical project representation.
- Support every advanced IF construct in the first releases.
- Promise lossless import of arbitrary Inform, TADS, or other third-party source.
