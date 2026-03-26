codeunit 98940 AutomationManager
{
    /// <summary>
    /// Helper codeunit for automations to register, update status, and check enabled flag
    /// against the AutomationSetup table. Use from reports/codeunits that run as scheduled jobs.
    /// </summary>

    /// <summary>
    /// Registers a new automation or updates an existing one at the start of execution.
    /// If no record exists: inserts with Status=Running, Enabled=true, FirstRun/LastRun/CreatedAt/CreatedBy set.
    /// If record exists: sets Status=Running, LastRun, UpdatedAt, increments TotalRunCount, and updates AutomationName.
    /// Optionally pass email configuration to store on the record so the Automation Card reflects current recipients/subject/body.
    /// </summary>
    procedure RegisterOrUpdateOnStart(AutomationCode: Code[50]; AutomationName: Text[100]; RecipientEmails: Text[250]; EmailTitle: Text[250]; EmailContent: Text[2048]; JobQueueEntryNo: Integer)
    var
        AutomationSetupRec: Record AutomationSetup;
        Now: DateTime;
    begin
        // JobQueueEntryNo is passed for traceability / future use.
        Now := CurrentDateTime();
        AutomationSetupRec.SetRange(AutomationCode, AutomationCode);
        if AutomationSetupRec.FindFirst() then begin
            // Only increment when not already Running (avoids counting the same logical run multiple times)
            if AutomationSetupRec.Status <> Enum::AutomationStatus::Running then
                AutomationSetupRec.TotalRunCount := AutomationSetupRec.TotalRunCount + 1;
            AutomationSetupRec.AutomationName := CopyStr(AutomationName, 1, MaxStrLen(AutomationSetupRec.AutomationName));
            AutomationSetupRec.Status := Enum::AutomationStatus::Running;
            AutomationSetupRec.LastRun := Now;
            SetEmailConfigIfProvided(AutomationSetupRec, RecipientEmails, EmailTitle, EmailContent);
            AutomationSetupRec.Modify(true);
        end else begin
            AutomationSetupRec.Init();
            AutomationSetupRec.AutomationCode := AutomationCode;
            AutomationSetupRec.AutomationName := CopyStr(AutomationName, 1, MaxStrLen(AutomationSetupRec.AutomationName));
            AutomationSetupRec.Status := Enum::AutomationStatus::Running;
            AutomationSetupRec.Enabled := true;
            AutomationSetupRec.FirstRun := Now;
            AutomationSetupRec.LastRun := Now;
            AutomationSetupRec.CreatedAt := Now;
            AutomationSetupRec.CreatedBy := UserId();
            AutomationSetupRec.TotalRunCount := 1;
            SetEmailConfigIfProvided(AutomationSetupRec, RecipientEmails, EmailTitle, EmailContent);
            AutomationSetupRec.Insert(true);
        end;
    end;

    local procedure SetEmailConfigIfProvided(var AutomationSetupRec: Record AutomationSetup; RecipientEmails: Text[250]; EmailTitle: Text[250]; EmailContent: Text[2048])
    begin
        if RecipientEmails <> '' then
            AutomationSetupRec.RecipientEmails := CopyStr(RecipientEmails, 1, MaxStrLen(AutomationSetupRec.RecipientEmails));
        if EmailTitle <> '' then
            AutomationSetupRec.EmailTitle := CopyStr(EmailTitle, 1, MaxStrLen(AutomationSetupRec.EmailTitle));
        if EmailContent <> '' then
            AutomationSetupRec.EmailContent := CopyStr(EmailContent, 1, MaxStrLen(AutomationSetupRec.EmailContent));
    end;

    /// <summary>
    /// Updates the automation record after successful completion: Status=Idle, LastRunStatus=Success,
    /// LastRun and UpdatedAt set. NextRun is calculated from RunFrequency when set.
    /// </summary>
    procedure UpdateOnSuccess(AutomationCode: Code[50])
    var
        AutomationSetupRec: Record AutomationSetup;
        Now: DateTime;
        DurationSeconds: Integer;
    begin
        AutomationSetupRec.SetRange(AutomationCode, AutomationCode);
        if not AutomationSetupRec.FindFirst() then
            exit;
        Now := CurrentDateTime();
        DurationSeconds := CalcDurationInSeconds(AutomationSetupRec.LastRun, Now);

        AutomationSetupRec.Status := Enum::AutomationStatus::Idle;
        AutomationSetupRec.LastRun := Now;
        AutomationSetupRec.LastRunStatus := Enum::LastRunStatus::Success;
        AutomationSetupRec.NextRun := CalcNextRun(AutomationSetupRec.ScheduleFormula, AutomationSetupRec.ScheduledTime, Now);
        AutomationSetupRec.Modify(true);

        InsertRunLogEntry(AutomationSetupRec, Enum::LastRunStatus::Success, '', DurationSeconds);
    end;

    /// <summary>
    /// Marks the automation as failed: Status=Failed, LastRunStatus=Failed, UpdatedAt set.
    /// Call from a wrapper when execution fails (e.g. after Report.Run returns false).
    /// </summary>
    procedure UpdateOnFailure(AutomationCode: Code[50]; ErrorMessage: Text[2048])
    var
        AutomationSetupRec: Record AutomationSetup;
        Now: DateTime;
        DurationSeconds: Integer;
    begin
        AutomationSetupRec.SetRange(AutomationCode, AutomationCode);
        if not AutomationSetupRec.FindFirst() then
            exit;
        Now := CurrentDateTime();
        DurationSeconds := CalcDurationInSeconds(AutomationSetupRec.LastRun, Now);

        AutomationSetupRec.Status := Enum::AutomationStatus::Failed;
        AutomationSetupRec.LastRunStatus := Enum::LastRunStatus::Failed;
        AutomationSetupRec.Modify(true);

        InsertRunLogEntry(AutomationSetupRec, Enum::LastRunStatus::Failed, CopyStr(ErrorMessage, 1, 2048), DurationSeconds);
    end;

    /// <summary>
    /// Returns true if the automation is enabled (or no record exists yet, allowing first run).
    /// Returns false if a record exists and Enabled is false.
    /// </summary>
    procedure IsEnabled(AutomationCode: Code[50]): Boolean
    var
        AutomationSetupRec: Record AutomationSetup;
    begin
        AutomationSetupRec.SetRange(AutomationCode, AutomationCode);
        if not AutomationSetupRec.FindFirst() then
            exit(true); // No record yet: allow execution (will register on start)
        exit(AutomationSetupRec.Enabled);
    end;

    local procedure CalcNextRun(RunFrequency: Text[20]; ScheduledTime: Time; LastRun: DateTime): DateTime
    var
        NextDate: Date;
        NextTime: Time;
        Formula: DateFormula;
    begin
        if RunFrequency = '' then
            exit(0DT);
        Evaluate(Formula, '<' + RunFrequency + '>');
        NextDate := CalcDate(Formula, DT2Date(LastRun));
        // Use the persisted scheduled time when available so the next run is always
        // at the intended hour (not the actual execution time which may drift).
        if ScheduledTime <> 0T then
            NextTime := ScheduledTime
        else begin
            NextTime := DT2Time(LastRun);
            if NextTime = 0T then
                NextTime := 000000T;
        end;
        exit(CreateDateTime(NextDate, NextTime));
    end;

    local procedure CalcDurationInSeconds(StartDateTime: DateTime; EndDateTime: DateTime): Integer
    var
        DiffMs: BigInteger;
    begin
        if (StartDateTime = 0DT) or (EndDateTime = 0DT) then
            exit(0);
        DiffMs := EndDateTime - StartDateTime;
        if DiffMs <= 0 then
            exit(0);
        exit(DiffMs div 1000);
    end;

    local procedure InsertRunLogEntry(AutomationSetupRec: Record AutomationSetup; RunStatus: Enum LastRunStatus; ErrorMessage: Text[2048]; DurationSeconds: Integer)
    var
        RunLog: Record AutomationRunLog;
    begin
        RunLog.Init();
        RunLog.AutomationId := AutomationSetupRec.Id;
        RunLog.AutomationName := AutomationSetupRec.AutomationName;
        RunLog.DurationSeconds := DurationSeconds;
        RunLog.RunStatus := RunStatus;
        RunLog.ErrorMessage := ErrorMessage;
        RunLog.Insert(true);
    end;
}
