# Reference hooks

Kiro does not load hooks shipped inside a power (kirodotdev/Kiro#9007). Copy the file
you want into your workspace's `.kiro/hooks/` directory. Kiro asks for confirmation on
every write under `.kiro/hooks/`, which is expected.

| File | Trigger | What it does |
|---|---|---|
| `aximo-test-on-task-complete.json` | `PostTaskExec` (IDE only) | Asks the agent to run `test-what-you-built` for the task that was just completed. The agent shows the prompt and asks before spending credits. |

Not included on purpose: a `PostFileSave` hook. An Aximo run takes minutes; firing one
per file save would stall the agent loop and burn credits.
