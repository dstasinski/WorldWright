# WorldWright Architecture

This document records the initial architectural direction. It is expected to evolve before and during implementation.

## Guiding principles

1. **Build while playing.** Authored definitions are immediately visible to play-testing, while player actions mutate only disposable runtime state.
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

## Authored state and play-test state

WorldWright strictly separates the project's **authored initial state** from a
temporary **runtime test state**. The project model is the source of truth for
what a newly started game contains: initial object locations, initial door and
container states, initial variable values, NPC starting locations, and similar
definitions. Player actions such as TAKE, DROP, OPEN, movement, conversations,
and puzzle solving must never rewrite those authored initial values.

A `TGameSession` creates runtime state from the authored model. Runtime state
records the player's current location and the current mutable state of objects,
NPCs, variables, and other stateful systems. Restarting a test discards that
state and creates a pristine session from the project definitions.

Builder operations and inspector edits modify authored definitions. Ordinary
player commands modify runtime state. Author navigation may reposition the
test session for debugging but does not silently rewrite the project's starting
conditions.

Exporters consume only authored project definitions and initial values. They
must never serialize a `TGameSession` or infer initial state from the author's
current test position. Therefore an exported game always starts pristine even
when the author exports in the middle of a heavily modified play test.

A future explicit **Apply Current Test State to Initial World** operation may
allow authors to promote selected runtime values into project definitions. Such
promotion must be deliberate and reviewable; it is never an automatic side
effect of testing.

## Events and rules

WorldWright uses a Lazarus/Delphi-inspired event authoring metaphor while keeping
game semantics target-independent. An event is a semantic hook that references
a WorldWright rule; it is not a Pascal method and does not contain Inform 7 or
TADS 3 source code.

Examples include room lifecycle hooks such as `OnEnter` and `OnExit`, and
object/action hooks such as Take, Drop, Examine, or Use. The authoring UI may
present these in an Events category similar to the Lazarus/Delphi Object
Inspector. Activating an event should eventually open the associated Rule
Editor.

The model must not grow a fixed field for every possible verb. A small,
well-defined set of lifecycle hooks may be modeled directly where appropriate,
while action reactions use an extensible action-to-rule relationship. This
allows built-in and future custom actions without continually changing every
world entity class.

Rules themselves remain neutral WorldWright data. They should eventually
represent conditions and effects such as displaying text, changing variables,
moving entities, or invoking other rules. The WorldWright engine executes those
semantics directly during author testing. Exporters translate the same semantics
into the closest correct Inform 7 or TADS 3 constructs.

This preserves the dependency direction:

```text
Property/Rule Editors
        |
        v
Neutral Events -> Neutral Rules -> WorldWright Engine
                       |
                       +---------> Inform 7 Exporter
                       +---------> TADS 3 Exporter
```

Target-specific escape hatches may be considered later for semantics that
cannot be represented neutrally, but they must remain explicit exceptions and
must never become the primary event representation.

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
