# Sandbox-blocked DB validation

## Problem

The Lobsters Tier 2 task-authoring pass required RSpec red/green validation
against MariaDB, but the managed Codex sandbox blocked both TCP and Unix-socket
database connections before any examples could run.

## Context

This arose while authoring `eval/tier2-expansion/lobsters/tasks/` and wiring
`eval/tier2/apps/lobsters.rb`. The tracker now records the remaining
unsandboxed validation gate in `PROJECT_TRACKER.md`.

## Failed approaches

- Running the exact RSpec command from a throwaway clone failed at Rails load
  time with `Trilogy::SyscallError::EPERM` for `127.0.0.1:3306`.
- Switching from TCP to MariaDB's `/tmp/mysql.sock` did not help; the socket
  connection was also blocked by the sandbox.
- Process inspection with `ps` was also blocked, so the server had to be
  identified from the MariaDB error log instead.

## Key insight

The failure was not a Lobsters configuration problem; it was the managed
sandbox denying local database/socket access, so the correct response was to
finish static artifact checks and leave the RSpec gate for an unsandboxed shell.

## Final approach

Completed the authoring artifacts, verified patch applicability and Ruby
syntax offline, documented the blocker in the Lobsters README and project
tracker, and did not fabricate `task3_failing_output.txt`.

## Verification

`git apply --check` passed for the task 3 seed patch and all reference patches;
reference patches applied in throwaway clones and their changed Ruby files
passed `mise exec ruby@4.0.0 -- ruby -c`; `bundle exec rake test` passed with
`55 runs, 362 assertions, 0 failures, 0 errors, 0 skips`.

## Reusable rule

When DB-backed subject-app validation fails with sandbox-level `Operation not permitted`, record the blocker and defer only the DB gate instead of rewriting app config or inventing captured test output.

## When to apply again

Use this when a Tier 2 subject app needs MySQL, MariaDB, PostgreSQL, Redis, or
another local service from inside the managed Codex sandbox and the command
fails before examples or app behavior can run.
