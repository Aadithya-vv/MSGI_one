# MSGI One Auth email drafts

Development-pilot drafts. Not installed in existing local or hosted Auth. These
files do not change `config.toml`. Task 11C.2A tests them in a new disposable Auth
instance only; never apply them automatically to the linked project.

| Supabase template | Subject | HTML |
| --- | --- | --- |
| Confirm signup | [DEV] Confirm your email — MSGI One | confirmation.html |
| Reset password | [DEV] Reset your password — MSGI One | recovery.html |
| Change email address | [DEV] Confirm email address change — MSGI One | email-change.html |

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
Actual GoTrue/Mailpit test: `node tool/test_email_template_rendering.cjs`.
This uses installed Docker images, new unique containers/internal network, tmpfs
data and read-only draft mounts. No existing stack is reset or configured; no
ports are published and no network egress or real mail is used. Raw Auth logs are
discarded, tokens remain in process memory, and preview action links are redacted.
It stops only its own new containers/network. Existing databases and hosted Auth
are outside its targets. `tool/email_template_server.sh` must retain LF endings.
These checks do not prove Gmail/Outlook, screen-reader or dark-mode compatibility.
Before applying, review the three HTML drafts and test actual mail clients with
consented recipients. Never enable click/open tracking for
authentication links. No institution endorsement or real support address is
asserted by these drafts; approve a support contact before rollout.

The JSON pilot manifest is a blocked proposal, not an API body or executable
configuration. Resolve null sender/HTTPS values, recipient containment and owner
approvals before any separate Task 11C.2B activation.
