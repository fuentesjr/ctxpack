# ctxpack context packet

## Task
No task was provided.

## Anchor
- Anchor: `roles#create`
- Controller: `RolesController`
- Action: `create`
- File: `app/controllers/roles_controller.rb`
- Generated from: 3386d95 (clean)

## Files to inspect first

### `app/controllers/roles_controller.rb`

Why: controller action for requested anchor.
Reason code: `controller_action`

```ruby
  def create
    @role = Role.new
    @role.safe_attributes = params[:role]
    if request.post? && @role.save
      # workflow copy
      if params[:copy_workflow_from].present? && (copy_from = Role.find_by_id(params[:copy_workflow_from]))
        @role.copy_workflow_rules(copy_from)
      end
      flash[:notice] = l(:notice_successful_create)
      redirect_to roles_path
    else
      @roles = Role.sorted.to_a
      render :action => 'new'
    end
  end
```

### `app/models/role.rb`

Why: constant `Role` was referenced by the action or an applicable callback.
Reason code: `referenced_constant`

## Tests to run
No Minitest candidates were found by ctxpack's path rules.

## Uncertainty
- Callback `require_admin` applies but was not defined in this controller file.
- Callbacks declared outside this controller file, including superclasses and concerns, were not resolved.
- Route discovery is delegated to Rails; run `bin/rails routes -g create` if the exact endpoint matters.
- Convention-only constant match `Role` resolved to `app/models/role.rb`; verify it if the task depends on that behavior.

## Retrieve more only if needed
- Inspect the superclass or concerns for callback `require_admin`.
- Search `test/` by hand if the task needs test coverage.

