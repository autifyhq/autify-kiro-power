---
name: aximo-test-task
description: Run a real end-to-end browser test of the spec task you just implemented. Use when the user says "test what I built", "test this task", "verify the acceptance criteria in the browser", after a spec task is marked complete, or when a hook asks for an Aximo run. Reads the task's acceptance criteria, runs them with Aximo, and reports the verdict with screenshots and the failure reasoning.
metadata:
  author: Autify
  version: "0.2.0"
---

# Test what you just built

One Aximo session per completed task. The session is a natural-language prompt made of
the task's acceptance criteria; a browser agent executes it and judges each criterion.
Runs take minutes, not seconds, so this skill dispatches, waits in short calls, then
collects. Never run it per file save.

## Credit rules (read first)

Every Aximo step costs credits. Follow all of these:

1. One session per task. Do not test the whole spec; that is `aximo-spec-to-plan`.
2. Maximum two re-runs per task after a failure, then stop and report.
3. Only user-observable criteria go into the prompt. Skip build, packaging, and
   internal-API criteria; say which ones you skipped.
4. Keep the criteria list short. Each criterion is what costs steps, so trimming the
   list is the only reliable way to shorten a run. Aximo gives the agent no step
   counter, so asking it for "at most N steps" does nothing.
5. Never dispatch against a host that looks like production unless the user names it.
   Production-looking: a public hostname with no `localhost`, `127.0.0.1`, `.local`,
   `staging`, `preview`, `sbx`, `dev`, or `test` in it. Ask "This looks like production.
   Run against `<host>`?" and wait for a yes that repeats the host.
6. Show the criteria and the estimated cost, then ask, before every run that the user did
   not start by hand in this turn. Hook-started and autopilot-started runs always ask.
7. After every run, state `creditsUsed` for that run and the running total for this
   Kiro session.
8. There is no per-run ceiling a caller can set. Aximo stops a session at 60 minutes,
   4000 steps, or $20 of model spend, all far above a task-sized test. Nothing else
   bounds a runaway run, so the length of the prompt is the real control.

## 1. Find the acceptance criteria

- Locate the task in `.kiro/specs/<feature>/tasks.md`: the one just marked `[x]`, or the
  one the user names.
- Read its `_Requirements: 1.1, 2.3_` line. Open `.kiro/specs/<feature>/requirements.md`
  and collect those numbered criteria (`### Requirement 1` then `#### Acceptance
  Criteria` item 1 is criterion 1.1). Include the user story line for context.
- If the task has no `_Requirements_` line, derive two or three observable checks from
  the task text and tell the user you did.

## 2. Preconditions

- **Target URL.** Ask if unknown. Default suggestion is `http://localhost:3000` when
  the workspace has a dev server script.
