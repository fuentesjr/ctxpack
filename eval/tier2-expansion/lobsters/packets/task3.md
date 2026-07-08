# ctxpack context packet

## Task
No task was provided.

## Anchor
- Anchor: `inbox#all`
- Controller: `InboxController`
- Action: `all`
- File: `app/controllers/inbox_controller.rb`
- Generated from: 20d3446 (clean)

## Files to inspect first

### `app/controllers/inbox_controller.rb`

Why: controller action for requested anchor.
Reason code: `controller_action`

```ruby
  def all
    notifications_per_page = 25

    @notifications = @user
      .notifications
      .offset((@page - 1) * notifications_per_page)
      .limit(notifications_per_page)
      .order(created_at: :desc)
      .preload(user: [:hidings, :votes], notifiable: {story: [:tags, :user], user: [:comments], author: [], parent_comment: []})
    apply_current_vote

    @has_more = @user.notifications.count > (@page * notifications_per_page)

    respond_to do |format|
      format.html
      format.json { render json: @notifications }
    end
  end
```

Why: callback `set_page` applies to the requested action.
Reason code: `before_action_callback`

```ruby
  def set_page
    @page = params[:page].to_i
    if @page == 0
      @page = 1
    elsif @page < 0 || @page > (2**32)
      raise ActionController::RoutingError.new("page out of bounds")
    end
  end
```

### `spec/controllers/inbox_controller_spec.rb`

Why: test file matched the conventional controller spec path.
Reason code: `rspec_candidate`

## Tests to run
- `bundle exec rspec spec/controllers/inbox_controller_spec.rb`

## Uncertainty
- Callback `require_logged_in_user` applies but was not defined in this controller file.
- Callbacks declared outside this controller file, including superclasses and concerns, were not resolved.
- Route discovery is delegated to Rails; run `bin/rails routes -g all` if the exact endpoint matters.

## Retrieve more only if needed
- Inspect the superclass or concerns for callback `require_logged_in_user`.

