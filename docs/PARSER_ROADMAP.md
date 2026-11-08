# Future roadmap: Parser, Vocabulary, and Action System

**Status: Deferred design proposal. Do not implement until explicitly scheduled.**

WorldWright is an **authoring and testing tool**, not a game-play distribution platform. Its internal play mode exists solely to design, preview, debug, and test games intended for export to **Inform 6, Inform 7, and TADS**. The exported game's target interpreter/runtime is the end-user play platform.

WorldWright should offer a deterministic, offline-first, extensible natural-language parser for authoring and test sessions. Export fidelity is a primary design constraint: favor target-supported semantics and explicitly flag target-specific differences rather than growing a separate proprietary play platform. The player input pipeline should be:

1. Tokenization, vocabulary and grammar recognition.
2. Semantic action and entity resolution.
3. Contextual disambiguation and clarification.
4. World-state validation and neutral rule dispatch.
5. Most-specific applicable response, then graceful fallback.

## Vocabulary architecture

- Built-in vocabulary: standard verbs, common synonyms and grammar.
- Project vocabulary: author-defined verbs, synonyms and phrases.
- Entity vocabulary: object, room and NPC nouns and aliases.
- Store stable entity/action IDs independently of mutable display names.
- Grammar patterns should map multiple phrasings (e.g. TAKE/GET/PICK UP) to a semantic action, without conflating genuinely different intents.
- A typed registry should expose legal argument types and patterns to GUI editors.

## Response and error handling

Prefer object-specific, room-specific, project-specific, library and parser-level responses, in that order where applicable. Distinguish unknown verb, unknown object, ambiguity, missing argument, unsupported action, and action blocked by world state. Recognition of an action must not imply permission or success (e.g. EAT ROCK).

Support multi-turn clarification (USE KEY -> On what? -> CABINET), ordinal/descriptor disambiguation and cautious typo correction; do not silently perform uncertain or destructive corrections.

## Libraries and authoring

Provide reusable action/behavior libraries for standard actions, containers, clothing, conversations, vehicles, senses and social actions. Libraries supply vocabulary, validation and defaults; authored rules override them. Later build dedicated Vocabulary and Actions workspaces for synonyms, typed grammar, default responses and overrides, with designer-managed Lazarus GUI.

A Parser Debugger should show input, recognized action, grammar match, resolved entity IDs, applicable rule, validation result and selected response.

## Export and runtime constraints

- All definitions remain neutral WorldWright model data, not Inform/TADS source.
- **Never use AI for game play**, including interpreting player commands, choosing actions, generating in-game responses, or resolving ambiguity. This applies to both WorldWright test sessions and exported games.
- AI, if offered at all, is restricted to optional authoring assistance (e.g. suggesting vocabulary or prose) and cannot become a runtime dependency.
- WorldWright's internal game session is a design/testing harness only, never a target player platform or substitute for Inform/TADS interpreters.
- Export to Inform 6, Inform 7, and TADS is the product's purpose; their parser and runtime capabilities constrain neutral-model design.
- Exporters map supported semantics into Inform 7 and TADS 3 and report unsupported behavior explicitly rather than silently dropping it.
- Test native and exported behavior for parity.
- Preserve strict authored-vs-runtime-state separation.

## Tentative implementation sequence

1. Neutral vocabulary registry and synonyms.
2. Structured semantic actions and typed grammar patterns.
3. Context-aware entity resolution and disambiguation.
4. Semantic action dispatch and rule execution.
5. Hierarchical customizable failure responses.
6. Reusable action/behavior libraries.
7. Vocabulary and Actions GUI editors and Parser Debugger.
8. Inform 6 / Inform 7 / TADS export support and behavioral parity tests.

**Planning note:** Establish the neutral vocabulary/action model before expanding the Rule Editor deeply, to avoid baking string-expression semantics into its UI. This is an architectural direction, not approval to start coding.
