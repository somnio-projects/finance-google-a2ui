# Provisioning runbook — the reviewer's demo account

GGU-12. One account, created by hand, used by Google's reviewers to open the
showcase. This file is the record that it exists, works, and was handed over.

**This file records metadata only. It never contains a credential value.**
The repository is public: a password committed here is an incident and a
rotation, not a cleanup commit.

## Who does what

| Step | Who |
|---|---|
| Create the account | **a human** — never an agent |
| Run `scripts/verify_demo_account.sh` | a human, before handover |
| UAT-1…UAT-8 on the deployed URLs | a human |
| Deliver the credentials | a human, out of band |

An agent may author the script and this skeleton, and nothing else. A
credential that enters an agent's transcript has been disclosed, whatever the
transcript is for.

## Creating the account

Signup is gated deliberately, so there is no public flow to use and enabling
one for this would undo that decision. Create the user in the **Firebase
console** for project `finance-a2ui` → Authentication → Users → Add user, with
the email/password provider and no custom claims.

Generate the password with a password manager. Do not invent one, do not reuse
one, and do not type it anywhere it will be stored in plain text.

## Verifying it, before handover

```bash
export DEMO_PASSWORD='…'              # from the password manager, never inline
export FIREBASE_WEB_API_KEY='…'       # Firebase console → project settings
./scripts/verify_demo_account.sh reviewer@example.com
```

Exit 0 means: the credentials return a real ID token, the backend verifies it,
the portfolio renders with formatted figures, and the A2A surface accepts the
token. **A non-zero exit before handover means do not hand over.**

The script settles AC-2 only. UAT-3 through UAT-6 — do the numbers look right,
does the surface stream rather than dump JSON, is it legible on a phone, does a
session survive a five-minute gap — are judgements no exit code captures.

## The record

Fill one row per account. Metadata only.

| Field | Value |
|---|---|
| Email | |
| Firebase project | `finance-a2ui` |
| Created by | |
| Created at | |
| Verified by (script, exit 0) | |
| Verified at | |
| Environment verified against | |
| Delivery channel | password-manager share / one-time secret link |
| Delivered to | |
| Delivered at | |
| Protected from cleanup until | |
| UAT sign-off (date · platforms · by whom) | |

**Delivery channel:** a password-manager share or a one-time secret link.
Never email, never chat, never a Jira comment.

## When the review window closes

Remove the cleanup protection and delete the account. Record the deletion date
in the row above rather than deleting the row — the record of an account that
existed is part of the audit trail (SOC 2 CC6.1).
