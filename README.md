# AL-Go Per Tenant Extension Template

This template repository can be used for managing Per-tenant Extensions (PTEs) for Business Central.

Please go to https://aka.ms/AL-Go to learn more.

## Require AL-Go Copilot reviews before merging

The review runner reports an **AL-Go Copilot Review** check on the pull request's
head commit. The check links to the running workflow and succeeds only after the
review and publish jobs succeed. It does not require the review to have no findings.

In a repository using this template, run the workflow on an eligible pull request
first. Then add **AL-Go Copilot Review** (source: **GitHub Actions**) to the required
status checks in the target branch's ruleset or branch protection rule. Do not
require **Intake** as a substitute: it only queues the review. Apply the rule only
to branches where the workflow runs and reviews are enabled for all PRs that
should be mergeable. A missing, pending, cancelled, or failed check blocks merging.

## Contributing

Please read [this](https://github.com/microsoft/AL-Go/blob/main/Scenarios/Contribute.md) description on how to contribute to AL-Go for GitHub.

We do not accept Pull Requests on the template repository directly.
