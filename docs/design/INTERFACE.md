# WorldWright Interface Direction

WorldWright is designed as a **single-window application**.

The application should avoid a collection of independent editor windows. Major
authoring tools instead appear as panes, tabs, or workspace views within the
main window.

## Baseline layout

The initial shell establishes three primary areas:

1. **World Tree** — navigation through rooms, objects, NPCs, rules, and other
   project entities.
2. **Main Workspace** — play transcript initially; later this area may host
   maps, rule editors, conversations, source previews, reports, and other
   tabbed views.
3. **Property Inspector** — a Lazarus-inspired inspector for the currently
   selected entity.

The property inspector is a design inspiration rather than a requirement to
reuse Lazarus IDE code. Simple scalar properties fit a two-column property
grid. Long descriptions, rules, conversations, and other structured data
should open richer editors inside the main workspace instead of being forced
into tiny grid cells.

Panels should eventually be resizable and collapsible. Play mode may therefore
provide an uncluttered transcript while Build mode exposes authoring tools.

## Architectural rule

The GUI is a view/editor of the same neutral live world model used by parser
commands, builder commands, persistence, validation, importers, and exporters.
Changing an entity through the inspector and changing it through an @builder
command must ultimately use the same model operations.
