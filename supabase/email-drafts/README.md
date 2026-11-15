# MSGI One Auth email drafts

Not installed in local or hosted Auth. These files do not change `config.toml`.

| Supabase template | Subject | HTML |
| --- | --- | --- |
| Confirm signup | Confirm your email — MSGI One | confirmation.html |
| Reset password | Reset your password — MSGI One | recovery.html |
| Change email address | Confirm email address change — MSGI One | email-change.html |

The only dynamic value is the documented `{{ .ConfirmationURL }}`. Preserve its
complete generated URL; do not replace it with a direct app route or manually
assemble tokens. Email-change confirmations must preserve the backend's
two-inbox confirmation policy. No user metadata is interpolated.

Text files are copy drafts for a supported multipart/text sending path. The
Supabase custom-template editor exposes HTML content, not a separate text-body
setting; do not promise these text files will automatically be sent as MIME
alternatives. Check actual generated MIME before approval. Do not route Auth
through a new email hook merely to obtain text alternatives in this task.

Static security/variable checks: `node --test tool/email_drafts.test.cjs`.
These checks do not render Go templates or prove inbox/dark-mode compatibility.
Before applying, review the three HTML drafts and render them in a disposable
local Auth instance, inspect generated Mailpit MIME, then test Gmail/Outlook and
mobile clients with consented recipients. Never enable click/open tracking for
authentication links. No institution endorsement or real support address is
asserted by these drafts; approve a support contact before rollout.
