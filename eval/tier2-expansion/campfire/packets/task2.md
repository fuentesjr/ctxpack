# ctxpack context packet

## Task
No task was provided.

## Anchor
- Anchor: `accounts#edit`
- Controller: `AccountsController`
- Action: `edit`
- File: `app/controllers/accounts_controller.rb`
- Generated from: 71ffeee (clean)

## Files to inspect first

### `app/controllers/accounts_controller.rb`

Why: controller action for requested anchor.
Reason code: `controller_action`

```ruby
  def edit
    users = account_users.ordered.without_bots
    @administrators, @members = users.partition(&:administrator?)
    set_page_and_extract_portion_from users, per_page: 500
  end
```

Why: callback `set_account` applies to the requested action.
Reason code: `before_action_callback`

```ruby
    def set_account
      @account = Current.account
    end
```

### `app/models/current.rb`

Why: constant `Current` was referenced by the action or an applicable callback.
Reason code: `referenced_constant`

### `test/controllers/accounts_controller_test.rb`

Why: test file matched the conventional controller test path.
Reason code: `minitest_candidate`

## Tests to run
- `bin/rails test test/controllers/accounts_controller_test.rb`

## Uncertainty
- Callbacks declared outside this controller file, including superclasses and concerns, were not resolved.
- Route discovery is delegated to Rails; run `bin/rails routes -g edit` if the exact endpoint matters.
- Convention-only constant match `Current` resolved to `app/models/current.rb`; verify it if the task depends on that behavior.

