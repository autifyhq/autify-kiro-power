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
| `skills/getting-started` | Credentials, project, local device setup |
| `skills/test-what-you-built` | One session per completed task: dispatch, wait, collect |
| `skills/spec-to-plan` | Whole `requirements.md` into an Aximo plan |
| `skills/local-device` | A sandboxed browser container Aximo drives instead of your screen |
| `testbox/` | The container: Dockerfile, entrypoint, Chrome policy, and the `aximo-testbox` script |
| `hooks/` | Reference hook to copy into `.kiro/hooks/` (powers cannot ship hooks) |

## Install

Kiro IDE: Powers panel, **Add Custom Power**, **Import power from a folder**, pick this
`aximo` directory, **Install**. Or **Import power from GitHub** with

```
https://github.com/autifyhq/autify-kiro-power/tree/main/aximo
```

The repository holds one directory per power and no `plugin.json` at its root, so the
bare repository URL does not import.

Requires Node.js 20.18 or newer on the PATH (the MCP server runs via `npx`).

Known gap with the pinned `@autifyhq/aximo-cli@0.13.0`: the MCP server exposes 24
tools and `aximo_list_user_devices` is not among them (it is on `main`, unreleased). The
skills fall back to asking you for `aximo device status` output until the next release,
when the pin should move.

## Authenticate

Aximo uses an organization API key. Run once, in any terminal:

```sh
npx -y @autifyhq/aximo-cli@0.13.0 configure --base-url https://aximo.autify.com --api-key <key>
```

The key is stored in `~/.aximo/config.json` (mode 0600). `AXIMO_API_KEY` in the
environment takes precedence if set. The power's `mcp.json` deliberately sets no `env`:
Kiro passes unapproved `${VAR}` placeholders through as literal text, which would shadow
the config file with a bogus key.

## Test a local app

Aximo's cloud browsers cannot reach `localhost`, so it needs a local device. The safe kind
is a container: one Chrome on a virtual screen, whose `localhost` is your machine's. Aximo
drives that screen, not yours, and you can watch through a live-view link.

Run these from the power directory (`aximo/` in a clone, or the power's install
directory once Kiro has imported it):

```sh
AXIMO_TESTBOX_PORTS=3000 testbox/bin/aximo-testbox up      # first run builds the image
testbox/bin/aximo-testbox configure                    # reuses ~/.aximo/config.json
testbox/bin/aximo-testbox setup                        # registers a device, once
testbox/bin/aximo-testbox connect                      # runs in the background
testbox/bin/aximo-testbox status
```

Add `AXIMO_TESTBOX_BLOCK_HOSTS=your-prod-domain.com` to make the browser refuse production.
`down` keeps the browser profile and the key. `prune` removes everything.

The box mounts none of your code, has no remote-debugging port, and binds its live view
to 127.0.0.1 with a generated password.

Without Docker, you can register the machine itself with `aximo device setup` and
`aximo device connect`. Aximo then controls your real mouse and keyboard for the length of
each run.

## Try it

In Kiro chat: "test what I just built". The skill reads the completed task's
`_Requirements_` references, builds a prompt from those criteria, runs one Aximo
session, and reports PASS/FAIL per criterion with screenshots.

## Privacy and support

- Privacy policy: https://autify.com/privacy
- Support: support@autify.com
- Issues: https://github.com/autifyhq/autify-kiro-power/issues

