# View pass fixture token shapes

## Problem
The view pass needed a total-file truncation fixture with two test candidates, but the first fixture controller name only produced the conventional controller test and never produced the intended integration path match.

## Context
This arose while implementing VIEW-5 / LIM-1 coverage in `test/ctxpack/view_resolution_test.rb` and `test/fixtures/evals/view_total_file_truncation.yml`. TEST-1 rule 2 splits the integration test basename on underscores, then requires the controller token from the final controller path segment to be present.

## Failed approaches
Using `full_packets#show` looked natural for a "full packet" fixture, but `full_packets_show_flow_test.rb` splits into `full`, `packets`, `show`, `flow`, `test`; it never contains the single controller token `full_packets`, so ctxpack correctly did not produce the second test candidate.

## Key insight
For TEST-1 rule 2, an underscored controller segment is not representable as one underscore-delimited basename token.

## Final approach
Use a one-token controller segment for fixtures that must produce rule-2 test candidates. The total-file fixture now uses `saturation#show`, with `saturation_show_flow_test.rb` as the second test candidate that can be dropped by the total-file ceiling.

## Verification
`bundle exec ruby -Itest -Ilib test/ctxpack/view_resolution_test.rb` passed with `7 runs, 33 assertions, 0 failures, 0 errors, 0 skips`, and `bundle exec rake test` passed with `74 runs, 621 assertions, 0 failures, 0 errors, 0 skips`.

## Reusable rule
Use a one-token controller path segment when a fixture must exercise TEST-1 rule-2 path matching.

## When to apply again
Apply this whenever adding fixture apps or eval cases that depend on integration/request test path-token matching, especially when the fixture also needs to prove ordering or truncation across multiple test candidates.
