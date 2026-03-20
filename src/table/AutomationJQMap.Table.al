table 98943 "Automation JQ Map"
{
    Caption = 'Automation Job Queue Map';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Job Queue Entry No."; Integer)
        {
            Caption = 'Job Queue Entry No.';
        }
        field(2; "Automation Code"; Code[20])
        {
            Caption = 'Automation Code';
        }
    }

    keys
    {
        key(PK; "Job Queue Entry No.")
        {
            Clustered = true;
        }
    }
}
