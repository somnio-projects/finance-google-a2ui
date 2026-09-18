---
description: Draft a feature spec under specs/ from the template — the first step of every backend change
argument-hint: "[area/backend] [short feature name] [GGU-n]"
---

Draft a spec for: $ARGUMENTS

1. Read `specs/README.md` and `specs/TEMPLATE.md`. Pick the next free number
   in the target area folder (`specs/backend/`, `specs/client/`...).
2. Read the related Jira ticket description if a `GGU-n` key is given, and the
   existing code the feature touches (controllers, services, models).
3. Write `specs/<area>/NNNN-<kebab-name>.md` filling every section of the
   template. Acceptance criteria are numbered, observable and testable; the
   test plan maps each AC to unit and/or integration tests; security notes
   cover auth, audit events, data retention and error codes.
4. List open decisions with an owner and a default-if-unresolved.
5. Show me the spec and stop — do not write code until I approve it.
