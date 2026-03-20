permissionset 98900 "Automation Mgmt"
{
    Caption = 'Automation Management';
    Assignable = true;

    Permissions =
        tabledata AutomationSetup = RIMD,
        tabledata AutomationRunLog = RIMD,
        tabledata "Job Queue Entry" = RIMD,
        tabledata "Automation Instance Seq" = RIMD,
        tabledata "Automation JQ Map" = RIMD,
        table AutomationSetup = X,
        table AutomationRunLog = X,
        table "Job Queue Entry" = X,
        table "Automation Instance Seq" = X,
        table "Automation JQ Map" = X,
        page AutomationManagement = X,
        page AutomationCard = X,
        page AutomationRunLogPart = X,
        page AutomationFactBox = X;
}
