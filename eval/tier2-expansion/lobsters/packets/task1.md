# ctxpack context packet

## Task
No task was provided.

## Anchor
- Anchor: `comments#disown`
- Controller: `CommentsController`
- Action: `disown`
- File: `app/controllers/comments_controller.rb`
- Generated from: 430d864 (dirty)

## Files to inspect first

### `app/controllers/comments_controller.rb`

Why: controller action for requested anchor.
Reason code: `controller_action`

```ruby
  def disown
    if !((comment = find_comment) && comment.is_disownable_by_user?(@user))
      return render plain: "can't find comment", status: 400
    end

    InactiveUser.disown! comment

    if request.xhr?
      comment = find_comment
      show_story = ActiveModel::Type::Boolean.new.cast(params[:show_story])
      show_tree_lines = ActiveModel::Type::Boolean.new.cast(params[:show_tree_lines])

      render partial: "comment", locals: {comment: comment, show_story: show_story, show_tree_lines: show_tree_lines}
    else
      redirect_back_or_to(root_path)
    end
  end
```

### `app/models/inactive_user.rb`

Why: constant `InactiveUser` was referenced by the action or an applicable callback.
Reason code: `referenced_constant`

### `spec/controllers/comments_controller_spec.rb`

Why: test file matched the conventional controller spec path.
Reason code: `rspec_candidate`

## Tests to run
- `bundle exec rspec spec/controllers/comments_controller_spec.rb`

## Uncertainty
- Callback `show_title_h1` applies but was not defined in this controller file.
- Callbacks declared outside this controller file, including superclasses and concerns, were not resolved.
- Route discovery is delegated to Rails; run `bin/rails routes -g disown` if the exact endpoint matters.
- Convention-only constant match `InactiveUser` resolved to `app/models/inactive_user.rb`; verify it if the task depends on that behavior.

## Retrieve more only if needed
- Inspect the superclass or concerns for callback `show_title_h1`.

