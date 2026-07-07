# ctxpack context packet

## Task
No task was provided.

## Anchor
- Anchor: `autocompletable/users#index`
- Controller: `Autocompletable::UsersController`
- Action: `index`
- File: `app/controllers/autocompletable/users_controller.rb`
- Generated from: 71ffeee (clean)

## Files to inspect first

### `app/controllers/autocompletable/users_controller.rb`

Why: controller action for requested anchor.
Reason code: `controller_action`

```ruby
  def index
    set_page_and_extract_portion_from find_autocompletable_users.with_attached_avatar.ordered, per_page: 20
  end
```

### `test/controllers/autocompletable/users_controller_test.rb`

Why: test file matched the conventional controller test path.
Reason code: `minitest_candidate`

## Tests to run
- `bin/rails test test/controllers/autocompletable/users_controller_test.rb`

## Uncertainty
- Callbacks declared outside this controller file, including superclasses and concerns, were not resolved.
- Route discovery is delegated to Rails; run `bin/rails routes -g index` if the exact endpoint matters.

