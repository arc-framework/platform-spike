# A.R.C. Notifications

Composite action to send notifications via GitHub Issues (Slack support planned).

## Purpose

Centralizes notification logic for A.R.C. CI/CD events:
- Create GitHub Issues for CVEs, failures, alerts
- (Future) Send Slack notifications

## Usage

### Create GitHub Issue for CVE

```yaml
steps:
  - name: Create CVE Issue
    uses: ./.github/actions/arc-notify
    with:
      notification-type: github-issue
      title: 'CRITICAL CVE detected: CVE-2024-1234'
      body: |
        ## Vulnerability Details

        **CVE ID:** CVE-2024-1234
        **Severity:** CRITICAL
        **Package:** openssl
        **Affected Version:** 1.1.1
        **Fixed Version:** 1.1.2

        ## Affected Services
        - arc-sherlock-brain
        - arc-scarlett-voice

        ## Remediation
        Update openssl to version 1.1.2 or later.
      labels: 'security,cve,critical'
      github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Build Failure Notification

```yaml
steps:
  - name: Notify Build Failure
    if: failure()
    uses: ./.github/actions/arc-notify
    with:
      notification-type: github-issue
      title: 'Build failure: arc-sherlock-brain'
      body: |
        ## Build Failed

        The build for `arc-sherlock-brain` failed.

        **Error:** Docker build exited with code 1
        **Step:** Install dependencies

        See workflow run for details.
      labels: 'ci/cd,build-failure'
      github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `notification-type` | Type of notification | Yes | - |
| `title` | Notification title | Yes | - |
| `body` | Notification body (markdown) | Yes | - |
| `labels` | GitHub issue labels | No | `ci/cd,automated` |
| `assignees` | GitHub issue assignees | No | `` |
| `github-token` | GitHub token | No | `${{ github.token }}` |
| `slack-webhook-url` | Slack webhook (future) | No | `` |

## Outputs

| Output | Description |
|--------|-------------|
| `issue-number` | Created GitHub issue number |
| `issue-url` | Created GitHub issue URL |

## Notification Types

### `github-issue`

Creates a GitHub Issue with:
- Title and body from inputs
- Labels for categorization
- Automatic metadata (workflow run, commit, actor)
- Markdown formatting support

### `slack` (Future)

Will send Slack notification via webhook.

## Permissions

Requires `issues: write` permission:

```yaml
permissions:
  issues: write
```

## Example: Security Alert Workflow

```yaml
name: Security Alert

on:
  workflow_run:
    workflows: ["Security Scan"]
    types: [completed]

jobs:
  notify:
    if: ${{ github.event.workflow_run.conclusion == 'failure' }}
    runs-on: ubuntu-latest
    permissions:
      issues: write
    steps:
      - uses: actions/checkout@v4

      - name: Create security alert issue
        uses: ./.github/actions/arc-notify
        with:
          notification-type: github-issue
          title: 'Security scan failed'
          body: |
            The security scan workflow failed.

            Review the [workflow run](${{ github.event.workflow_run.html_url }}) for details.
          labels: 'security,automated'
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Preventing Duplicate Issues

To avoid creating duplicate issues for the same problem:

```yaml
- name: Check for existing issue
  id: check
  run: |
    EXISTING=$(gh issue list --search "CVE-2024-1234 in:title" --json number --limit 1)
    echo "exists=$(echo $EXISTING | jq 'length > 0')" >> $GITHUB_OUTPUT
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

- name: Create issue if not exists
  if: steps.check.outputs.exists != 'true'
  uses: ./.github/actions/arc-notify
  with:
    notification-type: github-issue
    title: 'CVE-2024-1234 detected'
    ...
```
