# Test Plan

T1–T23 (the original build slice) are not recorded in this file. They were run through anonymous Apex with all records rolled back; see the README's Verification section. The tests below cover the addendum (`docs/build-slice-addendum.md`) and were run on 2026-11-10.

**How tests were run**
- **Data:** anonymous Apex against the org, using the same field updates the flow and quick actions make. Records were rolled back unless noted.
- **UI:** run by hand in Lightning Experience.

## Partner registration flow and approve/reject actions

| ID | Scenario | Expected | Data | UI |
|---|---|---|---|---|
| T24 | Flow: "Initech" | Result screen "Received… 2 business days"; record Submitted, End Customer = Initech. | Pass | Pass |
| T25 | Flow: "Acme Corp" | Not Eligible message; record Not Eligible. | Pass | Pass |
| T26 | Flow: "Globex" | Under Review message **with no conflict detail**; record Conflict Flag = true. | Pass | Pass |
| T27 | Flow: "Hooli" (no Account) | Under Review message; record End Customer blank, reason "Customer not matched…". | Pass | Pass |
| T28 | Approve T27 record without End Customer | Blocked by `Approval_Requires_End_Customer`. | Pass | Pass |
| T29 | Approve action on Globex with Resolution cleared | Blocked by approval gate. | Pass | Pass |
| T30 | Reject action without reason | Blocked. | Pass | Pass |
| T31 | Approved/Rejected record | Approve/Reject buttons hidden. | n/a | Pass |
| T32 | Inline edit Status on record page | Not possible (read-only). | n/a | Pass |

## Notes

- **T24–T27:** the data checks covered the before-save Flow on its own (rolled back) and the four registrations the flow created in the org (DR-0030 to DR-0033), which were kept.
- **T28–T30:** the blocking messages were:
  - T28: "Match this registration to an End Customer account before approving."
  - T29: "Resolve the conflict before approving this registration."
  - T30: "Select a rejection reason so the partner gets a clear answer."

  A control update, approving Globex with the default resolution, saved successfully.
- **T28 follow-up:** after the End Customer was matched, the Hooli registration was approved successfully (DR-0033).
