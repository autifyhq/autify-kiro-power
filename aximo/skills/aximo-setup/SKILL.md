---
name: aximo-setup
description: Set up Autify Aximo for this workspace. Use when the user installs the Aximo power, asks how to connect Aximo, hits an "Unauthorized" or "API key not configured" error from an aximo tool, asks to test a local app or an app on localhost, or wants a local test device.
metadata:
  author: Autify
  version: "0.2.0"
---

# Getting started with Aximo

Aximo runs end-to-end tests from a natural-language prompt. There is no test code to
generate: an acceptance criterion is already a runnable test. This skill gets the
workspace to the point where `aximo-test-task` can dispatch a run.

## Step 1: Confirm the MCP server is up

Call `aximo_list_projects`.

- Success: note the project list and continue to Step 3.
- Error `API key not configured` or `Unauthorized`: go to Step 2. The server starts
  without a key and every tool answers with this error until one is set.
- No `aximo_*` tools at all: the power did not load. Ask the user to reload it (Powers
  panel, Aximo, Reload) and check Kiro's MCP log for the `aximo mcp` line.

## Step 2: Configure credentials

Aximo authenticates with an organization API key sent as `x-api-key`. The MCP server reads
it from `AXIMO_API_KEY` in the environment, then from `~/.aximo/config.json`.

Prefer the config file. GUI editors launched from the Dock or Start menu do not inherit
shell exports, so an env var set in `.zshrc` is often invisible to Kiro.

Tell the user, verbatim:

1. Create an API key in Aximo: Settings, API Keys, New key. Copy it once.
2. In any terminal run:

   ```sh
   npx -y @autifyhq/aximo-cli@0.13.0 configure --base-url https://aximo.autify.com --api-key <paste key>
   ```

   Sandbox or on-prem users pass their own base URL.

Then call `aximo_list_projects` again to verify. No reload: the server reads the key on
every call. Do not ask the user to paste the key into
chat and do not write it into any file in the workspace.

## Step 3: Pick a project

If the organization has one project, use it. Otherwise ask which project Kiro should file
runs under and remember the `projectId` for the rest of the session.

## Step 4: Decide where tests run

Ask the user one question: "Is the app under test reachable from the internet, or only on
this machine?"

**Reachable (staging, preview URL):** nothing else to set up. Aximo's cloud browsers open
the URL directly. Skip to Step 5.

**Local only (`http://localhost:...`):** Aximo's cloud browsers cannot reach `localhost`,
so it needs a local device. Prefer the sandboxed browser; fall back to the machine itself.

### 4a. A sandboxed browser in a container (needs Docker)

Load the `aximo-testbox` skill now and do all of its steps. It checks Docker, asks the user
once, brings up the container, registers it as a device, and hands back a `userDeviceId`
and a live-view link. Remember both. If it hands back because Docker is missing or the
user said no, go to 4b.

### 4b. This machine itself (no Docker)

Aximo takes over the real screen for the length of each run. This is the one step where
the user runs the commands, because `device connect` has to stay open in their own
terminal. Call `aximo_list_user_devices`.

- A desktop device with `status: "online"` exists: remember its `id`.
- None: tell the user, verbatim:

  > Register this machine as a local test device and keep the connection open in a
  > separate terminal:
  >
  > ```sh
  > npx -y @autifyhq/aximo-cli@0.13.0 device setup --name "$(hostname)"
  > npx -y @autifyhq/aximo-cli@0.13.0 device connect
  > ```
  >
  > First run downloads a small Python runtime. On macOS, grant Accessibility and
  > Screen Recording to your terminal when prompted. While a test is running, Aximo
  > controls this machine's mouse and keyboard, so leave the screen unlocked and
  > hands off until it reports back.

If any device call returns a 403 about `byodEnabled`, local devices are switched off
for the organization. Tell the user an Aximo org admin must enable "Local devices", and
fall back to a reachable URL.

## Step 5: Install the hook

Kiro does not load hooks from a power, so install it into the workspace yourself. Do not
ask the user to copy files. If `.kiro/hooks/aximo-test-on-task-complete.json` does not
exist, tell the user "I'll add a hook so finishing a spec task offers an Aximo test; Kiro
will ask you to confirm the new file", then write it with exactly this content:

```json
{
  "version": "v1",
  "hooks": [
    {
      "name": "Aximo: test the completed task",
      "description": "When a spec task is marked complete, run its acceptance criteria as an Aximo end-to-end test.",
      "trigger": "PostTaskExec",
      "action": {
        "type": "agent",
        "prompt": "A spec task was just marked complete. Use the aximo-test-task skill: find the task that just changed to [x] in .kiro/specs/*/tasks.md, collect its acceptance criteria, show me the criteria, the target, and the estimated cost, and ask before dispatching. One session for this task only."
      }
    }
  ]
}
```

Then say what it does in one line: finishing a task through Kiro's task runner starts
`aximo-test-task`, which always shows the cost and asks before spending anything.
The hook fires only in the Kiro IDE; in Kiro's terminal version the user starts a test by
saying "test what I built" or `/aximo-test-task`. If the user does not want the hook,
`enabled: false` in that file keeps it without running it.

## Done

Summarise: project, target URL type, device kind (sandboxed, this machine, or none), and that `aximo-test-task`
is ready to use with "test what I just built" or `/aximo-test-task`.
