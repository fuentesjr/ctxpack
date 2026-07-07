# ctxpack context packet

## Task
No task was provided.

## Anchor
- Anchor: `rooms#index`
- Controller: `RoomsController`
- Action: `index`
- File: `app/controllers/rooms_controller.rb`
- Generated from: 4450b7a (clean)

## Files to inspect first

### `app/controllers/rooms_controller.rb`

Why: controller action for requested anchor.
Reason code: `controller_action`

```ruby
  def index
    redirect_to room_url(Current.user.rooms.first)
  end
```

### `app/models/current.rb`

Why: constant `Current` was referenced by the action or an applicable callback.
Reason code: `referenced_constant`

### `test/controllers/rooms_controller_test.rb`

Why: test file matched the conventional controller test path.
Reason code: `minitest_candidate`

## Tests to run
- `bin/rails test test/controllers/rooms_controller_test.rb`

## Uncertainty
- Callbacks declared outside this controller file, including superclasses and concerns, were not resolved.
- Route discovery is delegated to Rails; run `bin/rails routes -g index` if the exact endpoint matters.
- Convention-only constant match `Current` resolved to `app/models/current.rb`; verify it if the task depends on that behavior.

