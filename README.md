# WorldWright

**Build your adventure from the inside.**

WorldWright is a planned cross-platform interactive-fiction authoring environment written in Lazarus/FreePascal.

The central idea is simple: authors should be able to **build a world while playing inside it**. Rooms, objects, exits, NPCs, rules, and other game elements will exist in a live world model that can be manipulated through both player-style commands and authoring tools.

## Project status

WorldWright is currently in the **planning and repository-scaffolding stage**. Active implementation has not begun.

Development work will take place on the `Development` branch. The `main` branch is intended to represent stable milestones/releases once development begins.

## Goals

- Cross-platform application using Lazarus/FreePascal and the LCL.
- Offline-first: normal authoring and play-testing require no Internet connection.
- Build and edit an interactive-fiction world while actively playing it.
- A target-independent internal world model.
- Rooms, exits, objects, containment, inventory, doors, locks, NPCs, conversations, rules, events, puzzles, and variables.
- A parser-based play mode for immediate testing.
- Visual authoring tools that operate on the same live world model.
- SQLite project persistence.
- Export to Inform 7, with TADS 3 support planned as a later exporter.
- Optional future AI assistance for prose refinement and brainstorming through provider-independent integrations such as OpenAI, Anthropic, xAI, or compatible/local services.
- AI assistance must remain optional and must not be required to use WorldWright.

## Core design principle

The world model is the source of truth. Player commands, builder commands, graphical editors, persistence, exporters, and optional AI tools are different interfaces to the same model.

## Platforms

WorldWright is intended for operating systems supported by Lazarus/FreePascal. Initial development and testing are expected to concentrate on Linux and Windows, followed by macOS. Other Lazarus/FPC targets should not be unnecessarily excluded by architectural decisions.

## Documentation

- `docs/ARCHITECTURE.md` — initial architectural boundaries and design principles.
- `docs/ROADMAP.md` — staged development concept.

## License

WorldWright is licensed under the GNU General Public License v3.0. See `LICENSE`.
