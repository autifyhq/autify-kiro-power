# Hooks

Kiro doesn't load hooks that ship inside a power (kirodotdev/Kiro#9007). During setup, the
`aximo-setup` skill writes this hook into your workspace's `.kiro/hooks/` directory, and
Kiro asks you to confirm the new file. If you skipped setup, copy the file there yourself.

| File | Trigger | What it does |
|---|---|---|
| `aximo-test-on-task-complete.json` | `PostTaskExec` (Kiro IDE only) | Asks the agent to run `aximo-test-task` for the task that just completed. The agent shows you the test and asks before using any credits. |

There is no hook that runs on file save. An Aximo test takes a few minutes, so running one
on every save would slow the agent down and use credits unnecessarily.
