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
6. Before every run, including one the user starts by hand, read the balance (rule 8).
   If `blocked` is true, tell the user the organization is out of credits and stop.
7. Show the criteria, the estimated cost and the balance, then ask, before every run that
   the user did not start by hand in this turn. Hook-started and autopilot-started runs
   always ask. After every run, state `creditsUsed` for that run, the running total for
   this Kiro session, and the balance from a fresh read.
8. The balance comes from `aximo_get_credits`: show `remaining`, plus `onDemandRemaining`
   when above 0 (runs keep going on on-demand credits once `remaining` hits 0).
   If `metered` is false, say credits are not enforced for this organization instead of
   showing figures. If the tool is not in your tool list (older aximo-cli), returns an
   error, or has no `remaining`, leave the balance out and carry on. Do not retry it, do
   not stop the run for it, and never guess a figure.
9. There is no per-run ceiling a caller can set. Aximo stops a session at 60 minutes,
   4000 steps, or a spend cap, all far above a task-sized test. Nothing else
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

## 2b. Check the app is reachable from the device

A run against an unreachable app still costs credits, and the agent reports it as the
app being broken rather than the setup. On the testbox, check first:

```sh
docker exec ${AXIMO_TESTBOX_NAME:-aximo-testbox} curl -s -o /dev/null -w '%{http_code}' --max-time 5 <URL>
```

Any 2xx, 3xx, or 4xx means the app answered; carry on. `000` means it did not, and the
usual cause is a dev server bound to loopback only, which the developer's own browser
reaches and the container cannot. Tell the user:

> Your dev server answers in your browser but not in the test browser, so it is
> listening on loopback only. Restart it bound to all interfaces: `--host` for Vite,
> `-H 0.0.0.0` for Next.js, `--host 0.0.0.0` for most others.

Then check again. Do not dispatch until it answers.

## 3. Compose the prompt and estimate the cost

Use this shape. Put the URL in the prompt body: on a local device the browser is
driven by keyboard and mouse and a separate `startUrl` is not opened for you.

On the testbox the browser keeps its profile, so it is usually signed in already from
`aximo-testbox` step 6. Do not ask for credentials before checking: put "if the page asks
you to sign in, stop and say so" in the prompt and run it. Only when a run comes back
saying it hit a login screen, ask the user for credentials once and reuse them for the
rest of this Kiro session. On a tunnel or a deployed URL there is no saved profile, so
ask up front.

```
Open <URL> in the browser. If it asks you to sign in, stop and say so.

Verify each of these acceptance criteria for "<task title>". For each one, state
PASS or FAIL with what you observed.

1. <criterion 1.1 text>
2. <criterion 2.3 text>

If you cannot reach the page, or a step blocks you, stop and explain what you saw
instead of retrying. Do not explore beyond the criteria above.
```

Estimate the cost from measured runs, not from the number of criteria alone. Opening
the page and signing in costs about 15 credits before any checking starts, and each
criterion costs about 12 more. On `haiku` or `auto`, halve the total.

| Criteria | `sonnet` | `haiku` / `auto` |
|---|---|---|
| 1 | about 30 credits | about 15 |
| 4 | about 60 credits | about 30 |
| 8 | about 110 credits | about 55 |

Give the estimate in credits only. Never convert credits to money or quote a price.

Say "about 30 credits", never "~30". A pair of tildes renders as strikethrough in Kiro
and the user sees the number crossed out.

Show the criteria list, the target URL, the device or tunnel, and the estimate. Ask
before dispatching unless the user asked for this exact run in this turn.

## 4. Dispatch

Call `aximo_create_session` with `title: "Kiro: <task title>"`, `prompt`, `projectId`,
and either `userDeviceId` (local device) or `startUrl` (tunnel or deployed URL). Keep
the returned `sessionId`. No case is saved.

If it comes back with `Insufficient credits to start session`, nothing was queued and no
credits were spent. Stop and tell the user the organization is out of credits. Do not
retry, and do not switch to the case path: it refuses the same way.

If `aximo_create_session` is not in your tool list (older aximo-cli), use the case path
and say why: `aximo_create_case` with `projectId`, `type: "web"`, `title`,
`format: "plain_text"`, `scenario: <the prompt>`, followed by `aximo_run_case` with
`caseId` plus `userDeviceId` for a local device. Tell the user a case was left behind and
offer to archive it after the run.

Immediately give the user both links. The session page is
`<base URL>/app/projects/<projectId>/sessions/<sessionId>`, and `<base URL>` is not
something to guess: read it from the config the CLI uses, so a sandbox or on-prem
organization gets a link that works.

```sh
node -e 'try{console.log(JSON.parse(require("fs").readFileSync(process.env.HOME+"/.aximo/config.json","utf8")).baseUrl||"")}catch{}'
```

Empty output means the default, `https://aximo.autify.com`. The other link, on the
testbox, is the live view (`aximo-testbox url`, see the `aximo-testbox` skill). Say the
run takes a few minutes.
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
   running total for this Kiro session and the balance, following credit rule 8.
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
