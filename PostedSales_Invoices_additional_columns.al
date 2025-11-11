// pageextension 98900 PageExtension50000 extends Microsoft.Sales.History."Posted Sales Invoices"
// {
//     layout
//     {
//         modify("No.")
//         {
//             Width = 31;
//         }
//         modify(Control1)
//         {
//             FreezeColumn = "Sell-to County11491";
//         }
//         addafter("Remaining Amount")
//         {
//             field("Sell-to County11491"; Rec."Sell-to County")
//             {
//                 ApplicationArea = All;
//                 Editable = false;
//             }
//             field("Ship-to County65357"; Rec."Ship-to County")
//             {
//                 ApplicationArea = All;
//                 Editable = false;
//             }
//         }
//     }
// }

pageextension 98900 PageExtension50000 extends Microsoft.Sales.History."Posted Sales Invoices"
{
    layout
    {
        modify("No.")
        {
            Width = 31;
        }
        modify(Control1)
        {
            FreezeColumn = "Sell-to County11491";
        }
        addlast(Control1)
        {
            field("Sell-to County11491"; Rec."Sell-to County")
            {
                ApplicationArea = All;
                Editable = false;
                Visible = false;
            }
            field("Ship-to County65357"; Rec."Ship-to County")
            {
                ApplicationArea = All;
                Editable = false;
                Visible = false;
            }
            field("Order Date"; Rec."Order Date")
            {
                ApplicationArea = All;
                Editable = false;
                Visible = false;
            }
        }
    }
}

