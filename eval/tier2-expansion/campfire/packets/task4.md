# ctxpack context packet

## Task
No task was provided.

## Anchor
- Anchor: `rooms/involvements#update`
- Controller: `Rooms::InvolvementsController`
- Action: `update`
- File: `app/controllers/rooms/involvements_controller.rb`
- Generated from: 71ffeee (clean)

## Files to inspect first

### `app/controllers/rooms/involvements_controller.rb`

Why: controller action for requested anchor.
Reason code: `controller_action`

```ruby
  def update
    @membership.update! involvement: params[:involvement]

    broadcast_visibility_changes
    redirect_to room_involvement_url(@room)
  end
```

### `test/controllers/rooms/involvements_controller_test.rb`

Why: test file matched the conventional controller test path.
Reason code: `minitest_candidate`

## Tests to run
- `bin/rails test test/controllers/rooms/involvements_controller_test.rb`

## Uncertainty
- Callbacks declared outside this controller file, including superclasses and concerns, were not resolved.
- Route discovery is delegated to Rails; run `bin/rails routes -g update` if the exact endpoint matters.

