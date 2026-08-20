# Static documents

Files here are served directly at `/documents/<filename>` (no asset digest), so
links to them stay stable.

## awbw-w9.pdf

The registration ticket links to `/documents/awbw-w9.pdf` when a registrant checks
"W-9" on the "Additional forms" registration question. It's a single static file
shared by every registrant (see `EventRegistrationServices::PublicRegistration` and
`app/views/event_registrations/_ticket.html.erb`). Replace `awbw-w9.pdf` here when
AWBW issues an updated W-9.
