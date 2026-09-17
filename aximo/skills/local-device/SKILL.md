---
name: local-device
description: Set up a sandboxed browser on this machine that Aximo drives as a local device, so tests of an app on localhost never touch the developer's own screen. Use when the app under test runs on localhost, when the user asks to test a local app safely, or when getting-started finds Docker and no online device.
metadata:
  author: Autify
  version: "0.1.0"
---

# A local device that is not your screen

Aximo's cloud browsers cannot reach `localhost`. A local device can. But registering the
developer's own laptop means Aximo takes their mouse and keyboard for the whole run. This
skill gives Aximo a container instead: one Chrome on a virtual screen, whose `localhost` is
the developer's `localhost`, with a live view the developer can watch in a browser tab.

The script lives in this power at `testbox/bin/aximo-testbox`. Resolve it relative to the
power's install directory and call it as `$BOX` below. Every command is safe to re-run.

## 1. Check Docker

Run `docker info`. If it fails, tell the user Docker Desktop (macOS, Windows) or a Docker
engine (Linux) is needed for the sandboxed device, and offer the fallback: register the
laptop itself (see `getting-started` Step 4) or test a deployed URL.

## 2. Bring the box up

Ask which port the app serves on (default 3000). Then:

```sh
AXIMO_TESTBOX_PORTS=3000 $BOX up
```

First run builds the image and takes a few minutes. It prints a live-view link. Give that
link to the user and say: "This is the browser Aximo will drive. Open it in a tab to watch."

If the user has a production hostname, pass it so the browser refuses it:

```sh
AXIMO_TESTBOX_PORTS=3000 AXIMO_TESTBOX_BLOCK_HOSTS=app.example.com $BOX up
```

## 3. Give the box the API key

```sh
$BOX configure
```

It reuses the key from `~/.aximo/config.json` when `getting-started` has already written
one. Otherwise it prompts inside the box. The key is stored in a Docker volume, never in the
container's environment and never in the workspace.

## 4. Register and connect, once per box

```sh
$BOX setup            # registers a device named kiro-<hostname>
$BOX connect          # starts the connection in the background
$BOX status           # shows: connect running, device online
```

`connect` keeps running until `down`. Do not start a second one.

## 5. Sign in through the live view, if the app needs it

You cannot type someone's password. If the app has a login screen, ask the user to open
the live-view link, sign in once, and leave the browser on the page the test should start
from. The profile persists across `down` and `up`, so this is once per box, not once per
run. Only `reset` clears it.

## 6. Use it

`aximo_list_user_devices` (or `$BOX status`) now shows the device online. Pass its `id` as
`userDeviceId` in `test-what-you-built` or `spec-to-plan`. When a run starts, hand the user
both links: the Aximo session page and the live view. Put the URL in the prompt body; the
start URL is not opened for you on a local device.

## Put it away

`$BOX down` keeps the profile and the key. `$BOX reset` also drops the profile. `$BOX prune`
removes everything, including the device registration and the image.

## What the box does not do

It does not mount the workspace. It has no remote-debugging port. Its live view is bound
to 127.0.0.1 and always has a password. It cannot click anything on the developer's own
screen.
