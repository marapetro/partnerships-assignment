# CLAUDE.md — Partner Deal Registration

## Context
Salesforce DX project for a time-boxed take-home. Build ONLY what `docs/build-slice-spec.md` defines. Design rationale lives in `docs/decision-log.md` — don't re-decide; ask if something conflicts.

## Target org
- Developer Edition org, authenticated via SF CLI (default target org alias set in `.sf/config.json`).
- **Never** deploy to any org other than the default dev org. Confirm the target alias before every deploy.

## Workflow
1. Read the spec section being built.
2. Create/modify metadata under `force-app/main/default/`.
3. Deploy only what changed: `sf project deploy start --source-dir <path>`.
4. Verify (query or describe), then stop and summarize what changed before the next step.
5. Commit one spec step per commit, with a clear message.

## Conventions
- API names: `Title_Case__c`; labels in plain English; descriptions on every custom field, Flow and validation rule.
- Prefer declarative (Flow, validation rules). Before-save Flows for same-record updates; no DML loops.
- Access via **permission sets only** — never edit profiles.
- Restricted picklists for anything reported on.
- No hardcoded IDs. Note any hardcoded values (e.g., stage names) in the README as assumptions.

## Security
- Never commit credentials, auth URLs, `.sf/`, `.sfdx/`, or org-specific files — check `.gitignore` / `.forceignore` before the first commit.
- Don't grant Modify All / View All or "Author Apex" style system permissions.
- Demo data uses fictional company names only.

## Out of scope (do not build)
Partner Involvement object, opp creation on approval, override approval process, escalations, auto-renewal job, fuzzy matching, Experience Cloud portal.
