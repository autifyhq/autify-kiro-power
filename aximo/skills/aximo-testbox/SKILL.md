---
name: aximo-testbox
description: Bring up a sandboxed browser in Docker on this machine that Aximo drives as a local device, so tests of an app on localhost never touch the developer's own screen. Use when the app under test runs on localhost, when the user asks to test a local app safely, or when aximo-setup or aximo-test-task finds no local device online.
metadata:
  author: Autify
  version: "0.3.0"
---

# A local device that is not your screen

Aximo's cloud browsers cannot reach `localhost`. A local device can. But registering the
developer's own laptop means Aximo takes their mouse and keyboard for the whole run. This
skill gives Aximo a container instead: one Chromium on a virtual screen, whose `localhost`
is the developer's `localhost`, with a live view the developer can watch in a browser tab.

The box is `aximo device testbox` in aximo-cli, and you drive it with three MCP tools:
`aximo_start_testbox`, `aximo_get_testbox`, `aximo_stop_testbox`. **No shell commands.**
The user answers two questions (yes to the setup, and the port) and nothing else. Every
tool is safe to call again.

## 1. Ask once

"No test browser is online. Start the sandboxed one in Docker? The first time downloads a
1 GB image and takes a couple of minutes. Which port does the app serve on (default 3000)?"

Stop on no and hand back to the skill that sent you here.

## 2. Start it

Call `aximo_start_testbox` with `ports` (the user's port, or `"3000"`) and
`timeoutSeconds: 60`. If the user has a production hostname, add
`blockHosts: ["app.example.com"]` so the browser refuses it.

- A tool error mentioning Docker: Docker is not installed or not running. Show the
  message (it carries the install link or the fix) and hand back for the fallback
  (register the laptop itself, or test a deployed URL).
- `ready: true`: go to step 4.
- `ready: false`: go to step 3.

## 3. Wait for it

Call `aximo_get_testbox` with `timeoutSeconds: 45` until `ready: true`. A first start
pulls the image, so expect several calls; each returns the current `state` (`pulling`,
`starting`, `connecting`). Do not call `aximo_start_testbox` again and do not add a
shell `sleep`. Give up after 10 calls: report `state` and `lastError` and hand back.

`state: "error"` means the start failed; `lastError` says why. Show it to the user. Once
the cause is fixed, `aximo_start_testbox` again.

## 4. Hand the user the live view

The result carries `liveViewUrl`. Give it to the user: "This is the browser Aximo will
drive. Open it in a tab to watch." If the app has a login screen, ask them to sign in
there once and leave the browser on the page tests should start from. You cannot type
someone's password. The profile survives stop and start.

## 5. Hand back the device id

Return `userDeviceId` from the result: that is the local device for `aximo_create_session`
and case runs. Also check `ports`: `reachable: false` means the app is not answering
inside the box; `aximo-test-task` step 2b says what to tell the user.

## Put it away

`aximo_stop_testbox` stops the container and keeps the browser profile and the device
registration, so the next start takes seconds. Dropping the profile (fresh sign-in) or
the registration is a human action in a terminal:

```sh
npx -y @autifyhq/aximo-cli@0.16.0 device testbox reset   # drop the browser profile
npx -y @autifyhq/aximo-cli@0.16.0 device testbox prune   # remove everything, including the device
```

## If the tools are missing

No `aximo_start_testbox` in your tool list means an aximo-cli older than 0.16.0. Ask the
user to run the same thing in a terminal and tell you when it prints `"state": "online"`:

```sh
npx -y @autifyhq/aximo-cli@0.16.0 device testbox up --ports <port>
```

## What the box does not do

It does not mount the workspace. It has no remote-debugging port. Its live view is bound
to 127.0.0.1 and always has a password. The API key never enters the container. It
cannot click anything on the developer's own screen. macOS and Linux; Windows untested.
