Implement the following feature.

The comment disown endpoint (CommentsController#disown) should accept an
optional truthy `cascade` parameter. When `cascade` is present, disown the
target comment and any direct child replies that were written by the same
original author.

Requirements:

- With no `cascade` parameter, the current disown behavior must be unchanged.
- Cascade disowning must use the existing inactive-user attribution path.
- Do not disown replies written by other users, and do not disown deeper
  descendants beyond direct child replies.
- Follow Lobsters' existing controller and model conventions; keep the change
  additive and avoid changing ordinary comment deletion or editing behavior.
