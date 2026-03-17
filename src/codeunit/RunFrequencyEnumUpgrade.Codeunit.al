codeunit 98941 "Run Frequency Enum Upgrade"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    begin
        MigrateRunFrequencyToNotSetDefault();
    end;

    /// <summary>
    /// Migrates AutomationSetup.RunFrequency after adding "Not Set" as enum value 0.
    /// Old: 0=Daily, 1=Weekly, 2=Monthly, 3=Custom.
    /// New: 0=Not Set, 1=Daily, 2=Weekly, 3=Monthly, 4=Custom.
    /// Existing stored values 0..3 are shifted to 1..4 so display stays correct.
    /// </summary>
    local procedure MigrateRunFrequencyToNotSetDefault()
    var
        AutomationSetup: Record AutomationSetup;
        UpgradeTag: Codeunit "Upgrade Tag";
        UpgradeTagCode: Code[250];
        OldInt: Integer;
    begin
        UpgradeTagCode := 'QOH-98941-RunFrequencyNotSet-20260316';
        if UpgradeTag.HasUpgradeTag(UpgradeTagCode) then
            exit;

        if AutomationSetup.FindSet(true) then
            repeat
                OldInt := AutomationSetup.RunFrequency.AsInteger();
                if OldInt in [0 .. 3] then begin
                    AutomationSetup.RunFrequency := RunFrequency.FromInteger(OldInt + 1);
                    AutomationSetup.Modify(true);
                end;
            until AutomationSetup.Next() = 0;

        UpgradeTag.SetUpgradeTag(UpgradeTagCode);
    end;
}
