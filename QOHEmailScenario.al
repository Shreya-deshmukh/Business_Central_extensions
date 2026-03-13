// ────────────────────────────────────────────────────────────────────────────
// QOHEmailScenario.AL
//
// Registers a custom Email Scenario enum value used exclusively by the
// Quantity on Hand & Usage report when sending scheduled email deliveries.
//
// POST-DEPLOY SETUP (one-time, required):
//   1. Go to Business Central → search "Email Accounts"
//   2. Open your configured SMTP account
//   3. Click "Email Scenarios" in the ribbon
//   4. Assign "QOH Report" to this SMTP account
//
//   Without this mapping, Email.Send() will throw:
//   "No email account is set up for scenario QOH Report"
// ────────────────────────────────────────────────────────────────────────────

enumextension 98920 "QOH Email Scenario Ext" extends "Email Scenario"
{
    value(98920; "QOH Report")
    {
        Caption = 'QOH Report';
    }
}
