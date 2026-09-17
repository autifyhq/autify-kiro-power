---
name: getting-started
description: Set up Autify Aximo for this workspace. Use when the user installs the Aximo power, asks how to connect Aximo, hits an "Unauthorized" or "No API key configured" error from an aximo tool, or wants to register their machine as a local test device.
metadata:
  author: Autify
  version: "0.1.0"
---

# Getting started with Aximo

Aximo runs end-to-end tests from a natural-language prompt. There is no test code to
generate: an acceptance criterion is already a runnable test. This skill gets the
workspace to the point where `test-what-you-built` can dispatch a run.

## Step 1: Confirm the MCP server is up

Call `aximo_list_projects`.

- Success: note the project list and continue to Step 3.
- Error mentioning `Unauthorized` or `No API key configured`: go to Step 2.
- The `aximo` server is missing from the tool list: the server refuses to start without a
  key. Do Step 2 first, then ask the user to reload the power (Powers panel, Aximo, Reload).

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
3. Reload the Aximo power in Kiro so the MCP server restarts.

Then call `aximo_list_projects` again to verify. Do not ask the user to paste the key into
chat and do not write it into any file in the workspace.

## Step 3: Pick a project

If the organization has one project, use it. Otherwise ask which project Kiro should file
runs under and remember the `projectId` for the rest of the session.

## Step 4: Decide where tests run

Ask the user one question: "Is the app under test reachable from the internet, or only on
this machine?"

- **Reachable (staging, preview URL):** nothing else to set up. Aximo's cloud browsers
  will open the URL directly.
- **Local only (`http://localhost:...`):** Aximo needs a local device. There are two
  kinds. Prefer the first.

  1. **A sandboxed browser in a container** (needs Docker). Aximo drives a Chrome on a
     virtual screen whose `localhost` is this machine's. The developer keeps their own
     mouse, keyboard, and screen, and can watch the run through a live-view link. Run
     `docker info`; if it works, switch to the `local-device` skill and come back here
     when it reports the device online.
  2. **This machine itself** (no Docker). Aximo takes over the real screen for the length
     of each run. Call `aximo_list_user_devices`. If that tool is not in your tool list
     (aximo-cli 0.13.0 ships without it), ask the user to run
     `npx -y @autifyhq/aximo-cli device status` and paste the output.
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

## Step 5: Optional hooks

Hooks are not loaded from a power. If the user wants a run to start automatically when a
spec task is marked complete, copy `hooks/aximo-test-on-task-complete.json` from this
power into `.kiro/hooks/` (Kiro will ask for confirmation, that is expected). Explain
that each hook-triggered run spends Aximo credits and Kiro credits, and that the hook
only fires from the Kiro IDE task runner.

## Done

Summarise: project, target URL type, device kind (sandboxed, this machine, or none), and that `test-what-you-built`
is ready to use with "test what I just built" or `/test-what-you-built`.
