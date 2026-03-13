page 98922 "Item Variant Lookup"
{
    PageType = List;
    SourceTable = "Item Variant";
    Caption = 'Select Variants';
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item number.';
                }
                field(Code; Rec.Code)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the variant code.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the variant description.';
                }
            }
        }
    }
}
