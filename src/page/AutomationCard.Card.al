page 98937 AutomationCard
{
    PageType = Card;
    SourceTable = AutomationSetup;
    Caption = 'Automation Card';
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

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
                field(RunFrequency; Rec.RunFrequency)
                {
                    ApplicationArea = All;
                    Caption = 'Run Frequency';
                    ToolTip = 'Specifies how frequently this automation is scheduled to run.';
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
                field(TotalRunCount; Rec.TotalRunCount)
                {
                    ApplicationArea = All;
                    Caption = 'Total Run Count';
                    ToolTip = 'Specifies the cumulative number of times this automation has executed.';
                    Editable = false;
                }
                field(LastRunStatus; Rec.LastRunStatus)
                {
                    ApplicationArea = All;
                    Caption = 'Last Run Status';
                    ToolTip = 'Specifies the result of the most recent execution.';
                    Editable = false;
                    StyleExpr = LastRunStatusStyleExpr;
                }
                field(CreatedBy; Rec.CreatedBy)
                {
                    ApplicationArea = All;
                    Caption = 'Created By';
                    ToolTip = 'Specifies the user who created this automation record.';
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
            group(EmailConfiguration)
            {
                Caption = 'Email Configuration';

                field(RecipientEmails; Rec.RecipientEmails)
                {
                    ApplicationArea = All;
                    Caption = 'Recipient Emails';
                    ToolTip = 'Specifies the semicolon-separated list of recipient email addresses.';
                    Editable = IsEditMode;
                }
                field(EmailTitle; Rec.EmailTitle)
                {
                    ApplicationArea = All;
                    Caption = 'Email Subject';
                    ToolTip = 'Specifies the subject line for the automation email.';
                    Editable = IsEditMode;
                }
                field(EmailContent; Rec.EmailContent)
                {
                    ApplicationArea = All;
                    Caption = 'Email Body';
                    ToolTip = 'Specifies the body content for the automation email.';
                    Editable = IsEditMode;
                    MultiLine = true;
                }
            }
            part(RunHistory; AutomationRunLogPart)
            {
                ApplicationArea = All;
                Caption = 'Run History';
                SubPageLink = AutomationId = field(Id);
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
            action(EditAction)
            {
                ApplicationArea = All;
                Caption = 'Edit';
                ToolTip = 'Switch to edit mode to update the email configuration for this automation.';
                Image = Edit;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Visible = not IsEditMode;

                trigger OnAction()
                begin
                    IsEditMode := true;
                    CurrPage.Update(false);
                end;
            }
            action(SaveAction)
            {
                ApplicationArea = All;
                Caption = 'Save';
                ToolTip = 'Save the email configuration changes for this automation.';
                Image = Save;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Visible = IsEditMode;

                trigger OnAction()
                var
                    EmptyFieldsLbl: Label 'Recipient Emails, Email Subject, and Email Body cannot be empty before saving.';
                    SaveConfirmLbl: Label 'Do you want to save the email configuration changes?';
                begin
                    if not Confirm(SaveConfirmLbl, true) then
                        exit;
                    if (Rec.RecipientEmails = '') or (Rec.EmailTitle = '') or (Rec.EmailContent = '') then
                        Error(EmptyFieldsLbl);
                    Rec.UpdatedAt := CurrentDateTime();
                    Rec.Modify(true);
                    IsEditMode := false;
                    CurrPage.Update(false);
                end;
            }
            action(Cancel)
            {
                ApplicationArea = All;
                Caption = 'Cancel';
                ToolTip = 'Discard any unsaved changes and exit edit mode.';
                Image = Cancel;
                Promoted = true;
                PromotedCategory = Process;
                Visible = IsEditMode;

                trigger OnAction()
                var
                    DiscardChangesLbl: Label 'Do you want to discard your unsaved changes?';
                begin
                    if Confirm(DiscardChangesLbl, true) then begin
                        Rec.Get(Rec.Id);
                        IsEditMode := false;
                        CurrPage.Update(false);
                    end;
                end;
            }
            action(Enable)
            {
                ApplicationArea = All;
                Caption = 'Enable';
                ToolTip = 'Enables this automation and sets its status to Running.';
                Image = Start;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    ConfirmEnableLbl: Label 'Do you want to enable the automation "%1"?', Comment = '%1 = automation name';
                begin
                    if Confirm(ConfirmEnableLbl, true, Rec.AutomationName) then begin
                        Rec.Enabled := true;
                        Rec.Status := Enum::AutomationStatus::Running;
                        Rec.Modify(true);
                        CurrPage.Update(false);
                    end;
                end;
            }
            action(Disable)
            {
                ApplicationArea = All;
                Caption = 'Disable';
                ToolTip = 'Disables this automation and sets its status to Paused.';
                Image = Stop;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    ConfirmDisableLbl: Label 'Do you want to disable the automation "%1"?', Comment = '%1 = automation name';
                begin
                    if Confirm(ConfirmDisableLbl, true, Rec.AutomationName) then begin
                        Rec.Enabled := false;
                        Rec.Status := Enum::AutomationStatus::Paused;
                        Rec.Modify(true);
                        CurrPage.Update(false);
                    end;
                end;
            }
        }
    }

    var
        IsEditMode: Boolean;
        StatusStyleExpr: Text;
        LastRunStatusStyleExpr: Text;

    trigger OnAfterGetRecord()
    begin
        SetStatusStyle();
    end;

    trigger OnOpenPage()
    begin
        IsEditMode := false;
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

}
