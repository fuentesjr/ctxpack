# ctxpack context packet

## Task
No task was provided.

## Anchor
- Anchor: `twofa#deactivate_init`
- Controller: `TwofaController`
- Action: `deactivate_init`
- File: `app/controllers/twofa_controller.rb`
- Generated from: 3386d95 (clean)

## Files to inspect first

### `app/controllers/twofa_controller.rb`

Why: controller action for requested anchor.
Reason code: `controller_action`

```ruby
  def deactivate_init
    if @twofa.send_code(controller: 'twofa', action: 'deactivate')
      flash[:notice] = l('twofa_code_sent')
    end
    redirect_to action: :deactivate_confirm, scheme: @twofa.scheme_name
  end
```

Why: callback `deactivate_setup` applies to the requested action.
Reason code: `before_action_callback`

```ruby
  def deactivate_setup
    @user = User.current
    @twofa = Redmine::Twofa.for_user(@user)
    if params[:scheme].to_s != @twofa.scheme_name
      redirect_to my_account_path
    end
  end
```

### `app/models/user.rb`

Why: constant `User` was referenced by the action or an applicable callback.
Reason code: `referenced_constant`

## Tests to run
No Minitest candidates were found by ctxpack's path rules.

## Uncertainty
- Callback `require_login` applies but was not defined in this controller file.
- Callback `require_active_twofa` applies but was not defined in this controller file.
- Callbacks declared outside this controller file, including superclasses and concerns, were not resolved.
- Route discovery is delegated to Rails; run `bin/rails routes -g deactivate_init` if the exact endpoint matters.
- Convention-only constant match `User` resolved to `app/models/user.rb`; verify it if the task depends on that behavior.

## Retrieve more only if needed
- Inspect the superclass or concerns for callbacks: `require_login`, `require_active_twofa`.
- Search `test/` by hand if the task needs test coverage.

