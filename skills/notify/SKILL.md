---
name: notify
description: Get the user's attention by speaking a short message via TTS and posting a desktop notification. Use when a long-running task finishes, when you need input to continue, or when something needs human attention.
---

# Notify Skill

Use `s say` to alert the user — it speaks via flite TTS and posts a desktop
notification. `s` is the superconfig launcher; it resolves the flake and runs
the tool, so you don't need to know where the checkout lives.

## Usage

```bash
s say "build finished, all tests green"
s say "need your input on the migration plan"
s say                     # default: "Attention requested."
```

## When to use

- A long-running build, test, or deploy just finished — tell the user the
  outcome.
- You hit a question that requires a human decision and can't proceed without
  it.
- An error or unexpected state needs review before you continue.

## When NOT to use

- Routine updates that the user can read in the transcript at their own pace.
- Inside tight loops or after every tool call — the user will tune it out.
- For anything sensitive: the message is spoken aloud and shown on the desktop,
  so don't read out secrets, tokens, or private data.

## Tips

- Keep messages short — one sentence is plenty. flite reads slowly.
- Lead with the outcome ("tests passed", "deploy failed", "need input"), not
  the context.
