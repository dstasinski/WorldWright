# WorldWright Interchange Format

## Purpose

WorldWright will define a public, application-native interchange format so complete projects can be created outside WorldWright and then imported, inspected, played, and edited normally.

A primary use case is generation by AI services, but the format is deliberately provider-independent. Scripts, converters, generators, educational tools, and other applications should be able to produce the same files without access to WorldWright's internal SQLite database.

The interchange format is a public contract around the neutral world model. It is **not** a dump of the database schema and is not tied to Inform 7, TADS 3, or any AI provider.

## Design requirements

The format must be:

- Fully documented and publicly available in the repository.
- Deterministic and machine-readable.
- Human-readable enough to inspect and debug.
- Versioned from its first release.
- Validatable before project data is modified.
- Target-independent.
- Provider-independent.
- Based on stable entity IDs and explicit relationships.
- Capable of representing a complete WorldWright project as the model grows.
- Backward-compatible where practical, with explicit migration when compatibility cannot be preserved.

JSON is the planned serialization unless implementation experience reveals a compelling reason to change it.

## File identity

The exact extension will be chosen before the first importer is implemented. Every document must identify itself as a WorldWright interchange document and declare the specification version it uses.

Conceptual header:

```json
{
  "format": "WorldWright",
  "formatVersion": "1.0",
  "project": {
    "id": "museum_mystery",
    "title": "The Museum Mystery"
  }
}
```

The final schema will define exact field names, types, required values, enumerations, ID rules, escaping, null handling, ordering expectations, and extension behavior.

## Model coverage

As WorldWright gains features, the interchange specification should cover the same neutral concepts, including where applicable:

- project metadata
- regions and rooms
- exits and connections
- objects
- containment and supporters
- doors, locks, and keys
- vocabulary and synonyms
- player/start state
- NPCs and NPC state
- conversations
- variables
- rules, events, conditions, and actions
- puzzles
- relationships
- author notes and metadata
- target-specific advanced source, when intentionally preserved

References between entities must use stable IDs rather than display names.

## Import contract

Import is transactional in intent: WorldWright should validate a document before committing it to a project.

Validation should detect at least:

- unsupported format versions
- malformed documents
- missing required fields
- duplicate IDs
- references to nonexistent IDs
- invalid enum/property values
- impossible or inconsistent relationships
- unsupported required features

An invalid document must produce useful diagnostics rather than silently dropping data or leaving a partially imported project.

Unknown optional extension data may be preserved or ignored according to rules explicitly defined by the specification. Unknown required semantics must not be silently ignored.

## AI-generated projects

An AI service should not need database knowledge or privileged application access to create a WorldWright game. Given the published specification and schema, it should be possible to request a complete project document and import the result.

The intended workflow is:

```text
WorldWright specification/schema
              |
              v
        AI or external tool
              |
              v
     WorldWright interchange file
              |
              v
       validate + import
              |
              v
      neutral live world model
              |
       +------+------+
       |             |
     edit/play      export
```

AI-generated content receives no special trust. It passes through exactly the same validation as files produced by any other external tool.

## Schema

When the model is sufficiently defined, the repository should contain a formal machine-readable schema alongside this document. For JSON, JSON Schema is the preferred starting point.

The schema and prose specification have different roles:

- the schema defines machine-checkable structure and primitive constraints;
- the prose specification defines semantics, relationships, invariants, compatibility behavior, and concepts that cannot be expressed adequately by schema alone.

Versioned example projects should accompany the specification and become part of automated compatibility tests.

## Import and export symmetry

WorldWright should eventually export its own interchange format as well as import it. This enables project interchange, external tooling, reproducible test fixtures, and AI-assisted workflows without exposing SQLite internals.

Round-trip tests should verify that a WorldWright-native project exported to the interchange format and re-imported preserves all representable neutral-model semantics.

This requirement is distinct from importing Inform, TADS, or other third-party source, where lossless round-tripping cannot generally be promised.
