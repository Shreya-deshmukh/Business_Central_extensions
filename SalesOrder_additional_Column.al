pageextension 98901 PageExtension50007 extends Microsoft.Sales.Document."Sales Order List"
{
    layout
    {
        modify("No.")
        {
            Width = 16;
        }
        addafter("No.")
        {
            field("Order Date05400"; Rec."Order Date")
            {
                ApplicationArea = All;
                Editable = false;
                Visible = false;

            }
        }
    }
}
