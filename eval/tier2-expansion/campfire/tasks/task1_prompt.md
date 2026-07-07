Implement the following feature.

The user autocomplete endpoint (Autocompletable::UsersController#index)
should accept an optional `except` parameter. When present, the matching user
IDs in `except` must be excluded from the autocomplete results. The parameter
may be submitted as an array of user IDs or as a comma-separated list.

Requirements:

- With no `except` parameter, the current autocomplete behavior must be
  unchanged.
- Exclusions must apply to both ordinary user autocomplete and room-scoped
  autocomplete results.
- Follow Campfire's existing controller and model conventions; keep the change
  additive and avoid changing existing autocomplete semantics.
