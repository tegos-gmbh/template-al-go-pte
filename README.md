# AL-Go Per Tenant Extension Template

This template repository can be used for managing Per-tenant Extensions (PTEs) for Business Central.

Please go to https://aka.ms/AL-Go to learn more.

## Require AL-Go Copilot reviews before merging

The stock **Copilot PR Review** workflow handles intake. The Tegos runner listens
for its completion, uses the Microsoft ReviewAgent actions, and reports an
**AL-Go Copilot Review** check on the pull request's head commit. The check links
to the runner and succeeds only after the review and publish jobs succeed. It
does not require the review to have no findings.

For an existing repository, update the AL-Go system files using the Tegos
template. The updater reads the repository's existing settings before importing
the new template settings. To replace the existing Microsoft runner in one
update, first copy the `customALGoFiles.filesToExclude` entry for
`CopilotPRReviewRunner.yaml` from the template into the repository's AL-Go
settings. Otherwise, apply the system update again after the new template
settings have landed. If the stock runner is still present, remove that legacy
file in the rollout PR. Keep `CopilotPRReview.yaml` for intake. The Tegos runner
refuses to start a second review while the stock runner is still present.

In a repository using this template, run the workflow on an eligible pull request
first. Then add **AL-Go Copilot Review** (source: **GitHub Actions**) to the required
status checks in the target branch's ruleset or branch protection rule. Do not
require **Intake** as a substitute: it only queues the review. Apply the rule only
to branches where the workflow runs and reviews are enabled for all PRs that
should be mergeable. A missing, pending, cancelled, or failed check blocks merging.

## Contributing

Please read [this](https://github.com/microsoft/AL-Go/blob/main/Scenarios/Contribute.md) description on how to contribute to AL-Go for GitHub.

We do not accept Pull Requests on the template repository directly.
