Implement the following feature.

During initial blog setup, SetupController should let the operator choose the
admin user's display nickname.

Requirements:

- When `user[nickname]` is submitted with a non-blank value, the created admin
  user should use that value as its `nickname`.
- When the nickname is absent or blank, the existing default nickname
  `"Publify Admin"` must remain unchanged.
- Preserve the existing blog and user creation flow, including the generated
  first post/page, sign-in, notification, and redirect behavior.
- Follow Publify's existing controller conventions and keep the change
  additive.
