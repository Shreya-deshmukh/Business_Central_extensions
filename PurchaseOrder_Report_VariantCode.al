reportextension 98905 PurchaseOrderReportExt extends 1322
{
    dataset
    {
        add("Purchase Line")
        {
            column(VariantCode; "Purchase Line"."Variant Code")
            {
                Caption = 'Variant Code';
            }
        }
    }
}

// reportextension 50100 "Purchase Order - Add VariantCode" extends 1322
// {
//     // Add the field to the Purchase Line dataitem in the dataset.
//     // Replace PurchaseLine with the exact dataitem name used in report 1322 if different.
//     dataset
//     {
//         addlast(PurchaseLine)
//         {
//             // Field name used in the dataset (VariantCode) and the source from the Purchase Line record
//             field(VariantCode; VariantCode)
//             {
//                 DataType = Text;
//                 Caption = 'Variant Code';
//             }
//         }
//     }
// }