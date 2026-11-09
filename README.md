# Partner Deal Registration

A Salesforce build slice that checks every new partner deal registration against existing customers and open or recently lost opportunities before anyone can approve it.

It addresses a specific failure: a reseller registered a deal that an AE had worked for four months.

## How it works

When a Deal Registration is created, a before-save Flow evaluates the End Customer in this order:

| Condition | Result |
|---|---|
| Any Closed Won opportunity | Status = Not Eligible, Rejection Reason = Existing Customer |
| Open opportunity past Prospecting, or with activity in the last 30 days | Status = Under Review, conflict flagged, reason "Open engaged opportunity" |
| Closed Lost opportunity with a Close Date in the last 30 days | Status = Under Review, conflict flagged, reason "Closed Lost within 30 days" |
| None of the above | Status stays Submitted |

Flagged conflicts default to the resolution Direct Retains – Partner Influenced. Validation rules then control the decision, and a second before-save Flow stamps Approval Date and Protection End Date (Approval Date + 90 days) on approval.

## In scope

- `Deal_Registration__c` object and fields
- `Partner_Type__c` on Account, used by the Partner Account lookup filter
- Flow `Deal_Registration_Before_Save_Checks`: eligibility and conflict check on create
- Flow `Deal_Registration_On_Approval`: date stamping on approval
- Five validation rules: the approval gate, plus required rejection and override reasons
- Permission sets `Partner_Deal_Registration_Manager` and `Partner_Program_Admin`
- Page layout and tab
- Demo data script

## Out of scope

- Partner Involvement object
- Opportunity creation or linking on approval
- Dual-executive override approval process
- Escalation of unresolved conflicts
- Protection auto-renewal job
- Matching service or fuzzy matching (exact AccountId match only)
- Experience Cloud partner portal

## Setup

Requires the Salesforce CLI and an authenticated Developer Edition org. Replace `<org-alias>` with your org's alias.

`force-app` also contains unrelated metadata retrieved from the original org, so deploy only these paths:

```sh
sf project deploy start --target-org <org-alias> \
  --source-dir force-app/main/default/objects/Account/fields/Partner_Type__c.field-meta.xml \
  --source-dir force-app/main/default/objects/Deal_Registration__c \
  --source-dir force-app/main/default/flows/Deal_Registration_Before_Save_Checks.flow-meta.xml \
  --source-dir force-app/main/default/flows/Deal_Registration_On_Approval.flow-meta.xml \
  --source-dir "force-app/main/default/layouts/Deal_Registration__c-Deal Registration Layout.layout-meta.xml" \
  --source-dir force-app/main/default/tabs/Deal_Registration__c.tab-meta.xml \
  --source-dir force-app/main/default/permissionsets/Partner_Deal_Registration_Manager.permissionset-meta.xml \
  --source-dir force-app/main/default/permissionsets/Partner_Program_Admin.permissionset-meta.xml

sf org assign permset --target-org <org-alias> \
  --name Partner_Deal_Registration_Manager --name Partner_Program_Admin

sf apex run --target-org <org-alias> --file scripts/apex/demo-data.apex
```

Assign the permission sets before running the demo data script, because the script sets `Partner_Type__c`. The script is safe to re-run.

## Demo

Open **Deal Registrations** from the App Launcher and create registrations with Northwind Partners as the Partner Account:

1. **Globex** becomes Under Review, with the conflict reason and default resolution filled in. Clear the resolution and set Status to Approved: the validation rule blocks the save.
2. **Acme Corp** becomes Not Eligible because it is an existing customer.
3. **Initech** stays Submitted. Set Status to Approved: Approval Date and Protection End Date are stamped.

## Assumptions

- **First stage name:** the conflict check treats `Prospecting` as the first opportunity stage, the Developer Edition default. The value is hardcoded in the Flow; production would use Custom Metadata.
- **Exact matching:** conflicts are found only by exact `AccountId` match on the End Customer. Duplicate or related accounts are not detected.
- **Demo stage names:** the demo data uses `Closed Won` and `Negotiation/Review`, the Developer Edition defaults.
- **Fixed windows:** the 30-day conflict window and 90-day protection period are hardcoded in the Flows.
- **Status and resolution values:** the Flows and validation rules reference picklist values by name, so renaming a value requires updating them.
- **Check runs once:** the eligibility and conflict check runs on create only. Changing the End Customer later does not re-run it.
- **Re-approval:** a record that leaves Approved and is approved again gets new dates, which restarts protection.
- **AE ownership:** demo opportunities are owned by the running user, who stands in for the AE.

## Differences from the build spec

- The validation rule specified as `Approval_Blocked_When_Resolution_Rejected` is named `Approval_Blocked_If_Resolution_Rejected`, because API names are limited to 40 characters.
- `Partner_Program_Admin` was added so that editing `Partner_Type__c` is separate from the manager role, which has read access only.
- A tab was added so the object can be reached in the UI.
- The four required Deal Registration fields have no permission set entries because Salesforce does not allow them. They are always editable.

## Verification

The three demo scenarios, all five validation rules, the lookup filter and the Flow date boundaries (losses at 30 and 31 days) were tested in the org through anonymous Apex, with all test records rolled back.
