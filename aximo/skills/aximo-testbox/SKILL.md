---
name: aximo-testbox
description: Set up a sandboxed browser in Docker on this machine that Aximo drives as a local device, so tests of an app on localhost never touch the developer's own screen. Use when the app under test runs on localhost, when the user asks to test a local app safely, or when aximo-setup or aximo-test-task finds no local device online.
metadata:
  author: Autify
  version: "0.2.0"
---

# A local device that is not your screen

Aximo's cloud browsers cannot reach `localhost`. A local device can. But registering the
developer's own laptop means Aximo takes their mouse and keyboard for the whole run. This
skill gives Aximo a container instead: one Chrome on a virtual screen, whose `localhost` is
the developer's `localhost`, with a live view the developer can watch in a browser tab.

**You run every command here with your shell tool.** Do not paste them to the user. The
user answers two questions (yes to the setup, and the port) and nothing else. Every
command is safe to re-run.

## 1. Find the script

It ships in this skill, next to this file: `bin/aximo-testbox`. Resolve it relative to this
`SKILL.md`. If you do not know this file's path:

```sh
BOX=$(ls ~/.kiro/powers/installed/*/skills/aximo-testbox/bin/aximo-testbox 2>/dev/null | head -1)
```

Empty result: ask the user where they imported the power from and use
`<that folder>/skills/aximo-testbox/bin/aximo-testbox`.

## 2. Check Docker

Run `docker info`. If it fails, stop: tell the user Docker Desktop (macOS, Windows) or a
Docker engine (Linux) is needed for the sandboxed device, and hand back to the skill that
sent you here for the fallback (register the laptop itself, or test a deployed URL).

## 3. Ask once

"No test browser is online. Set up the sandboxed one in Docker? The first time builds an
image and takes a couple of minutes. Which port does the app serve on (default 3000)?"

Stop on no and hand back.

## 4. Bring the box up

```sh
AXIMO_TESTBOX_PORTS=<port> $BOX up
```

Show the user the output. It prints a live-view link; give it to them: "This is the browser
Aximo will drive. Open it in a tab to watch." If the user has a production hostname, add
`AXIMO_TESTBOX_BLOCK_HOSTS=app.example.com` so the browser refuses it.

## 5. Give the box the key, register it, connect it

```sh
$BOX configure     # reuses the key from ~/.aximo/config.json
$BOX setup         # registers a device named kiro-<hostname>, once per box
$BOX connect       # runs in the background until `down`; never start a second one
$BOX status        # want: connect running, device online
```

The key lives in a Docker volume, never in the container's environment or the workspace.

## 6. Sign in through the live view, if the app needs it

You cannot type someone's password. If the app has a login screen, ask the user to open the
live-view link, sign in once, and leave the browser on the page tests should start from.
The profile survives `down` and `up`; only `reset` clears it.

## 7. Hand back the device id

Call `aximo_list_user_devices` until the `kiro-<hostname>` device shows `online` (every 10
seconds, up to 2 minutes). Return its `id`: that is the `userDeviceId` for runs. Also hand
the user the live-view link again (`$BOX url`); every run report should carry it.

## Put it away

`$BOX down` stops the box and keeps the profile and key. `$BOX reset` also drops the
profile. `$BOX prune` removes everything, including the device registration and the image.

## What the box does not do

It does not mount the workspace. It has no remote-debugging port. Its live view is bound
to 127.0.0.1 and always has a password. It cannot click anything on the developer's own
screen.
