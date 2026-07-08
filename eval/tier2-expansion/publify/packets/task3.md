# ctxpack context packet

## Task
No task was provided.

## Anchor
- Anchor: `articles#preview`
- Controller: `ArticlesController`
- Action: `preview`
- File: `app/controllers/articles_controller.rb`
- Generated from: b78e0b4 (clean)

## Files to inspect first

### `app/controllers/articles_controller.rb`

Why: controller action for requested anchor.
Reason code: `controller_action`

```ruby
  def preview
    @article = Article.find(params[:id])
    @page_title = this_blog.article_title_template.to_title(@article, this_blog, params)
    render "read"
  end
```

Why: callback `verify_config` applies to the requested action.
Reason code: `before_action_callback`

```ruby
  def verify_config
    if !this_blog.configured?
      redirect_to controller: "setup", action: "index"
    elsif User.count == 0
      redirect_to new_user_registration_path
    else
      true
    end
  end
```

### `app/models/article.rb`

Why: constant `Article` was referenced by the action or an applicable callback.
Reason code: `referenced_constant`

### `app/models/user.rb`

Why: constant `User` was referenced by the action or an applicable callback.
Reason code: `referenced_constant`

### `spec/controllers/articles_controller_spec.rb`

Why: test file matched the conventional controller spec path.
Reason code: `rspec_candidate`

## Tests to run
- `bundle exec rspec spec/controllers/articles_controller_spec.rb`

## Uncertainty
- Callback `login_required` applies but was not defined in this controller file.
- Callbacks declared outside this controller file, including superclasses and concerns, were not resolved.
- Route discovery is delegated to Rails; run `bin/rails routes -g preview` if the exact endpoint matters.
- Convention-only constant match `Article` resolved to `app/models/article.rb`; verify it if the task depends on that behavior.
- Convention-only constant match `User` resolved to `app/models/user.rb`; verify it if the task depends on that behavior.

## Retrieve more only if needed
- Inspect the superclass or concerns for callback `login_required`.

