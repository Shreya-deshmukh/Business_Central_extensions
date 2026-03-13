pageextension 98906 PostedPurchaseReceiptsExt extends Microsoft.Purchases.History."Posted Purchase Receipts"
{
    layout
    {
        addafter("No.")
        {
            field("Order Date"; Rec."Order Date")
            {
                ApplicationArea = All;
                Editable = false;
                Visible = false;
                ToolTip = 'Specifies the date when the order was created.';
            }
            field("Order No."; Rec."Order No.")
            {
                ApplicationArea = All;
                Editable = false;
                Visible = false;
                ToolTip = 'Specifies the number of the order that created the entry.';
            }
        }
    }
}
