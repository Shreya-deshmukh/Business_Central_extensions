table 98930 "QOH Email Recipient"
{
    Caption = 'QOH Email Recipient';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(2; "Email Address"; Text[250])
        {
            Caption = 'Email Address';
            ExtendedDatatype = EMail;
        }
        field(3; "Recipient Name"; Text[100])
        {
            Caption = 'Recipient Name';
        }
        field(4; Active; Boolean)
        {
            Caption = 'Active';
            InitValue = true;
        }
    }
    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }
}
