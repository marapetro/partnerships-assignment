// Demo data for the Deal Registration build slice. Fictional companies only.
// Safe to re-run: existing accounts and opportunities are reused, not duplicated.
// Creates accounts and opportunities only, so registrations can be entered live in the demo.
// Run: sf apex run --target-org myorg --file scripts/apex/demo-data.apex
// Assumption: this org's default stage names (Closed Won, Negotiation/Review).
// Opportunities are owned by the running user, who stands in for the AE.

Map<String, Account> accounts = new Map<String, Account>();
for (Account existing : [
    SELECT Id, Name, Partner_Type__c
    FROM Account
    WHERE Name IN ('Northwind Partners', 'Acme Corp', 'Globex', 'Initech')
]) {
    accounts.put(existing.Name, existing);
}
for (String name : new List<String>{ 'Northwind Partners', 'Acme Corp', 'Globex', 'Initech' }) {
    if (!accounts.containsKey(name)) {
        accounts.put(name, new Account(Name = name));
    }
}
accounts.get('Northwind Partners').Partner_Type__c = 'Reseller';
upsert accounts.values();

Set<String> existingOpps = new Set<String>();
for (Opportunity opp : [
    SELECT Name
    FROM Opportunity
    WHERE Name IN ('Acme Corp - Initial Deal', 'Globex - Platform Deal')
]) {
    existingOpps.add(opp.Name);
}

List<Opportunity> toInsert = new List<Opportunity>();
if (!existingOpps.contains('Acme Corp - Initial Deal')) {
    toInsert.add(new Opportunity(
        Name = 'Acme Corp - Initial Deal',
        AccountId = accounts.get('Acme Corp').Id,
        StageName = 'Closed Won',
        CloseDate = Date.today().addDays(-90),
        Amount = 120000
    ));
}
if (!existingOpps.contains('Globex - Platform Deal')) {
    toInsert.add(new Opportunity(
        Name = 'Globex - Platform Deal',
        AccountId = accounts.get('Globex').Id,
        StageName = 'Negotiation/Review',
        CloseDate = Date.today().addDays(30),
        Amount = 250000
    ));
}
insert toInsert;
