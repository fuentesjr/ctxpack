# ctxpack context packet

## Task
No task was provided.

## Anchor
- Anchor: `stories#update`
- Controller: `StoriesController`
- Action: `update`
- File: `app/controllers/stories_controller.rb`
- Generated from: 430d864 (dirty)

## Files to inspect first

### `app/controllers/stories_controller.rb`

Why: controller action for requested anchor.
Reason code: `controller_action`

```ruby
  def update
    if !@story.is_editable_by_user?(@user)
      flash[:error] = "You cannot edit that story."
      return redirect_to "/"
    end

    @story.last_edited_at = Time.current
    @story.is_deleted = false
    @story.editor = @user
    update_story_attributes

    if @story.save
      if @story.saved_change_to_url?
        CreateStoryCardJob.perform_later(@story)
      end

      redirect_to Routes.title_path @story
    else
      render action: "edit"
    end
  end
```

Why: callback `find_user_story` applies to the requested action.
Reason code: `before_action_callback`

```ruby
  def find_user_story
    @story = if @user.is_moderator?
      Story.where(short_id: params[:story_id] || params[:id]).first
    else
      Story.where(user_id: @user.id, short_id: params[:story_id] || params[:id]).first
    end

    if !@story
      flash[:error] = "Could not find story or you are not authorized " \
        "to manage it."
      redirect_to "/"
      false
    end
  end
```

### `app/jobs/create_story_card_job.rb`

Why: constant `CreateStoryCardJob` was referenced by the action or an applicable callback.
Reason code: `referenced_constant`

### `app/models/story.rb`

Why: constant `Story` was referenced by the action or an applicable callback.
Reason code: `referenced_constant`

## Tests to run
No RSpec candidates were found by ctxpack's path rules.

## Uncertainty
- Callback declaration `track_story_reads` used dynamic callback arguments and was not resolved precisely.
- Callbacks declared outside this controller file, including superclasses and concerns, were not resolved.
- Route discovery is delegated to Rails; run `bin/rails routes -g update` if the exact endpoint matters.
- Convention-only constant match `CreateStoryCardJob` resolved to `app/jobs/create_story_card_job.rb`; verify it if the task depends on that behavior.
- Convention-only constant match `Story` resolved to `app/models/story.rb`; verify it if the task depends on that behavior.

## Retrieve more only if needed
- Inspect callback declarations with dynamic callback arguments: `track_story_reads`.
- Search `spec/` by hand if the task needs test coverage.

