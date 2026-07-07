Make the following small behavior change.

Rooms::InvolvementsController#update currently crashes when the involvement
parameter is not one of the supported values (`invisible`, `nothing`,
`mentions`, or `everything`).

Change this so an invalid involvement value does not update the membership and
redirects back to the room involvement page with a localized flash alert.
Valid involvement values must continue to update the membership, broadcast the
same visibility changes, and redirect as they do today.
