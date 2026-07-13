# Right-split structured input with regex captures in Ruby

## Problem
The first implementation of the slash-anchor diagnostic called a Python-style
`String#rsplit`, which Ruby does not provide.

## Context
This arose in the CLI-17c syntactic diagnostic for converting
`admin/accounts/upgrade` into the illustrative `admin/accounts#upgrade` form in
`lib/ctxpack/cli.rb`.

## Failed approaches
Calling `value.rsplit("/", 2)` failed with `NoMethodError` in the public CLI
test because `rsplit` is not a Ruby String API.

## Key insight
The input already has a strict grammar, so one anchored regex can validate it
and capture the controller prefix and final action without a separate split.

## Final approach
Match the complete slash-separated shape with named `controller` and `action`
captures, then construct only the diagnostic illustration from those safe
tokens.

## Verification
`bundle exec ruby -Itest test/ctxpack/cli_test.rb` passed with 56 runs, 424
assertions, 0 failures, and 0 errors, including namespaced slash input.

## Reusable rule
Use anchored named captures when Ruby must split a validated structured token at its final delimiter.

## When to apply again
Apply when parsing a small, closed CLI token grammar where the final delimiter
has semantic meaning and both halves need validation.
