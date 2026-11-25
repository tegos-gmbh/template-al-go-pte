
---
name: setup-provider-review
description: >
  Review Business Central AL enum and interface features
  implementing per-value setup using the ISetupProvider pattern.
---

# Setup Provider Pattern Review

Apply this skill when a pull request introduces or changes
enum/interface implementations with per-value setup.

Read the accompanying setup-provider-pattern.txt specification
before reviewing the implementation.

Inspect the enum, interfaces, implementing codeunits,
setup tables, pages, call sites and cleanup logic.

Flag the following violations as Major:

- Missing enum DefaultImplementation to a no-op provider.
- Implementing codeunit does not implement both interfaces.
- EditSetup does not call Commit() before Page.RunModal
  as required by the approved pattern.
- DeleteSetup does not remove the setup record.
- Relevant call sites do not use is/as narrowing.
- Missing orphan cleanup on record deletion.
- Missing orphan cleanup when the enum value changes.

Verify that Commit() is consistent with the intended
transaction design.

Use the accompanying specification as the source of truth.

If the specification or relevant implementations are
unavailable, report the evidence limitation.

Report concrete violations with a failure scenario
and focused AL recommendation.
