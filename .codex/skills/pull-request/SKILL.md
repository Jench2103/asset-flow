---
name: pull-request
description: Use when the user asks Codex to write or update a pull request description for the current branch, optionally naming a target branch or providing PR context.
---

# Write Pull Request Description

Create `PR_DESCRIPTION.md` in the repository root for merging the current branch into a target branch.

## Inputs

- Target branch: use the branch named by the user; default to `main`.
- Context: incorporate any rationale, caveats, or background the user provides.

## Workflow

1. Determine and verify the target branch:

   ```bash
   git rev-parse --verify <target-branch>
   ```

   If the branch is missing, stop and report the issue.

1. Gather branch information:

   ```bash
   git branch --show-current
   git log <target-branch>..HEAD --oneline
   git diff <target-branch>...HEAD --stat
   git diff <target-branch>...HEAD
   ```

1. Analyze the changes:

   - Identify the main goal and user-visible impact.
   - Group related changes into logical categories.
   - Note breaking changes, migrations, dependency changes, or configuration changes.
   - Capture key implementation decisions when they matter to reviewers.
   - Include the user's additional context as motivation when provided.

1. Write `PR_DESCRIPTION.md` with the format below.

1. Keep the description concise but comprehensive. Focus on what changed and why, not every file touched.

## Format

```markdown
# <PR title in conventional commit style>

## Summary

<1-3 sentences describing the purpose and impact. Mention the target branch if it is not main.>

## Changes

- **<Category>**
  - <Change description>
  - <Change description>

- **<Category>**
  - <Change description>

## Testing

<How the changes were tested, or what should be tested.>

## Notes

<Additional context, caveats, migrations, or follow-up items. Omit this section if not applicable.>
```
