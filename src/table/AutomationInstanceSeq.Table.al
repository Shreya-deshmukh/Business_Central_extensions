table 98942 "Automation Instance Seq"
{
    Caption = 'Automation Instance Sequence';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; Prefix; Code[10])
        {
            Caption = 'Prefix';
            NotBlank = true;
        }
        field(2; "Last No."; Integer)
        {
            Caption = 'Last No.';
            MinValue = 0;
        }
    }

    keys
    {
        key(PK; Prefix)
        {
            Clustered = true;
        }
    }
}
