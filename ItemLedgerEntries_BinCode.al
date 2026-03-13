pageextension 98904 PageExtensionItemLedgerEntries extends "Item Ledger Entries"
{
    layout
    {
        addafter("Location Code")
        {
            field("Bin Code"; Rec."Bin Code")
            {
                ApplicationArea = All;
                Editable = false;
                Visible = false;
                ToolTip = 'Specifies the bin code for the item ledger entry. This is retrieved from Warehouse Entry using the most recent entry when multiple exist.';
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        // Calculate Bin Code using custom logic when record is retrieved
        // This allows us to find the correct Warehouse Entry even when multiple exist
        Rec."Bin Code" := Rec.GetBinCodeFromWarehouseEntry();
    end;
}

