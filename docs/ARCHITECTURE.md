# WorldWright Architecture

This document records the initial architectural direction. It is expected to evolve before and during implementation.

## Guiding principles

1. **Build while playing.** Authoring and play-testing operate on the same live world.
2. **One world model.** The internal model, not generated Inform/TADS source, is the source of truth.
3. **Target independence.** Inform 7 and TADS 3 are export targets, not the internal representation.
4. **Offline first.** Core functionality must never require an Internet connection.
5. **Cross-platform first.** Prefer FreePascal RTL/FCL and Lazarus LCL over platform-specific APIs.
6. **Separation of concerns.** Core, parser, engine, builder, persistence, GUI, exporters, and optional services remain separated.
7. **AI is optional.** Future AI providers may suggest content but must not become a dependency of the world engine.
8. **Single-window interface.** WorldWright should present authoring, play, inspection, mapping, rules, conversations, reports, and related tools within one main application window using panes and workspace views rather than a collection of independent editor windows.

## Planned modules

### Core
Target-independent project/world model: rooms, objects, exits, containment, doors, NPCs, properties, variables, rules and identifiers.

### Engine
Runs the live world: player location, scope/visibility, movement, inventory, actions, state changes and rule processing.

### Parser
Converts player input into actions. Eventually includes vocabulary, synonyms, adjectives, pronouns and disambiguation.

### Builder
Author commands such as `@ROOM`, `@OBJECT`, `@DESCRIBE`, `@CONNECT`, `@MOVE`, `@PROPERTY`, `@RULE` and `@UNDO`. Builder operations modify the same world model used by the running engine.

### Persistence
Stores/restores projects. SQLite is the planned primary storage mechanism. Persistence must not define game semantics.

### GUI
Lazarus/LCL application layer built around one main window: playable interface, world tree, Lazarus-inspired property inspector, map, rule editor, NPC/conversation tools, project management and validation UI. Complex editors should appear as panes or workspace views inside the main window rather than separate top-level windows.

### Exporters
Target-specific generators. Initial target: Inform 7. Planned later target: TADS 3. Exporters consume the neutral world model and must not dictate its design.

### AI
Optional provider-independent assistance layer. Possible future providers include OpenAI, Anthropic, xAI and local/compatible services. Suggestions should be proposals presented to the author, not direct unreviewed mutations of project data.

## Dependency direction

```text
GUI -----------+
Builder -------+----> Core <---- Persistence
Parser -> Engine ----> |
                       +----> Exporters
                       +----> Optional AI context/services
```

Exact package/unit boundaries will be refined as implementation proceeds.

## Testing

Core logic should be testable without starting the GUI. Console/unit tests should cover the world model, parser, engine, builder operations, persistence and exporters.

Automated compilation and tests run through GitHub Actions. ChatGPT does not compile or execute WorldWright in its own environment unless explicitly requested.

Cross-platform behavior should be considered from the first implementation commit.
