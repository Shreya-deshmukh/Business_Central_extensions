tableextension 98904 TableExtensionItemLedgerEntry extends "Item Ledger Entry"
{
    fields
    {
        field(98904; "Bin Code"; Code[20])
        {
            Caption = 'Bin Code';
            Editable = false;
            ToolTip = 'Shows the Bin Code from Warehouse Entry. Handles all entry types: Sales, Purchases, Positive/Negative Adjustments, Transfers, and Assemblies. Uses sequential ranking when multiple Warehouse Entries exist.';
        }
    }

    procedure GetBinCodeFromWarehouseEntry(): Code[20]
    var
        WarehouseEntry: Record "Warehouse Entry";
        SalesShipmentLine: Record "Sales Shipment Line";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        ReturnReceiptLine: Record "Return Receipt Line";
        ReturnShipmentLine: Record "Return Shipment Line";
        TransferShipmentHeader: Record "Transfer Shipment Header";
        TransferReceiptHeader: Record "Transfer Receipt Header";
        PostedAssemblyHeader: Record "Posted Assembly Header";
        Item: Record Item;
        SourceNo: Code[20];
        SourceLineNo: Integer;
        BinCode: Code[20];
    begin
        // ==========================================
        // BASE FILTERS: Item, Variant, Location, Quantity, Serial, Lot, UOM
        // Applied throughout all strategies to narrow down matches.
        // Quantity filter (with sign) naturally separates positive entries from negative ones.
        // ==========================================
        WarehouseEntry.Reset();
        WarehouseEntry.SetRange("Item No.", Rec."Item No.");
        WarehouseEntry.SetRange("Variant Code", Rec."Variant Code");
        WarehouseEntry.SetRange("Location Code", Rec."Location Code");
        WarehouseEntry.SetRange(Quantity, Rec.Quantity);

        if Rec."Serial No." <> '' then
            WarehouseEntry.SetRange("Serial No.", Rec."Serial No.");
        if Rec."Lot No." <> '' then
            WarehouseEntry.SetRange("Lot No.", Rec."Lot No.");
        if Rec."Unit of Measure Code" <> '' then
            WarehouseEntry.SetRange("Unit of Measure Code", Rec."Unit of Measure Code");

        // ==========================================
        // STRATEGY 1: Document-Specific Source Order Tracing
        // Warehouse Entries store the source ORDER number (e.g., Sales Order, Purchase Order),
        // not the POSTED document number (e.g., Sales Shipment, Purchase Receipt).
        // We trace back from the posted document to find the source order.
        // When multiple WEs match (e.g., partial receipts for same PO line),
        // we use sequential ranking instead of FindLast() to get the correct bin.
        // ==========================================

        SourceNo := '';
        SourceLineNo := 0;

        case Rec."Document Type" of
            // --- Sales Shipment -> Sales Order ---
            Rec."Document Type"::"Sales Shipment":
                if Rec."Document No." <> '' then begin
                    SalesShipmentLine.Reset();
                    SalesShipmentLine.SetRange("Document No.", Rec."Document No.");
                    SalesShipmentLine.SetRange("No.", Rec."Item No.");
                    if Rec."Document Line No." <> 0 then
                        SalesShipmentLine.SetRange("Line No.", Rec."Document Line No.");
                    if SalesShipmentLine.FindFirst() then begin
                        SourceNo := SalesShipmentLine."Order No.";
                        SourceLineNo := SalesShipmentLine."Order Line No.";
                    end;
                end;

            // --- Purchase Receipt -> Purchase Order ---
            Rec."Document Type"::"Purchase Receipt":
                if Rec."Document No." <> '' then begin
                    PurchRcptLine.Reset();
                    PurchRcptLine.SetRange("Document No.", Rec."Document No.");
                    PurchRcptLine.SetRange("No.", Rec."Item No.");
                    if Rec."Document Line No." <> 0 then
                        PurchRcptLine.SetRange("Line No.", Rec."Document Line No.");
                    if PurchRcptLine.FindFirst() then begin
                        SourceNo := PurchRcptLine."Order No.";
                        SourceLineNo := PurchRcptLine."Order Line No.";
                    end;
                end;

            // --- Sales Return Receipt -> Sales Return Order ---
            Rec."Document Type"::"Sales Return Receipt":
                if Rec."Document No." <> '' then begin
                    ReturnReceiptLine.Reset();
                    ReturnReceiptLine.SetRange("Document No.", Rec."Document No.");
                    ReturnReceiptLine.SetRange("No.", Rec."Item No.");
                    if Rec."Document Line No." <> 0 then
                        ReturnReceiptLine.SetRange("Line No.", Rec."Document Line No.");
                    if ReturnReceiptLine.FindFirst() then begin
                        SourceNo := ReturnReceiptLine."Return Order No.";
                        SourceLineNo := ReturnReceiptLine."Return Order Line No.";
                    end;
                end;

            // --- Purchase Return Shipment -> Purchase Return Order ---
            Rec."Document Type"::"Purchase Return Shipment":
                if Rec."Document No." <> '' then begin
                    ReturnShipmentLine.Reset();
                    ReturnShipmentLine.SetRange("Document No.", Rec."Document No.");
                    ReturnShipmentLine.SetRange("No.", Rec."Item No.");
                    if Rec."Document Line No." <> 0 then
                        ReturnShipmentLine.SetRange("Line No.", Rec."Document Line No.");
                    if ReturnShipmentLine.FindFirst() then begin
                        SourceNo := ReturnShipmentLine."Return Order No.";
                        SourceLineNo := ReturnShipmentLine."Return Order Line No.";
                    end;
                end;

            // --- Transfer Shipment -> Transfer Order ---
            Rec."Document Type"::"Transfer Shipment":
                if Rec."Document No." <> '' then
                    if TransferShipmentHeader.Get(Rec."Document No.") then begin
                        SourceNo := TransferShipmentHeader."Transfer Order No.";
                        SourceLineNo := Rec."Document Line No.";
                    end;

            // --- Transfer Receipt -> Transfer Order ---
            Rec."Document Type"::"Transfer Receipt":
                if Rec."Document No." <> '' then
                    if TransferReceiptHeader.Get(Rec."Document No.") then begin
                        SourceNo := TransferReceiptHeader."Transfer Order No.";
                        SourceLineNo := Rec."Document Line No.";
                    end;

            // --- Posted Assembly -> Assembly Order ---
            Rec."Document Type"::"Posted Assembly":
                if Rec."Document No." <> '' then
                    if PostedAssemblyHeader.Get(Rec."Document No.") then
                        SourceNo := PostedAssemblyHeader."Order No.";
        end;

        // Apply source order matching if found
        if SourceNo <> '' then begin
            WarehouseEntry.SetRange("Source No.", SourceNo);
            if SourceLineNo <> 0 then
                WarehouseEntry.SetRange("Source Line No.", SourceLineNo);
            if Rec."Posting Date" <> 0D then
                WarehouseEntry.SetFilter("Registering Date", '%1', Rec."Posting Date");

            // Use ranking instead of FindLast() to handle multiple WEs correctly
            BinCode := FindBinByRanking(WarehouseEntry);
            if BinCode <> '' then
                exit(BinCode);

            // Fallback: try without source line no
            if SourceLineNo <> 0 then begin
                WarehouseEntry.SetRange("Source Line No.");
                BinCode := FindBinByRanking(WarehouseEntry);
                if BinCode <> '' then
                    exit(BinCode);
            end;

            // Fallback: try without date
            WarehouseEntry.SetRange("Registering Date");
            if SourceLineNo <> 0 then
                WarehouseEntry.SetRange("Source Line No.", SourceLineNo);
            BinCode := FindBinByRanking(WarehouseEntry);
            if BinCode <> '' then
                exit(BinCode);

            // Fallback: without date and without line no
            if SourceLineNo <> 0 then begin
                WarehouseEntry.SetRange("Source Line No.");
                BinCode := FindBinByRanking(WarehouseEntry);
                if BinCode <> '' then
                    exit(BinCode);
            end;

            // Clear for next strategies
            WarehouseEntry.SetRange("Source No.");
            WarehouseEntry.SetRange("Source Line No.");
            WarehouseEntry.SetRange("Registering Date");
        end;

        // ==========================================
        // STRATEGY 2: Direct Document No. = Source No. Match
        // Works for Item Journals, direct Invoice/Credit Memo postings, and any entry
        // where WE Source No. equals ILE Document No.
        // ==========================================
        if Rec."Document No." <> '' then begin
            WarehouseEntry.SetRange("Source No.", Rec."Document No.");

            if Rec."Document Line No." <> 0 then begin
                WarehouseEntry.SetRange("Source Line No.", Rec."Document Line No.");
                if Rec."Posting Date" <> 0D then
                    WarehouseEntry.SetFilter("Registering Date", '%1', Rec."Posting Date");

                BinCode := FindBinByRanking(WarehouseEntry);
                if BinCode <> '' then
                    exit(BinCode);

                // Fallback: try without line no
                WarehouseEntry.SetRange("Source Line No.");
            end;

            if Rec."Posting Date" <> 0D then
                WarehouseEntry.SetFilter("Registering Date", '%1', Rec."Posting Date");

            BinCode := FindBinByRanking(WarehouseEntry);
            if BinCode <> '' then
                exit(BinCode);

            // Clear for next strategies
            WarehouseEntry.SetRange("Source No.");
            WarehouseEntry.SetRange("Source Line No.");
            WarehouseEntry.SetRange("Registering Date");
        end;

        // ==========================================
        // STRATEGY 3: Sequential Ranking WITHOUT Source No.
        // For Positive/Negative Adjustments and any entries where
        // WE Source No. is blank or different from ILE Document No.
        // Matches the N-th ILE to the N-th WE for the same
        // Item + Variant + Location + Quantity + Date.
        // The Quantity filter (with sign) naturally separates
        // positive entries (+30) from negative entries (-5).
        // ==========================================
        if Rec."Posting Date" <> 0D then begin
            WarehouseEntry.SetRange("Registering Date", Rec."Posting Date");

            BinCode := FindBinByRanking(WarehouseEntry);
            if BinCode <> '' then
                exit(BinCode);

            WarehouseEntry.SetRange("Registering Date");
        end;

        // ==========================================
        // STRATEGY 4: KIT/Assembly Items
        // For Assembly BOM items where a source order number was found,
        // try a final match using that source order number.
        // ==========================================
        if Item.Get(Rec."Item No.") then
            if Item."Assembly BOM" then
                if SourceNo <> '' then begin
                    WarehouseEntry.SetRange("Source No.", SourceNo);
                    if Rec."Posting Date" <> 0D then
                        WarehouseEntry.SetFilter("Registering Date", '%1', Rec."Posting Date");
                    BinCode := FindBinByRanking(WarehouseEntry);
                    if BinCode <> '' then
                        exit(BinCode);
                    WarehouseEntry.SetRange("Source No.");
                    WarehouseEntry.SetRange("Registering Date");
                end;

        // ==========================================
        // STRATEGY 5: Final Fallback
        // Match by base filters (Item/Variant/Location/Quantity) + Date only.
        // Returns the most recent Warehouse Entry.
        // ==========================================
        if Rec."Posting Date" <> 0D then
            WarehouseEntry.SetFilter("Registering Date", '%1', Rec."Posting Date");

        if WarehouseEntry.FindLast() then
            exit(WarehouseEntry."Bin Code");

        // Absolute fallback: base filters only (no date)
        WarehouseEntry.SetRange("Registering Date");
        if WarehouseEntry.FindLast() then
            exit(WarehouseEntry."Bin Code");

        exit('');
    end;

    local procedure FindBinByRanking(var WarehouseEntry: Record "Warehouse Entry"): Code[20]
    var
        ItemLedgerEntry2: Record "Item Ledger Entry";
        EntryRank: Integer;
        WECount: Integer;
    begin
        // This helper handles both single and multiple WE matches:
        // - 0 WEs: returns '' (no match, caller continues to next strategy)
        // - 1 WE: returns its bin code (exact match)
        // - Multiple WEs: uses sequential ranking based on Entry No. position
        //   to match the N-th ILE to the N-th WE. Returns '' if rank exceeds
        //   WE count (lets caller fall through to next strategy).

        WECount := WarehouseEntry.Count();

        if WECount = 0 then
            exit('');

        if WECount = 1 then begin
            if WarehouseEntry.FindFirst() then
                exit(WarehouseEntry."Bin Code");
            exit('');
        end;

        // Multiple WEs - determine rank based on ILE Entry No. position.
        // Count all ILEs with same Item/Variant/Location/Quantity/Date
        // and Entry No. <= current. This gives us the sequential position
        // of the current ILE, which corresponds to the WE at the same position.
        ItemLedgerEntry2.Reset();
        ItemLedgerEntry2.SetRange("Item No.", Rec."Item No.");
        ItemLedgerEntry2.SetRange("Variant Code", Rec."Variant Code");
        ItemLedgerEntry2.SetRange("Location Code", Rec."Location Code");
        ItemLedgerEntry2.SetRange(Quantity, Rec.Quantity);
        if Rec."Posting Date" <> 0D then
            ItemLedgerEntry2.SetRange("Posting Date", Rec."Posting Date");
        ItemLedgerEntry2.SetFilter("Entry No.", '<=%1', Rec."Entry No.");
        EntryRank := ItemLedgerEntry2.Count();

        if (EntryRank > 0) and (EntryRank <= WECount) then begin
            WarehouseEntry.SetCurrentKey("Entry No.");
            if WarehouseEntry.FindSet() then begin
                if EntryRank > 1 then
                    WarehouseEntry.Next(EntryRank - 1);
                exit(WarehouseEntry."Bin Code");
            end;
        end;

        // Rank exceeds WE count - return '' to let caller try next strategy
        exit('');
    end;
}
