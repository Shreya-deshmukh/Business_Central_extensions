codeunit 98947 "Automation JQ Schedule Subs"
{
    Access = Internal;
    Permissions = tabledata "Job Queue Entry" = RM;

    [EventSubscriber(ObjectType::Table, Database::"Job Queue Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure JobQueueEntry_OnAfterInsert(var Rec: Record "Job Queue Entry"; RunTrigger: Boolean)
    var
        xJobQueueEntry: Record "Job Queue Entry";
    begin
        // On insert, request-page data is often incomplete; reading the XML BLOB with
        // CreateInStream/ReadText can hit internal binary layouts and cause runtime errors
        // (e.g. invalid type conversions). Use light parsing only; full parse on modify.
        xJobQueueEntry.Init();
        HandleScheduleUpsert(Rec, true, xJobQueueEntry);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Job Queue Entry", 'OnAfterModifyEvent', '', false, false)]
    local procedure JobQueueEntry_OnAfterModify(var Rec: Record "Job Queue Entry"; var xRec: Record "Job Queue Entry"; RunTrigger: Boolean)
    begin
        HandleScheduleUpsert(Rec, false, xRec);
    end;

    local procedure HandleScheduleUpsert(var JobQueueEntry: Record "Job Queue Entry"; FromInsert: Boolean; var xJobQueueEntry: Record "Job Queue Entry")
    var
        InstMgt: Codeunit "Automation Instance Mgt";
        AutomationSetupRec: Record AutomationSetup;
        AutomationCode: Code[50];
        AutomationName: Text[100];
        NextRunDT: DateTime;
        ScheduledRecipients: Text[250];
        CollectionName: Text[100];
        FirstRunDT: DateTime;
        FormulaText: Text[20];
        ScheduledTime: Time;
    begin
        if JobQueueEntry."Object Type to Run" <> JobQueueEntry."Object Type to Run"::Report then
            exit;
        if JobQueueEntry."Object ID to Run" <> 98920 then
            exit;

        // Resolve AutomationCode first so we can fall back to the persisted ScheduledTime
        // when the Job Queue Entry no longer carries the time (e.g. after a run BC resets
        // Earliest Start Date/Time to midnight for formula-based frequencies).
        AutomationCode := CopyStr(InstMgt.ResolveAutomationForJobQueue('QOH', JobQueueEntry."Entry No."), 1, 50);
        if AutomationCode = '' then
            exit;

        ScheduledTime := ResolveScheduleTime(JobQueueEntry, xJobQueueEntry);
        // If the Job Queue Entry no longer carries a time (post-run reset), fall back to
        // the time we persisted when the schedule was first created or last known good.
        if ScheduledTime = 0T then
            ScheduledTime := GetPersistedScheduledTime(AutomationCode);

        // Fix in-memory ESD so GetEffectiveNextRunDateTime computes the right NextRun.
        NormalizeJobQueueEarliestStartDateTime(JobQueueEntry, ScheduledTime);
        // Persist Starting Time on the JQ entry (once, idempotent) so BC's own
        // scheduler always builds ESD = next_date + ScheduledTime going forward.
        EnsureJobQueueStartingTime(JobQueueEntry, ScheduledTime);

        CollectionName := GetScheduledCollection(JobQueueEntry, FromInsert);
        if CollectionName <> '' then
            AutomationName := CopyStr('Quantity on Hand & Usage - ' + CollectionName, 1, 100)
        else
            AutomationName := 'Quantity on Hand & Usage';

        NextRunDT := GetEffectiveNextRunDateTime(JobQueueEntry, ScheduledTime);
        FirstRunDT := GetInitialFirstRunDateTime(JobQueueEntry, NextRunDT);
        ScheduledRecipients := GetScheduledRecipients(JobQueueEntry);
        FormulaText := CopyStr(Format(JobQueueEntry."Next Run Date Formula"), 1, 20);

        AutomationSetupRec.SetRange(AutomationCode, AutomationCode);
        if AutomationSetupRec.FindFirst() then begin
            if (CollectionName <> '') and (AutomationSetupRec.AutomationName <> AutomationName) then
                AutomationSetupRec.AutomationName := AutomationName;
            if NextRunDT <> 0DT then
                AutomationSetupRec.NextRun := ResolveNextRunWithFallbackTime(NextRunDT, AutomationSetupRec.NextRun, ScheduledTime);
            // Safety net: if NextRun still has midnight time but ScheduledTime is known,
            // apply the time directly — guards against any fallback chain that missed.
            if (ScheduledTime <> 0T) and (AutomationSetupRec.NextRun <> 0DT) and
               (DT2Time(AutomationSetupRec.NextRun) = 0T)
            then
                AutomationSetupRec.NextRun := CreateDateTime(DT2Date(AutomationSetupRec.NextRun), ScheduledTime);
            if AutomationSetupRec.FirstRun = 0DT then
                AutomationSetupRec.FirstRun := FirstRunDT;
            // Always sync the raw formula from the Job Queue — this is the authoritative source.
            if FormulaText <> '' then
                AutomationSetupRec.ScheduleFormula := FormulaText;
            if (AutomationSetupRec."Job Queue Entry No." = 0) or (AutomationSetupRec."Job Queue Entry No." <> JobQueueEntry."Entry No.") then
                AutomationSetupRec."Job Queue Entry No." := JobQueueEntry."Entry No.";
            // Persist ScheduledTime so future post-run events can always recover it.
            if (ScheduledTime <> 0T) and (AutomationSetupRec.ScheduledTime <> ScheduledTime) then
                AutomationSetupRec.ScheduledTime := ScheduledTime;
            ApplyInitialEmailConfigIfBlank(AutomationSetupRec, ScheduledRecipients, CollectionName);
            AutomationSetupRec.Modify(true);
            exit;
        end;

        AutomationSetupRec.Init();
        AutomationSetupRec.AutomationCode := AutomationCode;
        AutomationSetupRec.AutomationName := AutomationName;
        AutomationSetupRec."Job Queue Entry No." := JobQueueEntry."Entry No.";
        AutomationSetupRec.Enabled := true;
        AutomationSetupRec.Status := Enum::AutomationStatus::Idle;
        AutomationSetupRec.FirstRun := FirstRunDT;
        AutomationSetupRec.ScheduleFormula := FormulaText;
        AutomationSetupRec.ScheduledTime := ScheduledTime;
        AutomationSetupRec.TotalRunCount := 0;
        ApplyInitialEmailConfigIfBlank(AutomationSetupRec, ScheduledRecipients, CollectionName);
        if NextRunDT <> 0DT then begin
            AutomationSetupRec.NextRun := ResolveNextRunWithFallbackTime(NextRunDT, 0DT, ScheduledTime);
            if (ScheduledTime <> 0T) and (DT2Time(AutomationSetupRec.NextRun) = 0T) then
                AutomationSetupRec.NextRun := CreateDateTime(DT2Date(AutomationSetupRec.NextRun), ScheduledTime);
        end;
        AutomationSetupRec.Insert(true);
    end;

    local procedure GetInitialFirstRunDateTime(JobQueueEntry: Record "Job Queue Entry"; NextRunDT: DateTime): DateTime
    begin
        // First Run represents when the report was scheduled for first execution.
        // Keep it stable forever (it is set only once).
        if NextRunDT <> 0DT then
            exit(NextRunDT);
        // When job queue is inserted the "Earliest Start Date/Time" might not be populated yet.
        // Return 0DT so the subsequent modify event can set the real first-run datetime.
        exit(0DT);
    end;

    local procedure GetEffectiveNextRunDateTime(JobQueueEntry: Record "Job Queue Entry"; ScheduledTime: Time): DateTime
    var
        NextRunDT: DateTime;
        NextDate: Date;
    begin
        NextRunDT := JobQueueEntry."Earliest Start Date/Time";
        if NextRunDT = 0DT then
            exit(0DT);

        // Job Queue can persist only the date part in Earliest Start Date/Time for recurrences.
        // In that case, preserve known schedule time so Automation Next Run remains accurate.
        if (DT2Time(NextRunDT) = 0T) and (ScheduledTime <> 0T) then begin
            NextDate := DT2Date(NextRunDT);
            exit(CreateDateTime(NextDate, ScheduledTime));
        end;

        exit(NextRunDT);
    end;

    local procedure NormalizeJobQueueEarliestStartDateTime(var JobQueueEntry: Record "Job Queue Entry"; ScheduledTime: Time)
    begin
        // Update Earliest Start Date/Time IN MEMORY ONLY so GetEffectiveNextRunDateTime
        // computes the correct NextRun for AutomationSetup.
        // DO NOT call Modify here — BC's JQ infrastructure reacts to any ESD change by
        // recalculating and resetting to midnight, so writing ESD directly triggers a
        // permanent fight we will always lose on the final write.
        // The time is persisted durably via EnsureJobQueueStartingTime (Starting Time field)
        // which BC itself uses when it computes ESD on each future reschedule.
        if JobQueueEntry."Earliest Start Date/Time" = 0DT then
            exit;
        if ScheduledTime = 0T then
            exit;
        if DT2Time(JobQueueEntry."Earliest Start Date/Time") <> 0T then
            exit;
        JobQueueEntry."Earliest Start Date/Time" :=
            CreateDateTime(DT2Date(JobQueueEntry."Earliest Start Date/Time"), ScheduledTime);
    end;

    local procedure EnsureJobQueueStartingTime(var JobQueueEntry: Record "Job Queue Entry"; ScheduledTime: Time)
    begin
        // Set Starting Time on the JQ entry once so BC's own scheduler uses it when
        // computing Earliest Start Date/Time after each run.  This is the correct, durable
        // way to keep the JQ entry display in sync — BC reads Starting Time and builds
        // ESD = CalcDate(formula) + Starting Time on every reschedule.
        // Idempotent: exits if already set to the right time, so the OnAfterModify
        // triggered by our Modify below will not loop (Starting Time already = ScheduledTime
        // → exits immediately on the recursive call).
        if ScheduledTime = 0T then
            exit;
        if JobQueueEntry."Starting Time" = ScheduledTime then
            exit;
        if JobQueueEntry."Starting Time" <> 0T then
            exit; // Never override a Starting Time the user set intentionally
        JobQueueEntry."Starting Time" := ScheduledTime;
        JobQueueEntry.Modify(true);
    end;

    local procedure GetPersistedScheduledTime(AutomationCode: Code[50]): Time
    var
        AutomationSetupRec: Record AutomationSetup;
        T: Time;
    begin
        AutomationSetupRec.SetRange(AutomationCode, AutomationCode);
        if not AutomationSetupRec.FindFirst() then
            exit(0T);

        // Prefer the explicitly stored scheduled time (populated after first run with fix deployed).
        if AutomationSetupRec.ScheduledTime <> 0T then
            exit(AutomationSetupRec.ScheduledTime);

        // For records created before the ScheduledTime field existed, derive from FirstRun.
        // FirstRun is set at initial scheduling from Earliest Start Date/Time and reliably
        // carries the originally intended time (e.g. 10:23 AM for a 10:23 AM schedule).
        T := DT2Time(AutomationSetupRec.FirstRun);
        if T <> 0T then
            exit(T);

        exit(0T);
    end;

    local procedure ResolveScheduleTime(JobQueueEntry: Record "Job Queue Entry"; xJobQueueEntry: Record "Job Queue Entry"): Time
    var
        ExistingTime: Time;
    begin
        if JobQueueEntry."Starting Time" <> 0T then
            exit(JobQueueEntry."Starting Time");

        ExistingTime := DT2Time(JobQueueEntry."Earliest Start Date/Time");
        if ExistingTime <> 0T then
            exit(ExistingTime);

        if xJobQueueEntry."Starting Time" <> 0T then
            exit(xJobQueueEntry."Starting Time");

        ExistingTime := DT2Time(xJobQueueEntry."Earliest Start Date/Time");
        if ExistingTime <> 0T then
            exit(ExistingTime);

        exit(0T);
    end;

    local procedure ResolveNextRunWithFallbackTime(CandidateNextRun: DateTime; ExistingNextRun: DateTime; ScheduledTime: Time): DateTime
    var
        EffectiveTime: Time;
    begin
        if CandidateNextRun = 0DT then
            exit(0DT);

        if DT2Time(CandidateNextRun) <> 0T then
            exit(CandidateNextRun);

        EffectiveTime := ScheduledTime;
        if (EffectiveTime = 0T) and (ExistingNextRun <> 0DT) then
            EffectiveTime := DT2Time(ExistingNextRun);

        if EffectiveTime = 0T then
            exit(CandidateNextRun);

        exit(CreateDateTime(DT2Date(CandidateNextRun), EffectiveTime));
    end;

    local procedure ApplyInitialEmailConfigIfBlank(var AutomationSetupRec: Record AutomationSetup; ScheduledRecipients: Text[250]; CollectionName: Text[100])
    begin
        if (AutomationSetupRec.RecipientEmails = '') and (ScheduledRecipients <> '') then
            AutomationSetupRec.RecipientEmails := CopyStr(ScheduledRecipients, 1, MaxStrLen(AutomationSetupRec.RecipientEmails));

        // Only set email subject/body defaults when the collection name is known.
        // When unknown (blank) we leave them empty so that the first actual run generates
        // them from the real SelectedCollection — preventing a stale "All" from persisting.
        if CollectionName = '' then
            exit;

        if AutomationSetupRec.EmailTitle = '' then
            AutomationSetupRec.EmailTitle := CopyStr(GetDefaultQOHEmailSubject(CollectionName), 1, MaxStrLen(AutomationSetupRec.EmailTitle));
        if AutomationSetupRec.EmailContent = '' then
            AutomationSetupRec.EmailContent := CopyStr(GetDefaultQOHEmailBody(CollectionName), 1, MaxStrLen(AutomationSetupRec.EmailContent));
    end;

    local procedure GetDefaultQOHEmailSubject(CollectionName: Text[100]): Text[250]
    var
        FormattedDate: Text[30];
    begin
        FormattedDate := Format(Today, 0, '<Month Text,3> <Day>, <Year4>');
        exit(CopyStr('Quantity on Hand & Usage Report - ' + CollectionName + ' - ' + FormattedDate, 1, 250));
    end;

    local procedure GetDefaultQOHEmailBody(CollectionName: Text[100]): Text[2048]
    var
        FormattedDate: Text[30];
    begin
        FormattedDate := Format(Today, 0, '<Month Text,3> <Day>, <Year4>');
        exit(CopyStr('<p>Please find attached the Quantity on Hand &amp; Usage Report for ' +
            CollectionName + ' generated on ' + FormattedDate + '.</p>', 1, 2048));
    end;

    /// <summary>
    /// Derives SelectedCollection from the Job Queue entry before the report runs.
    /// Do not read the raw XML BLOB with ReadText — SaaS may store a non-text layout and
    /// that can throw at runtime. Use GetReportParameters() instead (same as Codeunit 487).
    /// On insert, only Parameter String is used; on modify, GetReportParameters is included.
    /// Returns '' when unknown; explicit empty selection → 'All'.
    /// </summary>
    local procedure GetScheduledCollection(JobQueueEntry: Record "Job Queue Entry"; FromInsert: Boolean): Text[100]
    var
        ParamXml: Text;
        Inner: Text;
        Params: Text;
        DecodedParams: Text;
        LowerParams: Text;
        FromParams: Text;
    begin
        // Some deployments still surface key/value pairs here
        Params := JobQueueEntry."Parameter String";
        if Params <> '' then begin
            DecodedParams := UrlDecodeParamsForParsing(Params);
            LowerParams := LowerCase(DecodedParams);
            FromParams := TryExtractAfterKey(LowerParams, DecodedParams, 'selectedcollection');
            if FromParams <> '' then
                exit(CopyStr(FromParams, 1, 100));
        end;

        if FromInsert then
            exit('');

        ParamXml := JobQueueEntry.GetReportParameters();
        if ParamXml = '' then
            exit('');

        Inner := ExtractXmlFieldInnerText(ParamXml, 'SelectedCollection');
        if Inner <> '' then
            exit(CopyStr(Inner, 1, 100));

        if XmlFieldIsPresent(ParamXml, 'SelectedCollection') then
            exit('All');

        exit('');
    end;

    local procedure ExtractXmlFieldInnerText(XmlText: Text; FieldName: Text): Text
    var
        OpenTag: Text;
        StartPos: Integer;
        EndPos: Integer;
    begin
        OpenTag := 'name="' + FieldName + '">';
        StartPos := StrPos(XmlText, OpenTag);
        if StartPos = 0 then
            exit('');

        StartPos += StrLen(OpenTag);
        EndPos := StrPos(CopyStr(XmlText, StartPos), '</Field>');
        if EndPos <= 0 then
            exit('');
        exit(CopyStr(XmlText, StartPos, EndPos - 1));
    end;

    local procedure XmlFieldIsPresent(XmlText: Text; FieldName: Text): Boolean
    var
        SelfClose: Text;
        OpenTag: Text;
        StartPos: Integer;
    begin
        SelfClose := '<Field name="' + FieldName + '" />';
        if StrPos(XmlText, SelfClose) > 0 then
            exit(true);
        SelfClose := '<Field name="' + FieldName + '"/>';
        if StrPos(XmlText, SelfClose) > 0 then
            exit(true);

        OpenTag := 'name="' + FieldName + '">';
        StartPos := StrPos(XmlText, OpenTag);
        if StartPos = 0 then
            exit(false);
        StartPos += StrLen(OpenTag);
        if CopyStr(XmlText, StartPos, 9) = '</Field>' then
            exit(true);
        exit(false);
    end;

    local procedure GetScheduledRecipients(JobQueueEntry: Record "Job Queue Entry"): Text[250]
    var
        FromParamString: Text;
    begin
        // Recipients often appear only in GetReportParameters() XML (same as SelectedCollection),
        // not in "Parameter String", until the job runs — so we must fall back to XML for the card
        // to show addresses immediately after scheduling.
        FromParamString := GetScheduledRecipientsFromParameterString(JobQueueEntry);
        if FromParamString <> '' then
            exit(FromParamString);
        exit(GetScheduledRecipientsFromReportParameters(JobQueueEntry));
    end;

    local procedure GetScheduledRecipientsFromParameterString(JobQueueEntry: Record "Job Queue Entry"): Text[250]
    var
        Params: Text;
        DecodedParams: Text;
        PairTxt: Text;
        KeyTxt: Text;
        ValTxt: Text;
        AmpPos: Integer;
        LowerParams: Text;
        Extracted: Text;
    begin
        // The Job Queue stores report request page parameters in "Parameter String" (URL-like key/value pairs).
        Params := JobQueueEntry."Parameter String";
        if Params = '' then
            exit('');

        // In some runtimes, the whole parameter string is URL-encoded (e.g. '%26' for '&', '%3D' for '='),
        // which breaks simple key/value scanning. Decode the minimal separators first so parsing is reliable.
        DecodedParams := UrlDecodeParamsForParsing(Params);

        // Fast path: try to find common patterns even when the string isn't a simple key/value list.
        LowerParams := LowerCase(DecodedParams);
        Extracted := TryExtractAfterKey(LowerParams, DecodedParams, 'emailaddresses');
        if Extracted <> '' then
            exit(CopyStr(UrlDecodeEmailList(Extracted), 1, 250));

        // Split on '&' manually (List.Split is not available for Text in all runtimes).
        Params := DecodedParams;
        repeat
            AmpPos := StrPos(Params, '&');
            if AmpPos > 0 then begin
                PairTxt := CopyStr(Params, 1, AmpPos - 1);
                Params := CopyStr(Params, AmpPos + 1);
            end else begin
                PairTxt := Params;
                Params := '';
            end;

            if PairTxt = '' then
                ; // skip
            if PairTxt <> '' then
                if TrySplitFirst(PairTxt, '=', KeyTxt, ValTxt) then
                    if (LowerCase(KeyTxt) = 'emailaddresses') or (LowerCase(KeyTxt) = 'emailaddress') then
                        exit(CopyStr(UrlDecodeEmailList(ValTxt), 1, 250));
        until Params = '';

        exit('');
    end;

    /// <summary>
    /// Reads EmailAddresses from the serialized request page XML (ReportParameters blob).
    /// Used when "Parameter String" does not contain the list — typical when scheduling from the web client.
    /// </summary>
    local procedure GetScheduledRecipientsFromReportParameters(JobQueueEntry: Record "Job Queue Entry"): Text[250]
    var
        ParamXml: Text;
        Inner: Text;
    begin
        ParamXml := JobQueueEntry.GetReportParameters();
        if ParamXml = '' then
            exit('');

        Inner := ExtractXmlFieldInnerText(ParamXml, 'EmailAddresses');
        if Inner = '' then
            Inner := ExtractXmlFieldInnerText(ParamXml, 'emailaddresses');

        if Inner = '' then
            exit('');

        exit(CopyStr(UrlDecodeEmailList(Inner), 1, 250));
    end;

    local procedure TryExtractAfterKey(LowerSource: Text; OriginalSource: Text; KeyLower: Text): Text
    var
        P: Integer;
        StartPos: Integer;
        EndPos: Integer;
        Ch: Text[1];
        MaxLen: Integer;
    begin
        // Looks for:
        // - key=VALUE
        // - key:VALUE
        // - key%3dVALUE (url-encoded '=')
        // and returns VALUE up to '&' or end of string.
        P := StrPos(LowerSource, KeyLower + '=');
        if P = 0 then
            P := StrPos(LowerSource, KeyLower + ':');
        if P = 0 then
            P := StrPos(LowerSource, KeyLower + '%3d');
        if P = 0 then
            exit('');

        StartPos := P + StrLen(KeyLower);
        if CopyStr(LowerSource, StartPos, 3) = '%3d' then
            StartPos += 3
        else
            StartPos += 1; // '=' or ':'

        // Strip leading quotes
        if CopyStr(OriginalSource, StartPos, 1) = '"' then
            StartPos += 1;

        EndPos := StartPos;
        MaxLen := StrLen(OriginalSource);
        while EndPos <= MaxLen do begin
            Ch := CopyStr(OriginalSource, EndPos, 1);
            if (Ch = '&') or (Ch = '"') then
                exit(CopyStr(OriginalSource, StartPos, EndPos - StartPos));
            EndPos += 1;
        end;
        exit(CopyStr(OriginalSource, StartPos));
    end;

    local procedure TrySplitFirst(Source: Text; Separator: Text[1]; var Left: Text; var Right: Text): Boolean
    var
        P: Integer;
    begin
        P := StrPos(Source, Separator);
        if P <= 0 then
            exit(false);
        Left := CopyStr(Source, 1, P - 1);
        Right := CopyStr(Source, P + 1);
        exit(true);
    end;

    local procedure UrlDecodeEmailList(Source: Text): Text
    var
        OutTxt: Text;
    begin
        // Keep this intentionally minimal: we only need to decode email-list characters
        // as stored in Job Queue "Parameter String" (URL encoding).
        OutTxt := Source;
        OutTxt := OutTxt.Replace('+', ' ');

        // '@'
        OutTxt := OutTxt.Replace('%40', '@');
        // common delimiters and safe chars
        OutTxt := OutTxt.Replace('%3B', ';');
        OutTxt := OutTxt.Replace('%3b', ';');
        OutTxt := OutTxt.Replace('%2C', ',');
        OutTxt := OutTxt.Replace('%2c', ',');
        OutTxt := OutTxt.Replace('%20', ' ');
        OutTxt := OutTxt.Replace('%2E', '.');
        OutTxt := OutTxt.Replace('%2e', '.');
        OutTxt := OutTxt.Replace('%2D', '-');
        OutTxt := OutTxt.Replace('%2d', '-');
        OutTxt := OutTxt.Replace('%5F', '_');
        OutTxt := OutTxt.Replace('%5f', '_');

        exit(OutTxt);
    end;

    local procedure UrlDecodeParamsForParsing(Source: Text): Text
    var
        OutTxt: Text;
    begin
        // Decode only the pieces needed for key/value parsing.
        // (We still decode the extracted email value separately via UrlDecodeEmailList.)
        OutTxt := Source;
        OutTxt := OutTxt.Replace('+', ' ');

        // separators
        OutTxt := OutTxt.Replace('%26', '&');
        OutTxt := OutTxt.Replace('%3D', '=');
        OutTxt := OutTxt.Replace('%3d', '=');
        OutTxt := OutTxt.Replace('%3A', ':');
        OutTxt := OutTxt.Replace('%3a', ':');

        exit(OutTxt);
    end;

}

