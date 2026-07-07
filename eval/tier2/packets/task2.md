# ctxpack context packet

## Task
No task was provided.

## Anchor
- Anchor: `my#show_api_key`
- Controller: `MyController`
- Action: `show_api_key`
- File: `app/controllers/my_controller.rb`
- Generated from: d070f7d (clean)

## Files to inspect first

### `app/controllers/my_controller.rb`

Why: controller action for requested anchor.
Reason code: `controller_action`

```ruby
  def show_api_key
    @current_user = User.current
  end
```

### `app/models/user.rb`

Why: constant `User` was referenced by the action or an applicable callback.
Reason code: `referenced_constant`

## Tests to run
No Minitest candidates were found by ctxpack's path rules.

## Uncertainty
- Callback `require_login` applies but was not defined in this controller file.
- Callbacks declared outside this controller file, including superclasses and concerns, were not resolved.
- Route discovery is delegated to Rails; run `bin/rails routes -g show_api_key` if the exact endpoint matters.
- Convention-only constant match `User` resolved to `app/models/user.rb`; verify it if the task depends on that behavior.

## Retrieve more only if needed
- Inspect the superclass or concerns for callback `require_login`.
- Search `test/` by hand if the task needs test coverage.

