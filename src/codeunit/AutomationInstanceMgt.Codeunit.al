codeunit 98944 "Automation Instance Mgt"
{
    /// <summary>
    /// Assigns unique automation instance codes per report type (prefix), e.g. QOH01, QOH02, SD01.
    /// Future reports: use a distinct prefix (e.g. SD for Sales Details), OnOpenPage GetNextInstanceCode('SD'),
    /// and a subscriber on Job Queue Start Report for that report object id.
    /// </summary>

    /// <summary>
    /// Returns the next code for the given prefix (e.g. QOH → QOH01, QOH02; SD → SD01, SD02).
    /// </summary>
    procedure GetNextInstanceCode(Prefix: Code[10]): Code[20]
    var
        Seq: Record "Automation Instance Seq";
    begin
        if Prefix = '' then
            Error('Automation instance prefix must not be empty.');
        if not Seq.Get(Prefix) then begin
            Seq.Init();
            Seq.Prefix := Prefix;
            Seq."Last No." := 0;
            Seq.Insert();
        end;
        Seq.LockTable();
        Seq.Get(Prefix);
        Seq."Last No." += 1;
        Seq.Modify();
        exit(CopyStr(Prefix + FormatInstanceNo(Seq."Last No."), 1, 20));
    end;

    /// <summary>
    /// For job queue runs where request page did not persist an instance code: one stable code per Job Queue Entry No.
    /// </summary>
    procedure ResolveAutomationForJobQueue(Prefix: Code[10]; JobQueueEntryNo: Integer): Code[20]
    var
        Map: Record "Automation JQ Map";
    begin
        if JobQueueEntryNo = 0 then
            exit('');
        if Map.Get(JobQueueEntryNo) then
            exit(Map."Automation Code");
        Map.Init();
        Map."Job Queue Entry No." := JobQueueEntryNo;
        Map."Automation Code" := CopyStr(GetNextInstanceCode(Prefix), 1, MaxStrLen(Map."Automation Code"));
        Map.Insert(true);
        exit(Map."Automation Code");
    end;

    local procedure FormatInstanceNo(SeqNo: Integer): Text
    var
        T: Text;
    begin
        T := Format(SeqNo);
        if StrLen(T) = 1 then
            exit('0' + T);
        exit(T);
    end;
}