- **Project.** Use the `projectId` chosen in `aximo-setup`, or `aximo_list_projects`.
- **Device, for a localhost URL.** Call `aximo_list_user_devices` and pick a desktop
  device with `status: "online"`. Prefer the testbox (`kiro-<hostname>`) over the
  developer's own machine.

  **None online.** Do not queue a run against an offline device: the run waits up to
  30 minutes for the device and then errors, and that shows up as a stuck run. Do not
  hand the user shell commands to run. Bring a device up yourself:

  1. Load the `aximo-testbox` skill now and do all of its steps. It checks Docker, asks
     the user once, brings up the container, and hands back a `userDeviceId` and a
     live-view link. Use that id and continue with step 3.
  2. If it hands back because Docker is missing or the user said no, offer the two other ways and let them
     pick: register this machine itself as the device (`aximo-setup` Step 4; Aximo
     then takes the user's mouse and keyboard during the run), or a tunnel: put the dev
     app on a temporary public URL and let Aximo's cloud browser open it.
     `cloudflared tunnel --url http://localhost:3000` or `ngrok http 3000` (either tool
     installed on the machine) prints the URL. Say plainly that the dev app is reachable
     from the internet while the tunnel is up, and that a login screen, if any, must be
     handled in the prompt because nobody can sign in for the agent. Use the tunnel URL
     as `startUrl` and skip `userDeviceId`.

## 3. Compose the prompt and estimate the cost

Use this shape. Put the URL in the prompt body: on a local device the browser is
driven by keyboard and mouse and a separate `startUrl` is not opened for you.

```
Open <URL> in the browser. Sign in as <role> if the page asks (credentials: <how>).

Verify each of these acceptance criteria for "<task title>". For each one, state
PASS or FAIL with what you observed.

1. <criterion 1.1 text>
2. <criterion 2.3 text>

If you cannot reach the page, or a step blocks you, stop and explain what you saw
instead of retrying. Do not explore beyond the criteria above.
```

Estimate: a step is one browser action. A task-sized run is about 25 steps; count
roughly 5 per criterion plus 5 to open the page and sign in. On `sonnet` a web step
costs 1 credit; on `haiku` or `auto`, 0.5. One on-demand credit is one US cent. So a
four-criterion task is about 25 credits (25 cents) on `sonnet`, half that on `auto`.

Show the criteria list, the target URL, the device or tunnel, and the estimate. Ask
before dispatching unless the user asked for this exact run in this turn.

## 4. Dispatch

Call `aximo_create_session` with `title: "Kiro: <task title>"`, `prompt`, `projectId`,
and either `userDeviceId` (local device) or `startUrl` (tunnel or deployed URL). Keep
the returned `sessionId`. No case is saved.

Use the case path instead, and say why, in either of these cases:

- **The organization may be out of credits** (the user says so, or an earlier run this
  session came back with `Insufficient credits`). Creating a session does not check the
  balance first; running a case does, and refuses up front with `Insufficient credits to
  start session`. Then: `aximo_create_case` with `projectId`, `type: "web"`, `title`,
  `format: "plain_text"`, `scenario: <the prompt>`, followed by `aximo_run_case` with
  `caseId` plus `userDeviceId` for a local device. Tell the user a case was left behind
  and offer to archive it after the run.
- **`aximo_create_session` is not in your tool list** (older aximo-cli). Same two calls.

Immediately give the user both links: the session page
`<base URL>/app/projects/<projectId>/sessions/<sessionId>` and, on the testbox, the
live view (`aximo-testbox url`, see the `aximo-testbox` skill). Say the run takes a few minutes.
On the developer's own machine, say that Aximo now has their mouse and keyboard.

## 5. Wait

Call `aximo_wait_for_session` with the `sessionId` and `timeoutSeconds: 90`. It polls
for you and returns before 90 seconds are up:

- `done: true`: go to step 6.
- `done: false`: call it again. Do not add a shell `sleep`, do not call
  `aximo_get_session` in between, and do not start a second run.

Give up after 20 minutes of `done: false` (about 14 calls). Report the last `status`
with both links and stop.

If `aximo_wait_for_session` is not in your tool list, poll `aximo_get_session` no faster
than every 15 seconds until `status` is `succeeded`, `failed`, `terminated`, `error`, or
`archived`.

## 6. Collect and report

Call `aximo_get_session_timeline`. Then report, in this order:

1. **Verdict.** `result` (`passed`, `failed`, `error`) and `creditsUsed`, plus the
   running total for this Kiro session.
2. **Per criterion.** PASS or FAIL for each numbered criterion, taken from the agent's
   final `text` in the timeline and the session `summary` and `observations`.
3. **Why it failed.** Quote the agent's own reasoning from the last assistant steps
   verbatim. Do not paraphrase into a guess.
4. **Evidence.** Up to three screenshots as markdown images from the failing steps'
   `screenshots[].url`, plus both links again. Screenshot links expire after one hour;
   say so.
5. **Next step.** If a criterion failed because of the code, propose the fix in the
   workspace, apply it if the user agrees, then re-run: `aximo_create_session` again
   with the same prompt (or `aximo_run_case` with the same `caseId` on the case path).
   Count the re-run against the two allowed. If it failed because the app was not
   reachable or the device went offline, say that and do not count it as a code failure.

Write the verdict back into `tasks.md` as a one-line note under the task only if the
user asks.
