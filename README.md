# Partner Deal Registration

A Salesforce build slice that checks every new partner deal registration against existing customers and open or recently lost opportunities before anyone can approve it.

It addresses a specific failure: a reseller registered a deal that an AE had worked for four months.

## How it works

Partners register deals through the **Partner Register Deal** screen flow (see below). When a Deal Registration is created, a before-save Flow evaluates the End Customer in this order:

| Condition | Result |
|---|---|
| End Customer is blank (the typed company name matched no Account) | Status = Under Review, reason "Customer not matched – confirm End Customer". No opportunity queries run. |
| Any Closed Won opportunity | Status = Not Eligible, Rejection Reason = Existing Customer |
| Open opportunity past Prospecting, or with activity in the last 30 days | Status = Under Review, conflict flagged, reason "Open engaged opportunity" |
| Closed Lost opportunity with a Close Date in the last 30 days | Status = Under Review, conflict flagged, reason "Closed Lost within 30 days" |
| None of the above | Status stays Submitted |

Flagged conflicts default to the resolution Direct Retains – Partner Influenced. Validation rules then control the decision, and a second before-save Flow stamps Approval Date and Protection End Date (Approval Date + 90 days) on approval.

End Customer is optional when a registration is submitted, but must be filled in before approval (`Approval_Requires_End_Customer`). End Customer Name and End Customer Domain store what the partner typed, so the partner manager can match it to an account.

### Partner view: registration flow

The **Partner Deal Registration** tab in the Sales app opens an app page hosting the `Partner_Register_Deal` screen flow. This is Portal V1: the same flow can be exposed in Experience Cloud later without a rebuild. The flow runs in user context.

1. The partner enters a company name, website or domain, their role and an estimated deal size. They type the company name and never browse Accounts. In the demo the Partner field defaults to Northwind Partners; in the portal it would come from the signed-in partner's account.
2. The flow looks for an Account whose name exactly matches the company name. This stands in for the matching service.
3. The flow creates the registration with the matched account as End Customer, or blank if nothing matched. The before-save Flow then sets Status.
4. The partner sees a result with their DR number: received, under review, or not eligible. The result never shows the conflict reason, opportunity details or other partners.

### Partner manager view: approve and reject

- The **Deal Registrations** tab in the Sales app has an **Open registrations** list view showing Submitted and Under Review registrations, with their conflict reasons.
- The record page has **Approve** and **Reject** quick actions, which appear only while Status is Submitted or Under Review.
  - **Approve** sets Status to Approved and shows Conflict Reason (read-only), Conflict Resolution, Override Reason and End Customer.
  - **Reject** sets Status to Rejected and requires a Rejection Reason.
- Both actions save through the normal record update, so every validation rule still applies.
- Status is read-only on the page layout, so it changes only through the actions.

## In scope

- `Deal_Registration__c` object and fields
- `Partner_Type__c` on Account, used by the Partner Account lookup filter
- Flow `Deal_Registration_Before_Save_Checks`: eligibility and conflict check on create
- Flow `Deal_Registration_On_Approval`: date stamping on approval
- Six validation rules: the approval gate (including End Customer required at approval), plus required rejection and override reasons
- Permission sets `Partner_Deal_Registration_Manager` and `Partner_Program_Admin`
- Page layout and tab
- Flow `Partner_Register_Deal`: partner-facing registration screen flow, on the **Partner Deal Registration** app page and tab
- **Approve** and **Reject** quick actions, plus the Deal Registration record page with Dynamic Actions
- **Open registrations** list view; both tabs added to the Sales app
- Demo data script

## Out of scope

