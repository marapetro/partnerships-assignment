# Build Slice Spec — Registration Eligibility + Conflict Check + Approval Gate

**Why this slice (one sentence for the doc):** It automates the exact failure from intake — a reseller registering a deal the AE had worked for four months — by checking every new registration against existing customers and open/recently lost opportunities before anyone can approve it.

**Time box:** 45–60 min. Deploy via SF CLI from the repo; commit per step.

## In scope
1. `Deal_Registration__c` object + minimal fields
2. `Partner_Type__c` on Account (for lookup filter)
3. Before-save record-triggered Flow: eligibility + conflict check on create
4. Before-save record-triggered Flow (or same Flow, update path): stamp Approval Date + Protection End Date on approval
5. Validation rules: approval gate; rejection reason
6. Permission set (no profile changes)
7. Page layout / Lightning record page with key fields
8. Demo data script (3 scenarios)

## Out of scope (state in doc/README)
Partner Involvement object, Opportunity creation/linking on approval, dual-exec override approval, escalation, auto-renewal job, matching service (exact AccountId match only), portal.

## 1. Object: `Deal_Registration__c`
- Label: Deal Registration; Name: Auto Number `DR-{0000}`; OWD: Private; Track Field History on Status, Conflict Resolution.

| API name | Type | Notes |
|---|---|---|
| `Partner_Account__c` | Lookup(Account) | Required. Lookup filter: `Account.Partner_Type__c` not blank. |
| `End_Customer__c` | Lookup(Account) | Required. Relationship name `Deal_Registrations_End_Customer`. |
| `Partner_Role__c` | Picklist: Referral, Reseller, Marketplace | Required. |
| `Estimated_Amount__c` | Currency(16,2) | Required. |
| `Status__c` | Picklist: Submitted (default), Under Review, Not Eligible, Approved, Rejected, Expired, Closed – Won, Closed – Lost | Restricted picklist. |
| `Conflict_Flag__c` | Checkbox | Set by Flow; read-only on layout. |
| `Conflict_Reason__c` | Text(255) | Set by Flow (internal only): which rule fired. |
| `Conflict_Resolution__c` | Picklist: Partner Protected (Sourced), Direct Retains – Partner Influenced, Rejected | |
| `Override_Reason__c` | Long Text(1000) | |
| `Rejection_Reason__c` | Picklist: Existing Customer, Duplicate Registration, Direct Already Engaged, Insufficient Detail, Other | |
| `Opportunity__c` | Lookup(Opportunity) | |
| `Approval_Date__c` | Date | Set by Flow. |
| `Protection_End_Date__c` | Date | Set by Flow = Approval Date + 90. |

## 2. Account field
- `Partner_Type__c` — Picklist: Reseller, Referral, Marketplace.

## 3. Flow: `Deal_Registration_Before_Save_Checks` (record-triggered, before save, on Create)
Order of evaluation:
1. **Eligibility** — Get Records: Opportunity where `AccountId = End_Customer__c` AND `IsWon = true`, first record only.
   - Found → `Status__c = Not Eligible`, `Rejection_Reason__c = Existing Customer`. Stop.
2. **Conflict A — open, engaged opp** — Get Records: Opportunity where `AccountId = End_Customer__c` AND `IsClosed = false` AND (`StageName != 'Prospecting'` OR `LastActivityDate >= {!Today_Minus_30}`).
3. **Conflict B — recent loss** — Get Records: Opportunity where `AccountId = End_Customer__c` AND `IsClosed = true` AND `IsWon = false` AND `CloseDate >= {!Today_Minus_30}`.
   - A or B found → `Conflict_Flag__c = true`, `Status__c = Under Review`, `Conflict_Resolution__c = Direct Retains – Partner Influenced` (default), `Conflict_Reason__c` = "Open engaged opportunity" / "Closed Lost within 30 days".
   - Neither → leave `Status__c = Submitted`, `Conflict_Flag__c = false`.
- Formula resource `Today_Minus_30` = `TODAY() - 30`.
- First stage name `Prospecting` (dev org default) — note as config assumption; production would use Custom Metadata.
- Before-save only: no DML, no extra transactions.

## 4. Flow: `Deal_Registration_On_Approval` (before save, on Update)
- Entry: `Status__c` changed AND `Status__c = Approved`.
- Set `Approval_Date__c = TODAY()`, `Protection_End_Date__c = TODAY() + 90`.

## 5. Validation rules
- `Approval_Requires_Conflict_Resolution`:
  `AND(ISPICKVAL(Status__c, "Approved"), Conflict_Flag__c, ISBLANK(TEXT(Conflict_Resolution__c)))`
  → "Resolve the conflict before approving this registration."
- `Approval_Blocked_When_Resolution_Rejected`:
  `AND(ISPICKVAL(Status__c, "Approved"), ISPICKVAL(Conflict_Resolution__c, "Rejected"))`
  → "Conflict resolution is Rejected; set Status to Rejected instead."
- `Not_Eligible_Cannot_Be_Approved`:
  `AND(ISCHANGED(Status__c), ISPICKVAL(Status__c, "Approved"), ISPICKVAL(PRIORVALUE(Status__c), "Not Eligible"))`
  → "Existing customers are not eligible for registration."
- `Rejection_Requires_Reason`:
  `AND(ISPICKVAL(Status__c, "Rejected"), ISBLANK(TEXT(Rejection_Reason__c)))`
  → "Select a rejection reason so the partner gets a clear answer."
- `Override_Requires_Reason`:
  `AND(Conflict_Flag__c, ISPICKVAL(Conflict_Resolution__c, "Partner Protected (Sourced)"), ISBLANK(Override_Reason__c))`
  → "Overriding the default resolution requires a reason."

## 6. Permission set: `Partner_Deal_Registration_Manager`
- Deal_Registration__c: CRUD (no Modify All). FLS edit on all except `Conflict_Flag__c`, `Conflict_Reason__c`, `Approval_Date__c`, `Protection_End_Date__c` (read-only).
- Account `Partner_Type__c`: read.
- Assign to the running user for the demo.

## 7. Layout
Sections: Registration (Partner Account, End Customer, Role, Amount, Status) · Conflict (Flag, Reason, Resolution, Override Reason) · Decision (Rejection Reason, Approval Date, Protection End Date, Opportunity).

## 8. Demo data (anonymous Apex or `sf data tree`)
- Partner account: **Northwind Partners** (Partner_Type = Reseller).
- **Acme Corp** — Closed Won opp → registration becomes *Not Eligible*.
- **Globex** — open opp in Negotiation, owned by the AE → *Under Review* with conflict; demo the approval gate error, then choose resolution.
- **Initech** — no opps → *Submitted*; approve → dates stamped.

## Demo script (≤2 min)
1. (15s) Problem: reseller registered a deal AE worked for 4 months.
2. (30s) Register Globex → Under Review, conflict reason shown, default resolution pre-filled.
3. (20s) Try to approve with resolution cleared → validation blocks it.
4. (20s) Register Acme → Not Eligible (existing customer).
5. (20s) Register Initech → approve → Approval Date + Protection End Date stamped.
6. (15s) What's next: Partner Involvement, auto-renewal, matching service.

## Definition of done
- All metadata deployed from repo; each step committed.
- 3 demo scenarios behave as above.
- README lists in/out of scope and the assumptions (first stage name, exact AccountId matching).
