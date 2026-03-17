pageextension 98940 AutomationMgmtRoleCenterExt extends "Business Manager Role Center"
{
    actions
    {
        addlast(Sections)
        {
            group(AutomationMgmtGroup)
            {
                Caption = 'Automation';
                ToolTip = 'Navigate to Automation Management.';
                Image = Action;

                action(OpenAutomationManagement)
                {
                    ApplicationArea = All;
                    Caption = 'Automation Management';
                    ToolTip = 'Opens the Automation Management list to view and manage all running automations.';
                    RunObject = page AutomationManagement;
                    Image = Action;
                }
            }
        }
    }
}
