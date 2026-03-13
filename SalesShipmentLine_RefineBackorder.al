tableextension 98908 "Sales Shipment Line Ext" extends "Sales Shipment Line"
{
    fields
    {
        field(98900; "Total Quantity Shipped"; Decimal)
        {
            Caption = 'Total Quantity Shipped';
            DataClassification = ToBeClassified;
        }
    }
}

