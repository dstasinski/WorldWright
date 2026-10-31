# WorldWright Command Reference

This document is the maintained reference for commands recognized by WorldWright.

**Maintenance rule:** whenever a player command, alias, builder command, argument
rule, resolution rule, or user-visible command behavior changes, update this file
in the same development change. Tests should cover the recognized syntax where
practical.

## Player commands

Player commands are ordinary input without an `@` prefix. Command verbs and
direction names are case-insensitive.

### LOOK

**Syntax:** `LOOK`  
**Alias:** `L`

Describes the current room, including its room description and objects currently
located there.

Example:

```text
LOOK
```

### Movement

**Syntax:** `NORTH`, `SOUTH`, `EAST`, `WEST`  
**Aliases:** `N`, `S`, `E`, `W`

Moves through the corresponding exit. If no exit exists in that direction,
WorldWright reports that the player cannot go that way. Successful movement
automatically describes the destination room.

### EXAMINE

**Syntax:** `EXAMINE <object>`  
**Alias:** `X <object>`

Examines an object visible to the player. At the current development stage,
visible objects consist of objects in the current room plus objects carried in
player inventory.

Object names are not required to be globally unique. If exactly one visible
object has the requested name, it is examined. If multiple visible objects have
the same name, including one carried object and one same-named room object,
WorldWright reports the ambiguity rather than arbitrarily choosing one. It
presents numbered candidates; entering a number examines that exact object.

Examples:

```text
EXAMINE brass key
X brass key
```

If the object has no authored description, WorldWright reports that there is
nothing special about it.

### TAKE

**Syntax:** `TAKE <object>`  
**Alias:** `GET <object>`

Moves an unambiguous object from the current room into player inventory. If
multiple room objects have the requested name, WorldWright presents numbered
choices and takes nothing until the player chooses one.

### DROP

**Syntax:** `DROP <object>`

Moves an unambiguous carried object into the current room. Object resolution is
limited to player inventory, so a same-named object already lying in the room
does not interfere. If multiple carried objects have the same name, WorldWright
presents numbered choices and drops nothing until the player chooses one.

### INVENTORY

**Syntax:** `INVENTORY`  
**Alias:** `I`

Lists objects currently carried by the player. If none are carried, WorldWright
reports that the player is carrying nothing.

## Builder commands

Builder commands begin with `@`. They modify the same live world being used by
the player session, so changes are immediately visible during play.

Stable entity IDs are generated automatically and remain unchanged when display
names are renamed. IDs are unique across the project and may be used when an
object name would otherwise be ambiguous.

### @ROOM

**Syntax:** `@ROOM <name>`

Creates a room, generates a stable ID, and makes the new room the current room.

Example:

```text
@ROOM Observation Deck
```

### @DESCRIBE

**Syntax:** `@DESCRIBE <description>`

Sets the description of the current room.

Example:

```text
@DESCRIBE Tall windows overlook the city below.
```

### @RENAME

**Syntax:** `@RENAME <name>`

Changes the display name of the current room. Its stable ID does not change.

### @MOVE

**Syntax:** `@MOVE <room>`

Moves the builder/player editing context to an existing room without requiring
an exit. A room may be referenced by display name or stable ID.

### @CONNECT

**Syntax:** `@CONNECT <direction> <room>`

Connects the current room to another room and automatically creates the reverse
cardinal exit.

Supported directions and aliases are `NORTH/N`, `SOUTH/S`, `EAST/E`, and
`WEST/W`.

Example:

```text
@CONNECT SOUTH Laboratory
```

A room cannot be connected to itself.

### @DELETE

**Syntax:** `@DELETE`

Deletes the current room. Objects located in that room and exits pointing to it
are also removed so the model does not retain dangling references. WorldWright
selects another existing room as current before deletion. The last remaining
room cannot be deleted.

### @OBJECT

**Syntax:** `@OBJECT <name>`

Creates an object in the current room and assigns it a globally unique stable
ID.

Example:

```text
@OBJECT brass key
```

### @TAG

**Syntax:** `@TAG <object> <tag>`

Sets the player-facing descriptive noun phrase for an object. The tag normally
omits the indefinite article: write `little brass key`, not `a little brass
key`. WorldWright uses the tag instead of the authoring Name in descriptive
prose and supplies `a` or `an` using its current grammar rule.

The tag remains an exact alternate player reference. For example:

```text
@TAG brass_key little brass key
@TAG apple old apple
```

Room prose can then say `a little brass key` or `an old apple`, while player
commands use the authored tag itself, such as `TAKE little brass key` or
`EXAMINE old apple`. Matching is exact, not fuzzy or partial.

When duplicate display names require a numbered choice, WorldWright shows the
authored tag as the distinguishing noun phrase. If no tag exists, it falls back
to a temporary `name #N` label.

### @DESCRIBEOBJECT

**Syntax:** `@DESCRIBEOBJECT <object> <description>`

Sets the description used by `EXAMINE` for an object in the current room.

The object reference may be its stable ID or its display name. A stable ID
selects the exact object. A name is accepted only when it uniquely identifies
one object in the current room. If the name is ambiguous, WorldWright refuses
to guess and asks the author to use a stable ID.

Example:

```text
@DESCRIBEOBJECT brass_key A small tarnished brass key with an ornate handle.
```

## Object resolution rule

WorldWright's object-command behavior follows this rule:

1. A stable ID identifies exactly one object.
2. An exact authored tag identifies a matching object in the command's
   applicable scope. Tag is a descriptive noun phrase and is not combined with Name.
3. A display name may identify an object when exactly one matching candidate is
   in the command's applicable scope.
4. Multiple matching names are ambiguous; commands must never silently choose
   the first match.
5. For player object commands, WorldWright lists numbered matching candidates.
   Authored tag is shown when available; otherwise temporary
   `name #N` labels are used. WorldWright remembers the pending action. Entering a listed number applies the
   original command to that exact object. Entering another command cancels the
   pending choice and executes the new command normally.
6. Builder commands report ambiguity and allow the author to use the stable ID.
   Stable IDs are not intended to be required knowledge for ordinary players.

This rule is common infrastructure for `EXAMINE`, `TAKE`, `DROP`, builder
object editing, and future commands such as `GIVE`, container interactions,
and GUI editing. EXAMINE resolves against visible objects (current room plus
inventory), TAKE resolves against the current room, and DROP resolves against
player inventory.

## Planned commands

Commands described elsewhere in the roadmap but not listed above are not yet
implemented. In particular, containment, doors, locks, NPC interactions, and richer builder
commands remain future work.
