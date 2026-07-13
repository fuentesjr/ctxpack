# Test filesystem errors with real path shapes

## Problem

The CLI needed observable tests for concise directory-creation and artifact-write failures without adding a mocking dependency.

## Context

This arose while covering CLI filesystem failures in `test/ctxpack/cli_test.rb` and the scoped file-operation handling in `lib/ctxpack/cli.rb`.

## Failed approaches

The first test tried to stub `File.binwrite` through `File.stub` and `minitest/mock`, but this repository's installed Minitest 6 setup does not provide that mocking helper.

## Key insight

Ordinary filesystem shapes trigger the required failures deterministically: a read-only file raises `Errno::EACCES`, and creating a directory where a regular file already exists raises `Errno::EEXIST`. A directory-valued artifact destination also exercises the CLI's preflight validation without relying on a mock.

## Final approach

The tests build those shapes inside their temporary Rails app, invoke the public `Ctxpack::CLI#run` interface, and assert the returned status, injected streams, and absence of partial sibling output.

## Verification

`bundle exec ruby -Itest test/ctxpack/cli_test.rb` exercised the filesystem and destination-preflight cases through the public CLI and passed without adding a dependency.

## Reusable rule

Prefer deterministic temporary-filesystem shapes over mocks when testing Ruby file-operation failures.

## When to apply again

Use this technique when a CLI must translate `SystemCallError` failures and the failure can be produced safely with files and directories under a temporary root.
