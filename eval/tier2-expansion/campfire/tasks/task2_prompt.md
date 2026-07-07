Implement the following feature.

The account settings page (AccountsController#edit) currently lists account
administrators and members, but it omits bot users. Add a visible section to
the account settings page that lists the account's active bot users.

Requirements:

- Preserve the existing administrators/members partition and ordering.
- Keep the existing account settings behavior unchanged for non-bot users.
- Follow Campfire's existing controller, view, and localization conventions;
  if you introduce new user-facing copy, add it to the locale file.
