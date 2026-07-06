Implement the following feature.

When a user initiates deactivation of their two-factor authentication
(TwofaController#deactivate_init), the application must additionally send a
security notification email to the user's mail address informing them that
2FA deactivation was requested for their account.

Requirements:

- The email is sent on every deactivate_init request, for any 2FA scheme, in
  addition to the existing code-sending behavior (which must not change).
- Follow the application's existing mailer conventions; the subject and body
  may be simple but must be localizable like other notification mail.
