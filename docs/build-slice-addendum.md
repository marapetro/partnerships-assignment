# Build Slice Addendum — Partner Registration Flow + Approve/Reject Actions

**Time box:** 40–50 min total. Build in order; deploy + commit per step. Opportunity creation on approval stays **out of scope**.

**Demo story:** "This is what a partner sees (Portal V1 — the same flow is exposed in Experience Cloud later, no rebuild). This is what the partner manager sees."

---

## A1. Data model changes (do first — the flow depends on them)
| Change | Detail | Why |
|---|---|---|
| `End_Customer__c` → **not required** at field level | Keep lookup; required at approval instead (A2 validation) | Partners type a company name; an unknown name can't resolve to an Account at submit time. |
| Add `End_Customer_Name__c` | Text(255) | What the partner typed; kept for audit and for the PM to match. |
| Add `End_Customer_Domain__c` | Text(255) | Second signal for matching (future matching service). |

## A2. Validation rule
- `Approval_Requires_End_Customer`:
  `AND(ISPICKVAL(Status__c, "Approved"), ISBLANK(End_Customer__c))`
  → "Match this registration to an End Customer account before approving."

## A3. Update before-save Flow `Deal_Registration_Before_Save_Checks`
- **New first decision — guard:** if `End_Customer__c` is blank →
  `Status__c = Under Review`, `Conflict_Flag__c = false`, `Conflict_Reason__c = "Customer not matched – confirm End Customer"`. **Skip** eligibility and conflict queries.
- **Why:** a Get Records filter of `AccountId = <blank>` can match unrelated Opportunities; never query with a null key.
- Existing logic unchanged when `End_Customer__c` is populated.

## A4. Screen Flow `Partner_Register_Deal` (runs in **user context**)
**Screen 1 — "Register a deal"**
| Input | Type | Notes |
|---|---|---|
| Partner (demo only) | Lookup to Account, filtered to Partner_Type__c not blank; default Northwind Partners | Help text: "In the portal this comes from the signed-in partner's account — partners never choose it." |
| Company name | Text, required | No Account lookup — partners must not browse our customers. |
| Company website / domain | Text | |
| Your role on this deal | Picklist: Referral, Reseller, Marketplace (required) | |
| Estimated deal size | Currency, required | |

**Logic**
1. Get Records — Account where `Name = {Company name}` (exact match), first record only. *Stand-in for the matching service (handoff component).*
2. Create Records — `Deal_Registration__c` with Partner Account, End Customer (matched Id or blank), End_Customer_Name__c, End_Customer_Domain__c, Partner Role, Estimated Amount. The before-save Flow sets Status.
3. Get Records — the new registration by Id (to read Status set by the before-save Flow, plus Name `DR-xxxx`).

**Screen 2 — partner-facing result** (decision on Status). Show reference number. **Never show Conflict Reason, opp details, or other partners.**
| Status | Message |
|---|---|
| Submitted | "Received (DR-xxxx). You'll have a decision within 2 business days." |
| Under Review | "Received (DR-xxxx). We're reviewing it against existing activity; you'll have a decision within 2 business days." |
| Not Eligible | "DR-xxxx: this company is already our customer, so it isn't eligible for registration. Your partner manager can still recognize your contribution on the deal." |

**Placement:** Lightning App Page **"Partner Deal Registration"** with the flow component; add to the Sales app nav.

## A5. Approve / Reject quick actions (partner manager)
Use **Update Record** quick actions on `Deal_Registration__c` (declarative, validation rules still fire):
| Action | Predefined value | Fields on action layout |
|---|---|---|
| **Approve** | `Status__c = Approved` | Conflict Reason (read-only), Conflict Resolution, Override Reason, End Customer |
| **Reject** | `Status__c = Rejected` | Rejection Reason (required on layout) |

- **Dynamic Actions** on the record page: show Approve/Reject only when Status is Submitted or Under Review.
- Make `Status__c` **read-only on the page layout** so status changes go through the actions (and their validations), not inline edits.
- Add both actions to the permission set's access as needed.

## A6. Navigation
- Custom tab for `Deal_Registration__c`; add to the Sales app; tab **Visible** in `Partner_Deal_Registration_Manager`.
- List view **"Open registrations"**: Status in (Submitted, Under Review); columns Name, Partner Account, End Customer Name, Status, Conflict Reason, Created Date.

---

## Tests to add (extend test-plan.md)
| ID | Scenario | Expected |
|---|---|---|
| T24 | Flow: "Initech" | Result screen "Received… 2 business days"; record Submitted, End Customer = Initech. |
| T25 | Flow: "Acme Corp" | Not Eligible message; record Not Eligible. |
| T26 | Flow: "Globex" | Under Review message **with no conflict detail**; record Conflict Flag = true. |
| T27 | Flow: "Hooli" (no Account) | Under Review message; record End Customer blank, reason "Customer not matched…". |
| T28 | Approve T27 record without End Customer | Blocked by `Approval_Requires_End_Customer`. |
| T29 | Approve action on Globex with Resolution cleared | Blocked by approval gate. |
| T30 | Reject action without reason | Blocked. |
| T31 | Approved/Rejected record | Approve/Reject buttons hidden. |
| T32 | Inline edit Status on record page | Not possible (read-only). |

## Revised demo script (≤2 min)
1. (10s) Problem + why this slice.
2. (40s) **Partner view** (App Page): register Globex → "under review" message (no conflict leakage); register Acme → not eligible message.
3. (40s) **Partner manager view:** Open registrations list → Globex shows conflict reason → Approve with resolution cleared → blocked → approve with default "Direct Retains – Partner Influenced".
4. (20s) Initech (pre-registered) → Approve → dates stamped; buttons disappear.
5. (10s) Next: same flow becomes Portal V1; matching service replaces exact-name match; opp creation on approval.

## Doc updates after build works
- Section 8: describe partner flow + actions.
- Field set: End Customer required at approval; add End Customer Name/Domain.
- Assumption/known limitation: exact-name match is a stand-in for the matching service.
