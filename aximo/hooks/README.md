# Reference hooks

Kiro does not load hooks shipped inside a power (kirodotdev/Kiro#9007). The
`aximo-setup` skill writes this hook into the workspace's `.kiro/hooks/` during set
up, with Kiro asking the user to confirm the new file. This copy is the reference; copy
it by hand if you skipped set up.

| File | Trigger | What it does |
|---|---|---|
| `aximo-test-on-task-complete.json` | `PostTaskExec` (IDE only) | Asks the agent to run `aximo-test-task` for the task that was just completed. The agent shows the prompt and asks before spending credits. |

Not included on purpose: a `PostFileSave` hook. An Aximo run takes minutes; firing one
per file save would stall the agent loop and burn credits.
