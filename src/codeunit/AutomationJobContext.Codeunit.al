codeunit 98945 "Automation Job Context"
{
    SingleInstance = true;

    var
        JobQueueEntryNo: Integer;

    procedure SetCurrentJobQueueEntryNo(EntryNo: Integer)
    begin
        JobQueueEntryNo := EntryNo;
    end;

    procedure GetCurrentJobQueueEntryNo(): Integer
    begin
        exit(JobQueueEntryNo);
    end;

    procedure Clear()
    begin
        JobQueueEntryNo := 0;
    end;
}