- Partner Involvement object
- Opportunity creation or linking on approval (still out of scope after the partner flow was added)
- Dual-executive override approval process
- Escalation of unresolved conflicts
- Protection auto-renewal job
- Matching service or fuzzy matching. The flow uses an exact account-name match as a stand-in, and the checks match on exact AccountId.
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
  --source-dir force-app/main/default/flows/Partner_Register_Deal.flow-meta.xml \
  --source-dir force-app/main/default/flexipages/Partner_Deal_Registration.flexipage-meta.xml \
  --source-dir force-app/main/default/flexipages/Deal_Registration_Record_Page.flexipage-meta.xml \
  --source-dir force-app/main/default/tabs/Partner_Deal_Registration.tab-meta.xml \
  --source-dir force-app/main/default/quickActions \
  --source-dir force-app/main/default/applications/standard__LightningSales.app-meta.xml \
  --source-dir force-app/main/default/permissionsets/Partner_Deal_Registration_Manager.permissionset-meta.xml \
  --source-dir force-app/main/default/permissionsets/Partner_Program_Admin.permissionset-meta.xml

sf org assign permset --target-org <org-alias> \
  --name Partner_Deal_Registration_Manager --name Partner_Program_Admin

sf apex run --target-org <org-alias> --file scripts/apex/demo-data.apex
```

Assign the permission sets before running the demo data script, because the script sets `Partner_Type__c`. The script is safe to re-run.

The project's `sourceApiVersion` is 66.0, because the screen flow's styling needs Metadata API 66.0 or later to deploy and retrieve.

## Demo

Open the **Sales** app.

1. **Partner view:** on the **Partner Deal Registration** tab, register **Globex**. The partner sees "under review", with no conflict detail. Register **Acme Corp**: the partner sees the not-eligible message.
2. **Partner manager view:** on **Deal Registrations** → **Open registrations**, the Globex registration shows its conflict reason. Click **Approve** and clear Conflict Resolution: the save is blocked. Approve again with the default "Direct Retains – Partner Influenced": it saves.
3. Register **Initech** (it becomes Submitted), then click **Approve**. Approval Date and Protection End Date are stamped, and the Approve and Reject buttons disappear.
4. Optional: register **Hooli**, which has no matching Account. It becomes Under Review with "Customer not matched". Approve is blocked until an End Customer is chosen.

## Assumptions

- **First stage name:** the conflict check treats `Prospecting` as the first opportunity stage, the Developer Edition default. The value is hardcoded in the Flow; production would use Custom Metadata.
- **Exact matching:** conflicts are found only by exact `AccountId` match on the End Customer. Duplicate or related accounts are not detected.
- **Exact-name match in the flow:** the partner flow matches the typed company name to an Account by exact name (Salesforce compares names case-insensitively) and takes the first match. This stands in for the matching service. Misspellings and variants such as "Acme" versus "Acme Corp" won't match, so the registration goes to Under Review for the partner manager to match. Because the flow runs in user context, it only matches Accounts the user can see.
- **Demo partner default:** the flow pre-fills the Partner field by looking up the account named `Northwind Partners`. In the portal, the partner comes from the signed-in user.
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
- The three required Deal Registration fields (Partner Account, Partner Role, Estimated Amount) have no permission set entries because Salesforce does not allow them. They are always editable. End Customer is no longer required, so it now has an explicit entry in `Partner_Deal_Registration_Manager`, along with End Customer Name and Domain.
- `Partner_Register_Deal` is restricted to permission sets that grant it, and `Partner_Deal_Registration_Manager` grants it.
- `Partner_Deal_Registration_Manager` also includes the **Run Flows** system permission. Without it, Salesforce leaves the flow component off the Lightning page for non-admin users such as Standard User: the page shows no flow and no error, even with flow-specific access. Because the flow is restricted, holders still can't run it without this permission set.
- A Lightning record page was added and set as the org default for Deal Registration, because Dynamic Actions need one.
- On the page layout, End Customer is no longer Required, to match the field. End Customer Name and Domain were added as read-only.
- The Sales app metadata no longer lists `standard-WaveHome`. The org rejects that tab when the app is deployed, because it is not supported in Lightning apps.

## Verification

The three demo scenarios, all five validation rules, the lookup filter and the Flow date boundaries (losses at 30 and 31 days) were tested in the org through anonymous Apex, with all test records rolled back.

Tests T24–T32 for the partner flow and the Approve and Reject actions are in [docs/test-plan.md](docs/test-plan.md). All of them passed in both the data checks and the UI.
