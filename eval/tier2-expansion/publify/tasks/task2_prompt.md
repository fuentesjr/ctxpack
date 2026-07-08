Implement the following feature.

The tag index endpoint (TagsController#index) should support JSON requests at
`GET /tags.json`. The JSON response should return a list of tags with the
number of published contents associated with each tag.

Requirements:

- Return a JSON array of objects with at least these keys: `name` and
  `articles_count`.
- `articles_count` must count only published contents for that tag, using the
  existing tag-to-contents association and published scope.
- Put the published-count calculation outside the controller, on `Tag` or a
  similarly small model-level API.
- Preserve the existing HTML tag index behavior.
- Follow Publify's existing controller and model conventions; do not introduce
  a template dependency for this JSON response.
