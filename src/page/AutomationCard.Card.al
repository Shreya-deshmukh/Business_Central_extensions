page 98937 AutomationCard
{
    PageType = Card;
    SourceTable = AutomationSetup;
    Caption = 'Automation Card';
    ApplicationArea = All;
    Editable = true;

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
                    Visible = Rec.TotalRunCount > 0;
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
                    MultiLine = true;
                }
                field(EmailTitleDisplay; EmailTitleDisplay)
                {
                    ApplicationArea = All;
                    Caption = 'Email Subject';
                    ToolTip = 'Specifies the subject line for the automation email. System-generated dynamic values are shown in square brackets for readability and are saved without brackets.';
                    Editable = IsEditMode;
                    MultiLine = true;

                    trigger OnValidate()
                    begin
                        EnsureDynamicPartsUnchanged(OriginalEmailTitleDisplay, EmailTitleDisplay);
                        Rec.EmailTitle := CopyStr(RemoveSquareBrackets(EmailTitleDisplay), 1, MaxStrLen(Rec.EmailTitle));
                        EmailTitleDisplay := FormatForDisplay(Rec.EmailTitle);
                    end;
                }
                field(EmailContentDisplay; EmailContentDisplay)
                {
                    ApplicationArea = All;
                    Caption = 'Email Body';
                    ToolTip = 'Specifies the body content for the automation email. System-generated dynamic values are shown in square brackets for readability and are saved without brackets.';
                    Editable = IsEditMode;
                    MultiLine = true;

                    trigger OnValidate()
                    begin
                        EnsureDynamicPartsUnchanged(OriginalEmailContentDisplay, EmailContentDisplay);
                        Rec.EmailContent := CopyStr(RemoveSquareBrackets(EmailContentDisplay), 1, MaxStrLen(Rec.EmailContent));
                        EmailContentDisplay := FormatForDisplay(Rec.EmailContent);
                    end;
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
                    CaptureOriginalDisplayValues();
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
                    EnsureDynamicPartsUnchanged(OriginalEmailTitleDisplay, EmailTitleDisplay);
                    EnsureDynamicPartsUnchanged(OriginalEmailContentDisplay, EmailContentDisplay);
                    Rec.EmailTitle := CopyStr(RemoveSquareBrackets(EmailTitleDisplay), 1, MaxStrLen(Rec.EmailTitle));
                    Rec.EmailContent := CopyStr(RemoveSquareBrackets(EmailContentDisplay), 1, MaxStrLen(Rec.EmailContent));
                    if (Rec.RecipientEmails = '') or (Rec.EmailTitle = '') or (Rec.EmailContent = '') then
                        Error(EmptyFieldsLbl);
                    Rec.UpdatedAt := CurrentDateTime();
                    Rec.Modify(true);
                    SyncDisplayFromRecord();
                    CaptureOriginalDisplayValues();
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
                        SyncDisplayFromRecord();
                        CaptureOriginalDisplayValues();
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
                        SetLinkedJobQueueEntryStatus(Rec, true);
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
                        SetLinkedJobQueueEntryStatus(Rec, false);
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
        EmailTitleDisplay: Text[250];
        EmailContentDisplay: Text[2048];
        OriginalEmailTitleDisplay: Text[250];
        OriginalEmailContentDisplay: Text[2048];

    trigger OnAfterGetRecord()
    begin
        SetStatusStyle();
        SyncDisplayFromRecord();
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

    local procedure SyncDisplayFromRecord()
    begin
        EmailTitleDisplay := FormatForDisplay(Rec.EmailTitle);
        EmailContentDisplay := FormatForDisplay(Rec.EmailContent);
    end;

    local procedure CaptureOriginalDisplayValues()
    begin
        OriginalEmailTitleDisplay := EmailTitleDisplay;
        OriginalEmailContentDisplay := EmailContentDisplay;
    end;

    local procedure FormatForDisplay(SourceText: Text): Text
    var
        DisplayText: Text;
        CollectionName: Text[100];
        FormattedDate: Text[30];
    begin
        DisplayText := SourceText;

        CollectionName := ExtractCollectionNameFromAutomationName();
        if CollectionName <> '' then
            DisplayText := AddSquareBracketsAroundToken(DisplayText, CollectionName);

        FormattedDate := Format(Today, 0, '<Month Text,3> <Day>, <Year4>');
        DisplayText := AddSquareBracketsAroundToken(DisplayText, FormattedDate);

        exit(DisplayText);
    end;

    local procedure ExtractCollectionNameFromAutomationName(): Text[100]
    var
        Prefix: Text;
        DashPos: Integer;
    begin
        Prefix := 'Quantity on Hand & Usage - ';
        if CopyStr(Rec.AutomationName, 1, StrLen(Prefix)) <> Prefix then
            exit('');

        DashPos := StrLen(Prefix) + 1;
        exit(CopyStr(Rec.AutomationName, DashPos, 100));
    end;

    local procedure AddSquareBracketsAroundToken(SourceText: Text; Token: Text): Text
    var
        OpenBracketToken: Text;
    begin
        if (SourceText = '') or (Token = '') then
            exit(SourceText);

        OpenBracketToken := '[' + Token + ']';
        if StrPos(SourceText, OpenBracketToken) > 0 then
            exit(SourceText);

        exit(SourceText.Replace(Token, OpenBracketToken));
    end;

    local procedure RemoveSquareBrackets(SourceText: Text): Text
    begin
        if SourceText = '' then
            exit(SourceText);

        exit(SourceText.Replace('[', '').Replace(']', ''));
    end;

    local procedure EnsureDynamicPartsUnchanged(OriginalDisplayText: Text; EditedDisplayText: Text)
    var
        BracketedToken: Text;
        DynamicPartLockedErr: Label 'System-generated dynamic part %1 cannot be modified. You can edit the surrounding text only.', Comment = '%1 = bracketed dynamic part';
        MissingDynamicPartErr: Label 'System-generated dynamic values are required and cannot be removed.';
    begin
        BracketedToken := GetFirstMissingBracketedToken(OriginalDisplayText, EditedDisplayText);
        if BracketedToken <> '' then begin
            if StrLen(BracketedToken) > 0 then
                Error(DynamicPartLockedErr, BracketedToken);
            Error(MissingDynamicPartErr);
        end;
    end;

    local procedure GetFirstMissingBracketedToken(SourceText: Text; EditedText: Text): Text
    var
        OpenPos: Integer;
        ClosePos: Integer;
        SearchText: Text;
        TokenValue: Text;
        BracketedToken: Text;
    begin
        SearchText := SourceText;

        repeat
            OpenPos := StrPos(SearchText, '[');
            if OpenPos = 0 then
                exit('');

            SearchText := CopyStr(SearchText, OpenPos + 1);
            ClosePos := StrPos(SearchText, ']');
            if ClosePos = 0 then
                exit('');

            TokenValue := CopyStr(SearchText, 1, ClosePos - 1);
            if TokenValue <> '' then begin
                BracketedToken := '[' + TokenValue + ']';
                if StrPos(EditedText, BracketedToken) = 0 then
                    exit(BracketedToken);
            end;

            SearchText := CopyStr(SearchText, ClosePos + 1);
        until SearchText = '';

        exit('');
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

        if not JobQueueEntry.Get(JobQueueEntryNo) then
            exit;

        if Enabled then
            JobQueueEntry.Status := JobQueueEntry.Status::Ready
        else
            JobQueueEntry.Status := JobQueueEntry.Status::"On Hold";

        JobQueueEntry.Modify(true);
    end;

}
