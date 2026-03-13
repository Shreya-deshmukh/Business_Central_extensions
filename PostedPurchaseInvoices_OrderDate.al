pageextension 98905 PostedPurchaseInvoicesExt extends Microsoft.Purchases.History."Posted Purchase Invoices"
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
                ToolTip = 'Specifies the date when the related order was created.';

            }
        }
    }
}
