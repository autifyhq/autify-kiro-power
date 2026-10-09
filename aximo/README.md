# Autify Aximo power for Kiro

Turn a spec task's acceptance criteria into a real end-to-end browser test, run it
against your local or deployed app, and get the verdict, screenshots, and the agent's
own failure reasoning back in the editor.

Aximo tests are natural-language prompts executed by a browser agent. Kiro specs already
hold acceptance criteria in structured form under `.kiro/specs/`, so there is no test
code to generate in between.

## What is in the power

| Path | Purpose |
|---|---|
| `plugin.json` | Agent Plugins 1.0 manifest; `keywords` activate the power |
| `mcp.json` | Starts the Aximo MCP server (`aximo mcp`) from `@autifyhq/aximo-cli` |
| `skills/aximo-setup` | Credentials, project, where tests run, and the hook |
| `skills/aximo-testbox` | A sandboxed browser container Aximo drives instead of your screen: the skill, the `aximo-testbox` script, and the Docker image. A slim fork of the internal hatty testbox; goes away when aximo-cli ships `aximo device testbox` (GEN-3086) |
| `skills/aximo-test-task` | One session per completed task: dispatch, wait, collect |
| `skills/aximo-spec-to-plan` | Whole `requirements.md` into an Aximo plan |
| `hooks/` | The task-complete hook; `aximo-setup` installs it into `.kiro/hooks/` (powers cannot ship hooks) |

## Install

Kiro IDE: Powers panel, **Add Custom Power**, **Import power from a folder**, pick this
`aximo` directory, **Install**. Or **Import power from GitHub** with

```
https://github.com/autifyhq/autify-kiro-power/tree/main/aximo
```

The repository holds one directory per power and no `plugin.json` at its root, so the
bare repository URL does not import.

Requires Node.js 20.18 or newer on the PATH (the MCP server runs via `npx`).

The pinned `@autifyhq/aximo-cli@0.14.0` serves 32 MCP tools, including
`aximo_list_user_devices`, which the skills use to find a local device.
`aximo_create_session` and `aximo_wait_for_session` are not in it yet
(autifyhq/aximo-cli#79); until the pin moves to the release that carries them, the skills
fall back to the saved-case path and to polling `aximo_get_session`.
`aximo_get_credits` is not in it either (GEN-3088), so until the pin moves past the
release that adds it, `aximo-test-task` reports each run's cost without the credits left.

## Authenticate

Aximo uses an organization API key. Run once, in any terminal:

```sh
npx -y @autifyhq/aximo-cli@0.14.0 configure --base-url https://aximo.autify.com --api-key <key>
```

The key is stored in `~/.aximo/config.json` (mode 0600). `AXIMO_API_KEY` in the
environment takes precedence if set. The power's `mcp.json` deliberately sets no `env`:
Kiro passes unapproved `${VAR}` placeholders through as literal text, which would shadow
the config file with a bogus key.

## Test a local app

Aximo's cloud browsers cannot reach `localhost`, so it needs a local device. The safe kind
is a container: one Chrome on a virtual screen, whose `localhost` is your machine's. Aximo
drives that screen, not yours, and you can watch through a live-view link.

Or say "test my local app" and Kiro does this for you. By hand, from the power directory
(`aximo/` in a clone, or the power's install directory once Kiro has imported it):

```sh
AXIMO_TESTBOX_PORTS=3000 skills/aximo-testbox/bin/aximo-testbox up      # first run builds the image
skills/aximo-testbox/bin/aximo-testbox configure                    # reuses ~/.aximo/config.json
skills/aximo-testbox/bin/aximo-testbox setup                        # registers a device, once
skills/aximo-testbox/bin/aximo-testbox connect                      # runs in the background
skills/aximo-testbox/bin/aximo-testbox status
```

Add `AXIMO_TESTBOX_BLOCK_HOSTS=your-prod-domain.com` to make the browser refuse production.
`down` keeps the browser profile and the key. `prune` removes everything.

The box mounts none of your code, has no remote-debugging port, and binds its live view
to 127.0.0.1 with a generated password.

Without Docker, you can register the machine itself with `aximo device setup` and
`aximo device connect`. Aximo then controls your real mouse and keyboard for the length of
each run.

## Try it

In Kiro chat: "test what I just built", or finish a task through Kiro's task runner and
let the hook from set up start it. The skill reads the completed task's `_Requirements_` references,
builds a prompt from those criteria, shows you the criteria and the estimated cost, asks,
runs one Aximo session, and reports PASS/FAIL per criterion with screenshots, the
session link, and the live-view link.

Kiro's terminal version cannot fire hooks. There, start a test by name:
`/aximo-test-task`.

## Privacy and support

- Privacy policy: https://autify.com/privacy
- Support: support@autify.com
- Issues: https://github.com/autifyhq/autify-kiro-power/issues

