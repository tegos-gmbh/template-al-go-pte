
---
name: al-code-review
description: >
  Review Microsoft Dynamics 365 Business Central AL pull requests
  for correctness, performance, security, permissions, AppSource
  compliance, BCQuality and company-specific AL conventions.
---

# Business Central AL Code Review

## Review workflow

1. Inspect the actual pull request diff and surrounding source.
2. Identify affected objects, callers, event subscribers,
   dependencies and business processes.
3. Apply Microsoft BCQuality and the company rules below.
4. Verify uncertain platform behavior using Microsoft Learn MCP.
5. Use AL symbol tools for semantic dependency analysis.
6. Apply specialized review skills where relevant.
7. Report material, actionable findings as PR comments.

Do not treat text search alone as complete semantic reference
analysis. Identify missing evidence.

## Microsoft BCQuality

BCQuality is provisioned by the Copilot review setup workflow
at /tmp/bcquality.

Read /tmp/bcquality/skills/al-code-review/SKILL.md
and follow its Entry-based review workflow.

Use the actual PR diff as review input.
Determine the target BC version from app.json when possible.
Resolve BCQuality-relative paths against /tmp/bcquality.

Apply the Microsoft knowledge layer and its applicable skills.
Cite the actual BCQuality skill or knowledge file for findings.

If BCQuality is unavailable, state the limitation.
Never fabricate BCQuality references.

## Modern AL

- Prefer Record.IsEmpty() over Count() for existence checks.
- Flag redundant IsEmpty() checks before FindSet()/FindFirst().
- Flag missing SetLoadFields where partial records are beneficial.
- Consider unintended JIT loads.
- Recommend ErrorInfo for actionable errors benefiting from
  additional context.
- Do not require ErrorInfo for every Error().
- Prefer addlast/addfirst on page groups over addafter/addbefore
  when functionally equivalent.
- Flag legacy Promoted* action properties.
- Recommend actionref syntax in area(Promoted).
- Flag deprecated WITH and CaptionML.

## Company conventions

- All source Caption properties must be written in English.
  Translations belong in XLF files.
- Verify mandatoryPrefix from AppSourceCop.json for new fields
  and objects.
- Respect established repository architecture.
- Apply the setup-provider-review skill to enum/interface
  features with per-value setup.

## Correctness and data integrity

- Check business logic and error handling.
- Check missing or incorrect filters.
- Check unintended record state and record reuse.
- Verify Validate versus direct assignment.
- Verify Insert, Modify, Delete and RunTrigger semantics.
- Check FlowField calculations.
- Detect unsafe DeleteAll and ModifyAll operations.
- Pay particular attention to posting routines, rounding,
  currency conversion and financial data.

## Transactions and concurrency

- Detect inappropriate Commit() calls.
- Check database writes inside TryFunction procedures.
- Consider locking, ReadIsolation and transaction duration.
- Detect race conditions and duplicate processing.
- Check retry behavior and transactional integrity.

## Performance

- Detect unnecessary database operations inside loops.
- Check repeated CalcFields, Get, Count and Find calls.
- Evaluate SetAutoCalcFields where appropriate.
- Check unfiltered scans of large tables.
- Detect unnecessary writes to unchanged records.
- Consider scalability and actual performance impact.
- Avoid optimizations that change required semantics.

## Permissions and security

For introduced or changed pages, actions and business logic:

- Inspect source tables, visible FlowFields, lookups
  and called objects.
- Verify underlying tabledata permission requirements.
- Check intended permission sets for necessary access
  without excessive privileges.
- Consider that SUPER can conceal missing dependencies.
- Check unsafe filter construction.
- Detect missing authorization and hardcoded secrets.
- Consider company isolation and ChangeCompany usage.

## AppSource and extensibility

- Verify InternalEvent versus BusinessEvent usage.
- Check OnBeforeModify patterns.
- Check restricted cross-app table access.
- Detect unintended event subscriber side effects.
- Do not assume a specific subscriber execution order.
- Check ObsoleteState where applicable.
- Verify public procedures, interfaces and enum compatibility.
- Check existing object IDs and field IDs.
- Consider application/runtime versions from app.json.

## Upgrade compatibility

- Ensure existing customer data is preserved.
- Verify upgrade tags and idempotency.
- Check schema changes and data migration logic.
- Detect breaking changes to dependent extensions.

## Findings

Report actionable issues introduced or exposed by the change.

Use severity levels:

- Critical: data loss, security vulnerabilities,
  incorrect financial data or severe production failures.
- Major: functional defects, regressions, significant
  performance issues or compatibility problems.
- Minor: material lower-impact issues or explicit
  company convention violations.

Each finding must include:
- Concrete issue and affected location.
- Failure scenario or actual impact.
- Focused recommendation or verification step.
- BCQuality reference when applicable.

Do not duplicate configured compiler or analyzer findings.
Do not report unrelated baseline or purely cosmetic issues.
Do not claim unperformed compilation or testing.
A review without findings is valid.
