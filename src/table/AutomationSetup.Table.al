table 98934 AutomationSetup
{
    Caption = 'Automation Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; Id; Integer)
        {
            Caption = 'ID';
            AutoIncrement = true;
        }
        field(2; AutomationName; Text[100])
        {
            Caption = 'Automation Name';
        }
        field(3; FirstRun; DateTime)
        {
            Caption = 'First Run';
        }
        field(4; LastRun; DateTime)
        {
            Caption = 'Last Run';
        }
        field(5; NextRun; DateTime)
        {
            Caption = 'Next Run';
        }
        field(6; CreatedAt; DateTime)
        {
            Caption = 'Created At';
            Editable = false;
        }
        field(7; UpdatedAt; DateTime)
        {
            Caption = 'Updated At';
            Editable = false;
        }
        field(8; Enabled; Boolean)
        {
            Caption = 'Enabled';
        }
        field(9; RecipientEmails; Text[250])
        {
            Caption = 'Recipient Emails';

            trigger OnValidate()
            begin
                ValidateRecipientEmails(Rec.RecipientEmails);
            end;
        }
        field(10; EmailTitle; Text[250])
        {
            Caption = 'Email Subject';
        }
        field(11; EmailContent; Text[2048])
        {
            Caption = 'Email Body';
        }
        field(12; Status; Enum AutomationStatus)
        {
            Caption = 'Status';
        }
        field(13; RunFrequency; Enum RunFrequency)
        {
            Caption = 'Run Frequency';
        }
        field(14; LastRunStatus; Enum LastRunStatus)
        {
            Caption = 'Last Run Status';
        }
        field(15; TotalRunCount; Integer)
        {
            Caption = 'Total Run Count';
        }
        field(16; CreatedBy; Code[50])
        {
            Caption = 'Created By';
            Editable = false;
        }
        field(17; AutomationCode; Code[50])
        {
            Caption = 'Automation Code';
            ToolTip = 'Specifies the unique code used to identify this automation (e.g. QOH-ALL, QOH-COLLECTION1).';
        }
    }

    keys
    {
        key(PK; Id)
        {
            Clustered = true;
        }
        key(AutomationCode; AutomationCode)
        {
        }
    }

    trigger OnInsert()
    begin
        Rec.CreatedAt := CurrentDateTime();
        Rec.CreatedBy := UserId();
    end;

    trigger OnModify()
    begin
        Rec.UpdatedAt := CurrentDateTime();
    end;

    local procedure ValidateRecipientEmails(EmailList: Text[250])
    var
        EmailParts: List of [Text];
        SingleEmail: Text;
        InvalidEmailLbl: Label 'The email address "%1" is not valid. Please use a valid format (e.g. user@domain.com).', Comment = '%1 = email address';
    begin
        if EmailList = '' then
            exit;

        EmailParts := EmailList.Split(';');
        foreach SingleEmail in EmailParts do begin
            SingleEmail := SingleEmail.Trim();
            if SingleEmail <> '' then
                if not IsValidEmailFormat(SingleEmail) then
                    Error(InvalidEmailLbl, SingleEmail);
        end;
    end;

    local procedure IsValidEmailFormat(Email: Text): Boolean
    var
        AtPos: Integer;
        DotPos: Integer;
        LocalPart: Text;
        DomainPart: Text;
    begin
        AtPos := Email.LastIndexOf('@');
        if AtPos <= 1 then
            exit(false);

        LocalPart := CopyStr(Email, 1, AtPos - 1);
        DomainPart := CopyStr(Email, AtPos + 1);

        if LocalPart = '' then
            exit(false);
        if DomainPart = '' then
            exit(false);

        DotPos := DomainPart.LastIndexOf('.');
        if DotPos <= 1 then
            exit(false);
        if DotPos >= StrLen(DomainPart) then
            exit(false);

        exit(true);
    end;
}
