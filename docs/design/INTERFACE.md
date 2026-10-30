# WorldWright Interface Direction

WorldWright is designed as a **single-window application**.

The application should avoid a collection of independent editor windows. Major authoring tools instead appear as panes, tabs, or workspace views within the main window.

## Lazarus designer requirement

Permanent visual forms and their static controls should be stored as normal Lazarus designer resources (`.lfm`) and be editable with the Lazarus Form Designer.

Pascal source should contain form behavior, event handling, model interaction, and controls that genuinely need to be created dynamically at runtime. It should not manually construct a static form layout when that layout can reasonably be represented in an `.lfm` file.

This is a project maintainability requirement: contributors should be able to open WorldWright in Lazarus, visually inspect a form, move or resize controls, change appropriate properties, and commit the resulting `.lfm` changes without rewriting GUI construction code.

## Baseline layout

The initial shell establishes three primary areas:

1. **World Tree** — navigation through rooms, objects, NPCs, rules, and other project entities.
2. **Main Workspace** — play transcript initially; later this area may host maps, rule editors, conversations, source previews, reports, and other tabbed views.
3. **Property Inspector** — a Lazarus-inspired inspector for the currently selected entity.

The property inspector is a design inspiration rather than a requirement to reuse Lazarus IDE code. Simple scalar properties fit a two-column property grid. Long descriptions, rules, conversations, and other structured data should open richer editors inside the main workspace instead of being forced into tiny grid cells.

Panels should eventually be resizable and collapsible. Play mode may therefore provide an uncluttered transcript while Build mode exposes authoring tools.

## Property inspector target

The current property grid is an implementation foundation, not the intended
finished appearance. The inspector should deliberately resemble the familiar
Lazarus/Delphi Object Inspector while remaining a WorldWright-specific control.

The inspector has two primary tabs: **Properties** and **Events**. Properties
use categorized property/value rows with a user-adjustable divider, clear
read-only styling, and editors appropriate to the value type (text, Boolean,
enumeration, numeric value, object reference, and richer editors where needed).
Long or structured values may open a workspace editor rather than being forced
into a single-line cell.

The Events tab presents neutral WorldWright semantic hooks using the same
property/value visual language. Event values reference WorldWright rules rather
than Pascal methods or target-language source. Double-clicking or otherwise
activating an event should create/open its associated rule in the Rule Editor,
mirroring the productive Lazarus/Delphi event-authoring workflow.

## Architectural rule

The GUI is a view/editor of the same neutral live world model used by parser commands, builder commands, persistence, validation, importers, and exporters. Changing an entity through the inspector and changing it through an @builder command must ultimately use the same model operations.


## Authoring play and world-tree navigation

WorldWright's interactive runtime is primarily part of the **authoring, preview, and debugging workflow**. Authors will not typically be playing their project as a protected attempt to "win." Moving through the world, manipulating objects, and exercising parser commands are ways to inspect and test the work in progress. The interface should therefore favor rapid iteration while still keeping ordinary player semantics distinct from authoring operations.

The World Tree must preserve the distinction between **selection** and **author navigation**:

- A single click selects a room or entity for inspection/editing. Selection alone must not move the player or otherwise mutate runtime state.
- A double click on a room performs an authoring jump to that room.
- A room context menu should eventually expose the same operation as **Go Here**, providing a discoverable alternative to double click.
- A future toolbar or inspector action may expose the same operation if useful.

An authoring jump is not ordinary player movement. It does not require a connecting exit and must allow the author to reach otherwise inaccessible locations, including locations behind locked doors or incomplete world topology. The operation should use the same underlying builder/session operation as the builder room-jump command rather than duplicating navigation logic in the GUI.

As richer rules and events are added, authoring jumps should not automatically acquire ordinary traversal semantics. In particular, jumping to a room should not imply that an exit was traversed, a door was opened, or a movement puzzle was solved. Entry/movement rule execution for author jumps must be an explicit design choice rather than an accidental consequence of sharing player movement code.

This distinction gives WorldWright two complementary navigation paths:

- **Player movement** exercises the authored game and its normal movement rules.
- **Author navigation** rapidly positions the live preview/debug session where the author needs to inspect or modify the world.

The live session remains useful precisely because both paths operate on the same world and runtime state, while their intent and side effects remain clearly separated.
