# WorldWright Interchange Format

## Purpose

WorldWright will define a public, application-native interchange format so complete projects can be created outside WorldWright and then imported, inspected, played, and edited normally.

A primary use case is generation by AI services, but the format is deliberately provider-independent. Scripts, converters, generators, educational tools, and other applications should be able to produce the same files without access to WorldWright's internal SQLite database.

The interchange format is a public contract around the neutral world model. It is **not** a dump of the database schema and is not tied to Inform 7, TADS 3, or any AI provider.

## Design requirements

The format must be fully documented, deterministic, machine-readable, reasonably human-readable, versioned from its first release, validatable before project data is modified, target-independent, provider-independent, based on stable entity IDs and explicit relationships, and capable of representing a complete WorldWright project as the model grows.

JSON is the planned serialization unless implementation experience reveals a compelling reason to change it.

## File identity

The exact extension will be chosen before the first importer is implemented. Every document must identify itself as a WorldWright interchange document and declare the specification version it uses.

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

As WorldWright gains features, the specification should cover the same neutral concepts: project metadata; regions and rooms; exits; objects; containment/supporters; doors, locks and keys; vocabulary; player/start state; NPCs; conversations; variables; rules/events/conditions/actions; puzzles; relationships; author metadata; and intentionally preserved target-specific source.

References between entities must use stable IDs rather than display names.

## Import contract

Import is transactional in intent: WorldWright should validate a document before committing it to a project. Validation should detect unsupported versions, malformed documents, missing required fields, duplicate IDs, broken references, invalid values, inconsistent relationships, and unsupported required features.

An invalid document must produce useful diagnostics rather than silently dropping data or leaving a partially imported project. Unknown required semantics must never be silently ignored.

## AI-generated projects

An AI service should not need database knowledge or privileged application access to create a WorldWright game. Given the published specification and schema, it should be possible to request a complete project document and import the result.

AI-generated content receives no special trust. It passes through exactly the same validation as files produced by any other external tool.

## Schema and compatibility

When the model is sufficiently defined, the repository should contain a formal machine-readable schema alongside this document. For JSON, JSON Schema is the preferred starting point. The schema defines machine-checkable structure; the prose specification defines semantics, relationships, invariants, and compatibility behavior.

Versioned example projects should accompany the specification and become automated compatibility tests. Format evolution should be backward-compatible where practical and use explicit migration when compatibility cannot be preserved.

## Import and export symmetry

WorldWright should export its native interchange format as well as import it. Round-trip tests should verify that a native project exported and re-imported preserves all representable neutral-model semantics.

This is distinct from importing Inform, TADS, or other third-party source, where lossless round-tripping cannot generally be promised.
