---
name: commit
description: Use when the user asks Codex to commit staged changes, optionally with a rationale or message guidance, using the repository's conventional commit style.
---

# Commit Staged Changes

Commit only the changes that are already staged.

## Workflow

1. Inspect the staged change set:

   ```bash
   git status --short
   git diff --cached --stat
   git diff --cached
   ```

1. If nothing is staged, stop and tell the user there are no staged changes to commit.

1. Draft a concise conventional commit message:

   - Format: `<type>(<scope>): <subject>`
   - Use the repository's allowed types from `AGENTS.md`.
   - Include a body when it helps explain motivation or summarize multiple changes.
   - In the generated commit message, wrap long body paragraphs or bullets onto continuation lines so each commit-message body line is 72 characters or fewer.
   - If the user supplied a rationale, incorporate it as the "why".
   - Describe the concept-level purpose and list meaningful included changes.
   - Do not describe the iterative workflow of implementation, review, or revision.

1. Run `git commit` with the drafted message.

1. Report the resulting commit hash and subject.

## Message Shape

Use this shape when a body is warranted:

```text
<type>(<scope>): <subject>

<why this change is being made, wrapping long text onto continuation lines>

- <included change, wrapping long text onto continuation lines>
- <included change>
```

For very small changes, a one-line conventional commit is acceptable. In the generated commit message, body paragraphs and bullets may contain more than 72 characters of content, but split them across multiple commit-message lines so no individual body line exceeds 72 characters.
