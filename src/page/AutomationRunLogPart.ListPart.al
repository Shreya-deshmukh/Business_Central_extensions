page 98938 AutomationRunLogPart
{
    PageType = ListPart;
    SourceTable = AutomationRunLog;
    Caption = 'Run History';
    ApplicationArea = All;
    Editable = false;
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(RunLog)
            {
                field(EntryNo; Rec.EntryNo)
                {
                    ApplicationArea = All;
                    Caption = 'Entry No.';
                    ToolTip = 'Specifies the unique sequential entry number for this log record.';
                }
                field(RunDateTime; Rec.RunDateTime)
                {
                    ApplicationArea = All;
                    Caption = 'Run Date/Time';
                    ToolTip = 'Specifies the date and time when this run was executed.';
                }
                field(DurationSeconds; Rec.DurationSeconds)
                {
                    ApplicationArea = All;
                    Caption = 'Duration (sec)';
                    ToolTip = 'Specifies how long the run took in seconds.';
                }
                field(RunStatus; Rec.RunStatus)
                {
                    ApplicationArea = All;
                    Caption = 'Status';
                    ToolTip = 'Specifies the result of this particular run.';
                    StyleExpr = RunStatusStyleExpr;
                }
                field(RunBy; Rec.RunBy)
                {
                    ApplicationArea = All;
                    Caption = 'Run By';
                    ToolTip = 'Specifies the user or process that triggered this run.';
                }
                field(ErrorMessage; Rec.ErrorMessage)
                {
                    ApplicationArea = All;
                    Caption = 'Error Message';
                    ToolTip = 'Specifies the error details if this run failed.';
                }
            }
        }
    }

    var
        RunStatusStyleExpr: Text;

    trigger OnAfterGetRecord()
    begin
        case Rec.RunStatus of
            Enum::LastRunStatus::Success:
                RunStatusStyleExpr := 'Favorable';
            Enum::LastRunStatus::Failed:
                RunStatusStyleExpr := 'Unfavorable';
            Enum::LastRunStatus::Skipped:
                RunStatusStyleExpr := 'Ambiguous';
            else
                RunStatusStyleExpr := 'Standard';
        end;
    end;
}
