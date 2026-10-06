# Contributing

WorldWright is currently in the planning/scaffolding stage.

Development work should target the `Development` branch. Stable milestones may later be merged into `main`.

## Development principles

- Preserve the target-independent world model.
- Keep core logic independent of Lazarus/LCL where practical.
- Avoid unnecessary OS-specific APIs.
- Keep WorldWright fully usable offline.
- Treat Inform 7 and TADS 3 as exporters rather than internal representations.
- Keep optional AI integrations outside the core engine.
- Add tests for core behavior as implementation begins.

## Code documentation requirement

All WorldWright source code must be clearly documented so its functionality and intent can be understood and maintained by another developer without having to reverse-engineer the implementation.

- Each unit should state its purpose and responsibility.
- Important classes, records, interfaces, and public APIs should explain what they represent and how they are intended to be used.
- Public methods and significant internal methods should document behavior, important parameters, return values, side effects, ownership/lifetime expectations, and relevant invariants where these are not self-evident.
- Non-obvious algorithms, parser behavior, rule processing, persistence logic, exporter/importer mappings, and state transitions should explain both what the code does and why the chosen approach is necessary.
- Complex or surprising code should include focused comments near the implementation.
- Comments should explain intent and reasoning rather than merely restating individual Pascal statements.
- Documentation must be kept current when behavior changes. Incorrect or obsolete comments are considered defects.
- Clear names and straightforward code remain preferable to excessive comments; documentation supplements readable code rather than replacing it.

## Build and test policy

Automated compilation and testing for WorldWright will be performed by GitHub Actions once implementation begins.

- ChatGPT should not compile, execute, or run WorldWright tests in its own environment unless the user explicitly requests it.
- Source changes should be pushed to the `Development` branch and validated by GitHub Actions.
- CI should eventually cover the supported Lazarus/FreePascal builds on Linux, Windows, and macOS where practical.
- Use ordinary GitHub-hosted runners; avoid larger/paid runners unless there is a specific future need.
- Keep the CI matrix economical and focused rather than testing unnecessary compiler/platform combinations.
- Interactive GUI and play-testing may still be performed manually by the developer.
- A real CI workflow should be added when the repository contains the initial Lazarus project and meaningful automated tests; no placeholder workflow should consume CI runs before then.

Detailed coding conventions will be added when active development starts.
