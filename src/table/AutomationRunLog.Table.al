table 98935 AutomationRunLog
{
    Caption = 'Automation Run Log';
    DataClassification = CustomerContent;

    fields
    {
        field(1; EntryNo; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(2; AutomationId; Integer)
        {
            Caption = 'Automation ID';
            TableRelation = AutomationSetup.Id;
        }
        field(3; AutomationName; Text[100])
        {
            Caption = 'Automation Name';
        }
        field(4; RunDateTime; DateTime)
        {
            Caption = 'Run Date/Time';
        }
        field(5; DurationSeconds; Integer)
        {
            Caption = 'Duration (sec)';
        }
        field(6; RunStatus; Enum LastRunStatus)
        {
            Caption = 'Status';
        }
        field(7; ErrorMessage; Text[2048])
        {
            Caption = 'Error Message';
        }
        field(8; RunBy; Code[50])
        {
            Caption = 'Run By';
        }
    }

    keys
    {
        key(PK; EntryNo)
        {
            Clustered = true;
        }
        key(ByAutomation; AutomationId, RunDateTime)
        {
        }
    }

    trigger OnInsert()
    begin
        Rec.RunDateTime := CurrentDateTime();
        Rec.RunBy := UserId();
    end;
}
