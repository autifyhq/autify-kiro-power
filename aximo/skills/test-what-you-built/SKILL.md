---
name: test-what-you-built
description: Run a real end-to-end browser test of the spec task you just implemented. Use when the user says "test what I built", "test this task", "verify the acceptance criteria in the browser", after a spec task is marked complete, or when a hook asks for an Aximo run. Reads the task's acceptance criteria, runs them with Aximo, and reports the verdict with screenshots and the failure reasoning.
metadata:
  author: Autify
  version: "0.1.0"
---

# Test what you just built

One Aximo session per completed task. The session is a natural-language prompt made of
the task's acceptance criteria; a remote browser agent executes it and judges each
criterion. Runs take minutes, not seconds, so this skill dispatches, waits, then
collects. Never run it per file save.

## Credit rules (read first)

Every Aximo step costs credits. Follow all of these:

1. One session per task. Do not test the whole spec; that is `spec-to-plan`.
2. Maximum two re-runs per task after a failure, then stop and report.
3. Only user-observable criteria go into the prompt. Skip build, packaging, and
   internal-API criteria; say which ones you skipped.
4. Keep the criteria list short. Each criterion is what costs steps, so trimming the
   list is the only reliable way to shorten a run. Aximo gives the agent no step
   counter, so asking it for "at most N steps" does nothing.
5. Never dispatch against a URL that looks like production unless the user asks by name.
6. After every run, state `creditsUsed` for that run and the running total for this
   Kiro session.
7. If the run is not user-initiated (hook, autopilot), confirm before dispatching.
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
- **Device.** For a localhost URL call `aximo_list_user_devices` (or, on aximo-cli
  0.13.0, ask the user for `aximo device status` output) and pick a desktop device with
  `status: "online"`. None online: stop and point the user at
  `getting-started` Step 4. Do not queue a run against an offline device; it waits up to
  30 minutes for the device and then errors, and that wait shows up as a stuck run.
- **Project.** Use the `projectId` chosen in `getting-started`, or `aximo_list_projects`.

## 3. Compose the prompt

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

Show the prompt to the user before dispatching when the run was not explicitly
requested.

## 4. Dispatch

Today the MCP server has no ad-hoc session tool, so create a case and run it:

1. `aximo_create_case` with `projectId`, `type: "web"`, `title: "Kiro: <task title>"`,
   `format: "plain_text"`, `scenario: <the prompt>`, and `startUrl: <URL>` when the URL is
   reachable from the internet. Keep the returned `caseId`; a re-run reuses it.
2. `aximo_run_case` with `caseId`, plus `userDeviceId` for a local device. Keep the
   returned `sessionId`.

When `aximo_create_session` exists, call it instead with `title`, `prompt`, `projectId`,
optional `startUrl` and `userDeviceId`, and skip the case.

Immediately tell the user: the session link
`<base URL>/app/projects/<projectId>/sessions/<sessionId>`, that it will take a few
minutes, and (local device) that Aximo now has their mouse and keyboard.

## 5. Wait

Poll `aximo_get_session` with the `sessionId`. Between polls run `sleep 20` in the shell.
Never poll faster than every 15 seconds. Stop when `status` is one of `succeeded`,
`failed`, `terminated`, `error`, `archived`. Give up after 20 minutes and report the
last status with the link.

Do not call other Aximo tools while waiting, and do not start a second run.

## 6. Collect and report

Call `aximo_get_session_timeline`. Then report, in this order:

1. **Verdict.** `result` (`passed`, `failed`, `error`) and `creditsUsed`.
2. **Per criterion.** PASS or FAIL for each numbered criterion, taken from the agent's
   final `text` in the timeline and the session `summary` and `observations`.
3. **Why it failed.** Quote the agent's own reasoning from the last assistant steps
   verbatim. Do not paraphrase into a guess.
4. **Evidence.** Up to three screenshots as markdown images from the failing steps'
   `screenshots[].url`. Links expire after one hour; say so.
5. **Next step.** If a criterion failed because of the code, propose the fix in the
   workspace, apply it if the user agrees, then re-run with `aximo_run_case` (same
   `caseId`). Count the re-run. If it failed because the app was not reachable or the
   device went offline, say that and do not count it as a code failure.

Write the verdict back into `tasks.md` as a one-line note under the task only if the
user asks.
