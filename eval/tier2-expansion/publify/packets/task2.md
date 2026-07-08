# ctxpack context packet

## Task
No task was provided.

## Anchor
- Anchor: `tags#index`
- Controller: `TagsController`
- Action: `index`
- File: `app/controllers/tags_controller.rb`
- Generated from: 80ede86 (dirty)

## Files to inspect first

### `app/controllers/tags_controller.rb`

Why: controller action for requested anchor.
Reason code: `controller_action`

```ruby
  def index
    @tags = Tag.page(params[:page]).per(100)
    @page_title = controller_name.capitalize
    @keywords = ""
    @description = "Tags for #{this_blog.blog_name}"
  end
```

### `app/models/tag.rb`

Why: constant `Tag` was referenced by the action or an applicable callback.
Reason code: `referenced_constant`

### `spec/controllers/tags_controller_spec.rb`

Why: test file matched the conventional controller spec path.
Reason code: `rspec_candidate`

## Tests to run
- `bundle exec rspec spec/controllers/tags_controller_spec.rb`

## Uncertainty
- Callback `auto_discovery_feed` applies but was not defined in this controller file.
- Callbacks declared outside this controller file, including superclasses and concerns, were not resolved.
- Route discovery is delegated to Rails; run `bin/rails routes -g index` if the exact endpoint matters.
- Convention-only constant match `Tag` resolved to `app/models/tag.rb`; verify it if the task depends on that behavior.

## Retrieve more only if needed
- Inspect the superclass or concerns for callback `auto_discovery_feed`.

