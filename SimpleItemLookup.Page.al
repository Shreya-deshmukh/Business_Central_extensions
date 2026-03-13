page 98921 "Simple Item Lookup"
{
    PageType = List;
    SourceTable = Item;
    Caption = 'Select Items';
    Editable = false;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ApplicationArea = All;
                }
                field("Base Unit of Measure"; Rec."Base Unit of Measure")
                {
                    ApplicationArea = All;
                }
                field(Inventory; Rec.Inventory)
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}
