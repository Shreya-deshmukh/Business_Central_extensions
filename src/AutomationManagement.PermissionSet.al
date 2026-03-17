permissionset 98900 "Automation Mgmt"
{
    Caption = 'Automation Management';
    Assignable = true;

    Permissions =
        tabledata AutomationSetup = RIMD,
        tabledata AutomationRunLog = RIMD,
        table AutomationSetup = X,
        table AutomationRunLog = X,
        page AutomationManagement = X,
        page AutomationCard = X,
        page AutomationRunLogPart = X,
        page AutomationFactBox = X;
}
