page 98936 AutomationManagement
{
    PageType = List;
    SourceTable = AutomationSetup;
    Caption = 'Automation Management';
    UsageCategory = Administration;
    ApplicationArea = All;
    CardPageId = AutomationCard;
    Editable = false;
    RefreshOnActivate = true;

    layout
    {
        area(Content)
        {
            repeater(Automations)
            {
                field(Id; Rec.Id)
                {
                    ApplicationArea = All;
                    Caption = 'ID';
                    ToolTip = 'Specifies the unique identifier for this automation.';
                    Editable = false;
                }
                field(AutomationName; Rec.AutomationName)
                {
                    ApplicationArea = All;
                    Caption = 'Automation Name';
                    ToolTip = 'Specifies the descriptive name of this automation.';
                    Editable = false;
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    Caption = 'Status';
                    ToolTip = 'Specifies the current execution status of this automation.';
                    Editable = false;
                    StyleExpr = StatusStyleExpr;
                }
                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                    Caption = 'Enabled';
                    ToolTip = 'Specifies whether this automation is currently active.';
                    Editable = false;
                }
                field(ScheduleFormula; Rec.ScheduleFormula)
                {
                    ApplicationArea = All;
                    Caption = 'Run Frequency';
                    ToolTip = 'Specifies how frequently this automation is scheduled to run (e.g. 1D, 1W, 1M, 2W).';
                    Editable = false;
                }
                field(FirstRun; Rec.FirstRun)
                {
                    ApplicationArea = All;
                    Caption = 'First Run';
                    ToolTip = 'Specifies when this automation first executed.';
                    Editable = false;
                }
                field(LastRun; Rec.LastRun)
                {
                    ApplicationArea = All;
                    Caption = 'Last Run';
                    ToolTip = 'Specifies the most recent execution time.';
                    Editable = false;
                }
                field(NextRun; Rec.NextRun)
                {
                    ApplicationArea = All;
                    Caption = 'Next Run';
                    ToolTip = 'Specifies the scheduled time for the next execution.';
                    Editable = false;
                }
                field(LastRunStatus; Rec.LastRunStatus)
                {
                    ApplicationArea = All;
                    Caption = 'Last Run Status';
                    ToolTip = 'Specifies the result of the most recent execution.';
                    Editable = false;
                    StyleExpr = LastRunStatusStyleExpr;
                    Visible = Rec.TotalRunCount > 0;
                }
                field(TotalRunCount; Rec.TotalRunCount)
                {
                    ApplicationArea = All;
                    Caption = 'Total Run Count';
                    ToolTip = 'Specifies the cumulative number of times this automation has executed.';
                    Editable = false;
                }
                field(CreatedAt; Rec.CreatedAt)
                {
                    ApplicationArea = All;
                    Caption = 'Created At';
                    ToolTip = 'Specifies the date and time when this record was created.';
                    Editable = false;
                }
                field(UpdatedAt; Rec.UpdatedAt)
                {
                    ApplicationArea = All;
                    Caption = 'Updated At';
                    ToolTip = 'Specifies the date and time when this record was last modified.';
                    Editable = false;
                }
            }
        }
        area(FactBoxes)
        {
            part(AutomationFactBox; AutomationFactBox)
            {
                ApplicationArea = All;
                Caption = 'Automation Details';
                SubPageLink = Id = field(Id);
            }
            systempart(Links; Links)
            {
                ApplicationArea = All;
            }
            systempart(Notes; Notes)
            {
                ApplicationArea = All;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            group(AutomationActions)
            {
                Caption = 'Actions';
                Image = Action;

                action(Enable)
                {
                    ApplicationArea = All;
                    Caption = 'Enable';
                    ToolTip = 'Enables the selected automation and sets its status to Running.';
                    Image = Start;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;

                    trigger OnAction()
                    var
                        ConfirmEnableLbl: Label 'Do you want to enable the automation "%1"?', Comment = '%1 = automation name';
                    begin
                        if not Confirm(ConfirmEnableLbl, true, Rec.AutomationName) then
                            exit;
                        EnableAutomation(Rec);
                    end;
                }
                action(Disable)
                {
                    ApplicationArea = All;
                    Caption = 'Disable';
                    ToolTip = 'Disables the selected automation and sets its status to Paused.';
                    Image = Stop;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;

                    trigger OnAction()
                    var
                        ConfirmDisableLbl: Label 'Do you want to disable the automation "%1"?', Comment = '%1 = automation name';
                    begin
                        if not Confirm(ConfirmDisableLbl, true, Rec.AutomationName) then
                            exit;
                        DisableAutomation(Rec);
                    end;
                }
                action(Refresh)
                {
                    ApplicationArea = All;
                    Caption = 'Refresh';
                    ToolTip = 'Reloads the list to show the latest automation data.';
                    Image = Refresh;
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    begin
                        CurrPage.Update(false);
                    end;
                }
            }
        }
    }

    var
        StatusStyleExpr: Text;
        LastRunStatusStyleExpr: Text;

    trigger OnAfterGetRecord()
    begin
        SetStatusStyle();
    end;

    local procedure SetStatusStyle()
    begin
        case Rec.Status of
            Enum::AutomationStatus::Running:
                StatusStyleExpr := 'Favorable';
            Enum::AutomationStatus::Failed:
                StatusStyleExpr := 'Unfavorable';
            Enum::AutomationStatus::Paused:
                StatusStyleExpr := 'Ambiguous';
            else
                StatusStyleExpr := 'Standard';
        end;

        case Rec.LastRunStatus of
            Enum::LastRunStatus::Success:
                LastRunStatusStyleExpr := 'Favorable';
            Enum::LastRunStatus::Failed:
                LastRunStatusStyleExpr := 'Unfavorable';
            Enum::LastRunStatus::Skipped:
                LastRunStatusStyleExpr := 'Ambiguous';
            else
                LastRunStatusStyleExpr := 'Standard';
        end;
    end;

    local procedure EnableAutomation(var AutomationSetupRec: Record AutomationSetup)
    var
        EnabledSuccessLbl: Label 'Automation "%1" has been enabled.', Comment = '%1 = automation name';
    begin
        AutomationSetupRec.Enabled := true;
        AutomationSetupRec.Status := Enum::AutomationStatus::Idle;
        AutomationSetupRec.Modify(true);
        SetLinkedJobQueueEntryStatus(AutomationSetupRec, true);
        Message(EnabledSuccessLbl, AutomationSetupRec.AutomationName);
        CurrPage.Update(false);
    end;

    local procedure DisableAutomation(var AutomationSetupRec: Record AutomationSetup)
    var
        DisabledSuccessLbl: Label 'Automation "%1" has been disabled.', Comment = '%1 = automation name';
    begin
        AutomationSetupRec.Enabled := false;
        AutomationSetupRec.Status := Enum::AutomationStatus::Paused;
        AutomationSetupRec.Modify(true);
        SetLinkedJobQueueEntryStatus(AutomationSetupRec, false);
        Message(DisabledSuccessLbl, AutomationSetupRec.AutomationName);
        CurrPage.Update(false);
    end;

    local procedure SetLinkedJobQueueEntryStatus(AutomationSetupRec: Record AutomationSetup; Enabled: Boolean)
    var
        JobQueueEntry: Record "Job Queue Entry";
        AutomationJQMapRec: Record "Automation JQ Map";
        JobQueueEntryNo: Integer;
        AutomationCode20: Code[20];
    begin
        JobQueueEntryNo := AutomationSetupRec."Job Queue Entry No.";

        // Fallback: if linkage wasn't persisted yet, resolve via Automation JQ Map.
        if JobQueueEntryNo = 0 then begin
            if AutomationSetupRec.AutomationCode = '' then
                exit;
            AutomationCode20 := CopyStr(AutomationSetupRec.AutomationCode, 1, MaxStrLen(AutomationJQMapRec."Automation Code"));
            AutomationJQMapRec.SetRange("Automation Code", AutomationCode20);
            if AutomationJQMapRec.FindFirst() then
                JobQueueEntryNo := AutomationJQMapRec."Job Queue Entry No.";
        end;

        if JobQueueEntryNo = 0 then
            exit;

        JobQueueEntry.SetRange("Entry No.", JobQueueEntryNo);
        if not JobQueueEntry.FindFirst() then
            exit;

        if Enabled then
            JobQueueEntry.Status := JobQueueEntry.Status::Ready
        else
            JobQueueEntry.Status := JobQueueEntry.Status::"On Hold";

        JobQueueEntry.Modify(true);
    end;
}
