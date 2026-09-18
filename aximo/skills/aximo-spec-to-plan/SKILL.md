---
name: aximo-spec-to-plan
description: Turn a Kiro spec's requirements.md into an Aximo test plan. Use when the user asks to "create tests from the spec", "turn the acceptance criteria into a regression suite", or wants a plan that runs the whole feature against staging or localhost.
metadata:
  author: Autify
  version: "0.1.0"
---

# Spec to plan

Each `### Requirement N` in `.kiro/specs/<feature>/requirements.md` becomes one Aximo
case. All cases go into one plan. This is a bulk operation; confirm scope and cost with
the user before creating anything.

## 1. Read and filter

Parse `requirements.md`: for each requirement take the title, the `**User Story:**`
line, and the numbered acceptance criteria. Drop criteria that are not observable in a
browser (build steps, file layout, internal APIs). Show the user the list of cases you
intend to create, with the criteria count per case, and wait for a yes.

## 2. Create cases

For each requirement, `aximo_create_case` with:

- `projectId`, `type: "web"`, `format: "plain_text"`
- `title: "<feature>: Requirement N <title>"`
- `scenario`: the user story, then "Open {{BASE_URL}} in the browser", then the
  criteria as a numbered PASS/FAIL checklist, then "If a step blocks you, stop and
  explain what you saw instead of retrying."

Use the literal placeholder `{{BASE_URL}}` in the scenario text. Aximo substitutes
plan variables into scenario text at run time, which lets the same plan target
localhost on a local device or staging in the cloud.

## 3. Create the plan

1. `aximo_create_plan` with `projectId` and `title: "<feature> acceptance"`.
2. `aximo_add_case_to_plan` for each `caseId`, in requirement order.
3. `aximo_update_plan` with `executionMode: "sequential"` and `stopOnFailure: false`.

## 4. Run it (only when asked)

`aximo_run_plan` with `planId`, `variables: [{ "name": "BASE_URL", "value": "<URL>" }]`,
and for a local target `desktopConfig: { "devices": [{ "userDeviceId": "<id>" }] }`.
A local device must be online; the plan run is rejected (412) otherwise.

Poll `aximo_get_plan_run` no faster than every 20 seconds until `status` is
`completed`, `failed`, or `cancelled`. Report `passedCases` / `failedCases` and link
each failed case's session. State the total credits across sessions.

## Cost note

A plan run is N sessions. Say the number of cases and the expected order of magnitude
of credits before running. Never attach this to a hook.
