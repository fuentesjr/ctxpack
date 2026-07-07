# Tier 2 Expansion Harness Notes

Per-app Tier 2 configuration lives in `eval/tier2/apps/<app>.rb`.
`campfire`, `lobsters`, and `publify` are skeleton configs only: their pinned
SHAs, prepared files, anchors, prompts, seed patches, packets, golden prompts,
and hidden acceptance tests are authored in a later pass.

Once an app is authored and its template checkout is prepared:

```bash
ruby eval/tier2/harness.rb <app> verify
ruby eval/tier2/harness.rb <app> status
ruby eval/tier2/harness.rb <app> setup
ruby eval/tier2/harness.rb <app> run [N]
```

`verify` is safe before setup and does not need a template checkout, database,
Claude auth, or network. Empty skeleton apps intentionally report `not yet
authored (0 tasks)`.
