# Autify Aximo power for Kiro

Turn a spec task's acceptance criteria into a real end-to-end browser test, run it
against your local or deployed app, and get the results back in the editor: a verdict for
each criterion, screenshots, and the agent's reasoning for any failure.

Aximo tests are natural-language prompts run by a browser agent. Kiro specs already keep
acceptance criteria in a structured form under `.kiro/specs/`, so the power works from
them directly. You don't need to write or generate any test code.

## What's included

| Path | Purpose |
|---|---|
| `plugin.json` | Power manifest (Agent Plugins 1.0). Its `keywords` tell Kiro when to activate the power |
| `mcp.json` | Starts the Aximo MCP server from `@autifyhq/aximo-cli` |
| `skills/aximo-setup` | Sets up credentials, the Aximo project, where tests run, and the task-complete hook |
| `skills/aximo-testbox` | Runs tests in a sandboxed browser container instead of on your screen |
| `skills/aximo-test-task` | Tests a completed task: starts one Aximo session, waits for it, and reports the results |
| `skills/aximo-spec-to-plan` | Turns a whole `requirements.md` into an Aximo test plan |
| `hooks/` | The task-complete hook. Kiro doesn't load hooks from powers, so `aximo-setup` installs it into `.kiro/hooks/` for you |

## Requirements

- Kiro IDE
- Node.js 20.18 or newer on your `PATH` (the MCP server runs through `npx`)
- An Aximo organization API key
- Docker, if you want to test an app running on your machine (see [Test a local app](#test-a-local-app))

## Install

1. In Kiro, open the **Powers** panel and choose **Add Custom Power**.
2. Choose **Import power from GitHub** and paste:

   ```
   https://github.com/autifyhq/autify-kiro-power/tree/main/aximo
   ```

3. Click **Install**.

To install from a local copy instead, clone the `main` branch and choose
**Import power from a folder** with the `aximo` directory:

```sh
git clone --branch main https://github.com/autifyhq/autify-kiro-power.git
```

## Authenticate

Run this once in any terminal, with your organization API key:

```sh
npx -y @autifyhq/aximo-cli@0.17.0 configure --base-url https://aximo.autify.com --api-key <key>
```

The key is saved to `~/.aximo/config.json`, readable only by your user. If `AXIMO_API_KEY`
is set in your environment, it takes precedence.

Keep the key out of the power's `mcp.json`. Kiro passes unapproved `${VAR}` placeholders
through as literal text, which would override your saved key with an invalid one.

## Test a local app

Aximo's cloud browsers can't reach `localhost`. To test an app running on your machine,
use the testbox: a Docker container with its own Chrome on a virtual screen, where
`localhost` points to your machine. Aximo drives the testbox instead of your screen, and
you can watch each run through a live-view link.

The easiest way is to ask Kiro to "test my local app", and the power starts the testbox
for you. To manage it yourself:

```sh
npx -y @autifyhq/aximo-cli@0.17.0 device testbox up --ports 3000   # first run pulls the image, then registers and connects
npx -y @autifyhq/aximo-cli@0.17.0 device testbox status
npx -y @autifyhq/aximo-cli@0.17.0 device testbox down               # stops it, keeping the browser profile and registration
npx -y @autifyhq/aximo-cli@0.17.0 device testbox prune              # removes everything, including the device registration
```

To keep tests away from production, add `--block-hosts your-prod-domain.com` and the
browser will refuse to open that domain.

The testbox is isolated from your machine:

- It doesn't mount any of your code.
- It exposes no remote-debugging port.
- Its live view listens only on `127.0.0.1` and is protected by a generated password.
- It never receives your API key, only a token scoped to that one device.

If you can't use Docker, you can register your own machine with `aximo device setup` and
`aximo device connect`. Aximo then controls your mouse and keyboard while each test runs.

## Try it

In Kiro chat, say "test what I just built". Or complete a task with Kiro's task runner and
let the hook installed during setup start the test.

The power reads the completed task's `_Requirements_` references and builds a test from
those criteria. Before running, it shows you the criteria and the estimated cost and asks
for confirmation. When the run finishes, you get PASS or FAIL for each criterion, with
screenshots, a link to the session, and the live-view link.

Kiro CLI doesn't run hooks. There, start a test with `/aximo-test-task`.

## License

Apache License 2.0. See [`LICENSE`](LICENSE).

## Privacy and support

- Privacy policy: https://autify.com/privacy
- Support: support@autify.com
- Issues: https://github.com/autifyhq/autify-kiro-power/issues
