codeunit 98947 "Automation JQ Schedule Subs"
{
    Access = Internal;
    Permissions = tabledata "Job Queue Entry" = R;

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
        InferredRunFrequency: Enum RunFrequency;
    begin
        if JobQueueEntry."Object Type to Run" <> JobQueueEntry."Object Type to Run"::Report then
            exit;
        if JobQueueEntry."Object ID to Run" <> 98920 then
            exit;

        AutomationCode := CopyStr(InstMgt.ResolveAutomationForJobQueue('QOH', JobQueueEntry."Entry No."), 1, 50);
        if AutomationCode = '' then
            exit;

        // Collection: Parameter String on insert; add GetReportParameters() after modify.
        CollectionName := GetScheduledCollection(JobQueueEntry, FromInsert);
        if CollectionName <> '' then
            AutomationName := CopyStr('Quantity on Hand & Usage - ' + CollectionName, 1, 100)
        else
            AutomationName := 'Quantity on Hand & Usage';

        NextRunDT := JobQueueEntry."Earliest Start Date/Time";
        FirstRunDT := GetInitialFirstRunDateTime(JobQueueEntry, NextRunDT);
        ScheduledRecipients := GetScheduledRecipients(JobQueueEntry);

        AutomationSetupRec.SetRange(AutomationCode, AutomationCode);
        if AutomationSetupRec.FindFirst() then begin
            // Never overwrite a concrete run-resolved name with a generic fallback.
            if (CollectionName <> '') and (AutomationSetupRec.AutomationName <> AutomationName) then
                AutomationSetupRec.AutomationName := AutomationName;
            if NextRunDT <> 0DT then
                AutomationSetupRec.NextRun := NextRunDT;
            if AutomationSetupRec.FirstRun = 0DT then
                AutomationSetupRec.FirstRun := FirstRunDT;
            if AutomationSetupRec.RunFrequency = Enum::RunFrequency::"Not Set" then begin
                InferredRunFrequency := InferRunFrequencyFromEarliestStartChange(JobQueueEntry, xJobQueueEntry);
                if InferredRunFrequency <> Enum::RunFrequency::"Not Set" then
                    AutomationSetupRec.RunFrequency := InferredRunFrequency;
            end;
            // Keep user's Enabled/Status choice. Still update the linkage to the concrete Job Queue Entry.
            if (AutomationSetupRec."Job Queue Entry No." = 0) or (AutomationSetupRec."Job Queue Entry No." <> JobQueueEntry."Entry No.") then
                AutomationSetupRec."Job Queue Entry No." := JobQueueEntry."Entry No.";
            // Populate initial email config from the scheduled request page, but do not override
            // values that the user has already set on the Automation Card.
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
        // Frequency can usually only be inferred after Job Queue updates the earliest start time.
        AutomationSetupRec.RunFrequency := Enum::RunFrequency::"Not Set";
        AutomationSetupRec.TotalRunCount := 0;
        ApplyInitialEmailConfigIfBlank(AutomationSetupRec, ScheduledRecipients, CollectionName);
        if NextRunDT <> 0DT then
            AutomationSetupRec.NextRun := NextRunDT;
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

    local procedure InferRunFrequencyFromEarliestStartChange(NewJobQueueEntry: Record "Job Queue Entry"; OldJobQueueEntry: Record "Job Queue Entry"): Enum RunFrequency
    var
        NewDT: DateTime;
        OldDT: DateTime;
        DaysDiff: Integer;
    begin
        NewDT := NewJobQueueEntry."Earliest Start Date/Time";
        OldDT := OldJobQueueEntry."Earliest Start Date/Time";

        if (NewDT = 0DT) or (OldDT = 0DT) then
            exit(Enum::RunFrequency::"Not Set");

        DaysDiff := DT2Date(NewDT) - DT2Date(OldDT);

        // Heuristic inference (Job Queue recurrence might shift by a few hours due to time zone/DST).
        if DaysDiff <= 1 then
            exit(Enum::RunFrequency::Daily);
        if (DaysDiff >= 5) and (DaysDiff <= 9) then
            exit(Enum::RunFrequency::Weekly);
        if (DaysDiff >= 20) and (DaysDiff <= 45) then
            exit(Enum::RunFrequency::Monthly);

        exit(Enum::RunFrequency::Custom);
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

