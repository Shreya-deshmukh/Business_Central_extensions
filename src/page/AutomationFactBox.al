page 98939 AutomationFactBox
{
    PageType = CardPart;
    SourceTable = AutomationSetup;
    Caption = 'Automation Details';
    ApplicationArea = All;
    Editable = false;
    RefreshOnActivate = true;

    layout
    {
        area(Content)
        {
            field(StatusFB; Rec.Status)
            {
                ApplicationArea = All;
                Caption = 'Status';
                ToolTip = 'Specifies the current execution status of this automation.';
                StyleExpr = StatusStyleExpr;
            }
            field(LastRunStatusFB; Rec.LastRunStatus)
            {
                ApplicationArea = All;
                Caption = 'Last Run Status';
                ToolTip = 'Specifies the result of the most recent execution.';
                StyleExpr = LastRunStatusStyleExpr;
            }
            field(LastRunFB; Rec.LastRun)
            {
                ApplicationArea = All;
                Caption = 'Last Run';
                ToolTip = 'Specifies the most recent execution time.';
            }
            field(NextRunFB; Rec.NextRun)
            {
                ApplicationArea = All;
                Caption = 'Next Run';
                ToolTip = 'Specifies when this automation is next scheduled to run.';
            }
            field(NextRunCountdown; NextRunCountdownTxt)
            {
                ApplicationArea = All;
                Caption = 'Countdown to Next Run';
                ToolTip = 'Specifies the time remaining until the next scheduled execution.';
            }
            field(TotalRunCountFB; Rec.TotalRunCount)
            {
                ApplicationArea = All;
                Caption = 'Total Runs';
                ToolTip = 'Specifies the total number of times this automation has executed.';
            }
            field(RunFrequencyFB; Rec.RunFrequency)
            {
                ApplicationArea = All;
                Caption = 'Frequency';
                ToolTip = 'Specifies how frequently this automation is scheduled to run.';
            }
            field(EnabledFB; Rec.Enabled)
            {
                ApplicationArea = All;
                Caption = 'Enabled';
                ToolTip = 'Specifies whether this automation is currently active.';
            }
        }
    }

    var
        StatusStyleExpr: Text;
        LastRunStatusStyleExpr: Text;
        NextRunCountdownTxt: Text;

    trigger OnAfterGetRecord()
    begin
        SetStyles();
        CalculateCountdown();
    end;

    local procedure SetStyles()
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

    local procedure CalculateCountdown()
    var
        Now: DateTime;
        DiffMs: BigInteger;
        TotalSeconds: BigInteger;
        Hours: BigInteger;
        Minutes: BigInteger;
        Seconds: BigInteger;
        NotScheduledLbl: Label 'Not scheduled';
        OverdueLbl: Label 'Overdue';
        CountdownFmtLbl: Label '%1h %2m %3s', Comment = '%1 = hours, %2 = minutes, %3 = seconds';
    begin
        if Rec.NextRun = 0DT then begin
            NextRunCountdownTxt := NotScheduledLbl;
            exit;
        end;

        Now := CurrentDateTime();
        if Rec.NextRun <= Now then begin
            NextRunCountdownTxt := OverdueLbl;
            exit;
        end;

        DiffMs := (Rec.NextRun - Now);
        TotalSeconds := DiffMs div 1000;
        Hours := TotalSeconds div 3600;
        Minutes := (TotalSeconds mod 3600) div 60;
        Seconds := TotalSeconds mod 60;
        NextRunCountdownTxt := StrSubstNo(CountdownFmtLbl, Hours, Minutes, Seconds);
    end;
}
