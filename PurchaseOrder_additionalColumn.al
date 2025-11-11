pageextension 98903 PageExtension50007_17652 extends Microsoft.Purchases.Document."Purchase Order List"
{
    layout
    {
        addafter("No.")
        {
            field("Order Date64619"; Rec."Order Date")
            {
                ApplicationArea = All;
                Editable = false;
                Visible = false;
            }
        }
    }
}
