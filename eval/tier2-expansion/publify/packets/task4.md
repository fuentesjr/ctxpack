# ctxpack context packet

## Task
No task was provided.

## Anchor
- Anchor: `admin/users#destroy`
- Controller: `Admin::UsersController`
- Action: `destroy`
- File: `app/controllers/admin/users_controller.rb`
- Generated from: 80ede86 (dirty)

## Files to inspect first

### `app/controllers/admin/users_controller.rb`

Why: controller action for requested anchor.
Reason code: `controller_action`

```ruby
  def destroy
    @user.destroy if User.where("profile = ? and id != ?", User::ADMIN, @user.id).count > 1
    redirect_to admin_users_url
  end
```

Why: callback `set_user` applies to the requested action.
Reason code: `before_action_callback`

```ruby
  def set_user
    @user = User.find(params[:id])
  end
```

### `app/models/user.rb`

Why: constant `User` was referenced by the action or an applicable callback.
Reason code: `referenced_constant`

### `spec/controllers/admin/users_controller_spec.rb`

Why: test file matched the conventional controller spec path.
Reason code: `rspec_candidate`

## Tests to run
- `bundle exec rspec spec/controllers/admin/users_controller_spec.rb`

## Uncertainty
- Callbacks declared outside this controller file, including superclasses and concerns, were not resolved.
- Route discovery is delegated to Rails; run `bin/rails routes -g destroy` if the exact endpoint matters.
- Convention-only constant match `User` resolved to `app/models/user.rb`; verify it if the task depends on that behavior.

