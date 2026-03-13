report 98921 "QoH"
{
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    ProcessingOnly = true;
    Caption = 'QOH';

    dataset
    {
        dataitem(Item; Item)
        {
            RequestFilterFields = "No.", "Vendor No.", "Location Filter";

            dataitem(VariantLoop; Integer)
            {
                DataItemTableView = sorting(Number);

                trigger OnPreDataItem()
                var
                    RealItemVariant: Record "Item Variant";
                begin
                    TempItemVariant.Reset();
                    TempItemVariant.DeleteAll();

                    RealItemVariant.SetRange("Item No.", Item."No.");
                    if VariantCodeFilter <> '' then
                        RealItemVariant.SetFilter(Code, VariantCodeFilter);

                    if RealItemVariant.FindSet() then
                        repeat
                            TempItemVariant := RealItemVariant;
                            TempItemVariant.Insert();
                        until RealItemVariant.Next() = 0;

                    // If no variants exist (or none match the filter), and the item doesn't use variants generally,
                    // or we just want to show the item itself:
                    if TempItemVariant.IsEmpty() then begin
                        TempItemVariant.Init();
                        TempItemVariant."Item No." := Item."No.";
                        TempItemVariant.Code := '';
                        TempItemVariant.Insert();
                    end;

                    SetRange(Number, 1, TempItemVariant.Count);
                end;

                trigger OnAfterGetRecord()
                var
                    ItemRec: Record Item;
                begin
                    if Number = 1 then
                        TempItemVariant.FindFirst()
                    else
                        TempItemVariant.Next();

                    // Initialize variables
                    Clear(VendorName);
                    Clear(VendorSKU);
                    QtyOnHand := 0;
                    QtyOnPOS := 0;
                    QtyOnSO := 0;
                    QtyOnAsm := 0;
                    SalesLast3M := 0;
                    UsageLast6M := 0;
                    UsageLast12M := 0;

                    // Calculate Quantities using Item FlowFields with Variant Filter
                    if ItemRec.Get(Item."No.") then begin
                        ItemRec.SetRange("Variant Filter", TempItemVariant.Code);

                        // Propagate Location Filter from Item DataItem
                        if Item.GetFilter("Location Filter") <> '' then
                            ItemRec.SetFilter("Location Filter", Item.GetFilter("Location Filter"));

                        ItemRec.CalcFields(Inventory, "Qty. on Purch. Order", "Qty. on Sales Order", "Qty. on Assembly Order");

                        QtyOnHand := ItemRec.Inventory;
                        QtyOnPOS := ItemRec."Qty. on Purch. Order";
                        QtyOnSO := ItemRec."Qty. on Sales Order";
                        QtyOnAsm := ItemRec."Qty. on Assembly Order";

                        // Calculate Sales History
                        SalesLast3M := CalculateSales(ItemRec."No.", TempItemVariant.Code, CalcDate('<-3M>', Today), Today);
                        UsageLast6M := CalculateSales(ItemRec."No.", TempItemVariant.Code, CalcDate('<-6M>', Today), Today);
                        UsageLast12M := CalculateSales(ItemRec."No.", TempItemVariant.Code, CalcDate('<-12M>', Today), Today);

                        // Get Vendor Info
                        GetVendorInfo(ItemRec."No.", TempItemVariant.Code, VendorName, VendorSKU);
                    end;

                    // Excel Buffer Output
                    ExcelBuf.NewRow();
                    ExcelBuf.AddColumn(Item."No.", false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
                    ExcelBuf.AddColumn(Item.Description, false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
                    ExcelBuf.AddColumn(TempItemVariant.Code, false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
                    ExcelBuf.AddColumn(VendorName, false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
                    ExcelBuf.AddColumn(VendorSKU, false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
                    ExcelBuf.AddColumn(QtyOnHand, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(QtyOnPOS, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(QtyOnSO, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(QtyOnAsm, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(SalesLast3M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(UsageLast6M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(UsageLast12M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                end;
            }
        }
    }

    requestpage
    {
        layout
        {
            area(Content)
            {
                group(Options)
                {
                    Caption = 'Options';
                    field(VariantCodeFilter; VariantCodeFilter)
                    {
                        ApplicationArea = All;
                        Caption = 'Variant Code Filter';
                        ToolTip = 'Filter by Variant Code.';
                        TableRelation = "Item Variant".Code;
                    }
                }
            }
        }
    }

    trigger OnPreReport()
    begin
        ExcelBuf.NewRow();
        ExcelBuf.AddColumn('Item No.', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Item Name', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Variant Code', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text); // Updated Title
        ExcelBuf.AddColumn('Vendor Name', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Vendor SKU', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Quantity On Hand', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Qty On POS', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Qty On SO', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Qty On Asm', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Sales Last 3M', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Usage Last 6M', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Usage Last 12M', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
    end;

    trigger OnPostReport()
    begin
        ExcelBuf.CreateNewBook('Quantity on Hand');
        ExcelBuf.WriteSheet('Quantity on Hand', CompanyName(), UserId());
        ExcelBuf.CloseBook();
        ExcelBuf.OpenExcel();
    end;

    var
        TempItemVariant: Record "Item Variant" temporary;
        ExcelBuf: Record "Excel Buffer" temporary;
        VendorName: Text[100];
        VendorSKU: Text[50];
        QtyOnHand: Decimal;
        QtyOnPOS: Decimal;
        QtyOnSO: Decimal;
        QtyOnAsm: Decimal;
        SalesLast3M: Decimal;
        UsageLast6M: Decimal;
        UsageLast12M: Decimal;
        VariantCodeFilter: Text;

    local procedure CalculateSales(ItemNo: Code[20]; VariantCode: Code[10]; StartDate: Date; EndDate: Date): Decimal
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        ItemLedgerEntry.SetRange("Variant Code", VariantCode);
        ItemLedgerEntry.SetRange("Entry Type", ItemLedgerEntry."Entry Type"::Sale);
        ItemLedgerEntry.SetRange("Posting Date", StartDate, EndDate);

        // Apply Location Filter if present on the Item DataItem
        if Item.GetFilter("Location Filter") <> '' then
            ItemLedgerEntry.SetFilter("Location Code", Item.GetFilter("Location Filter"));

        ItemLedgerEntry.CalcSums(Quantity);
        // Sales Quantity in ILE is negative, so we return the absolute value
        exit(Abs(ItemLedgerEntry.Quantity));
    end;

    local procedure GetVendorInfo(ItemNo: Code[20]; VariantCode: Code[10]; var VName: Text[100]; var VSKU: Text[50])
    var
        ItemRec: Record Item;
        Vendor: Record Vendor;
        ItemVendor: Record "Item Vendor";
    begin
        if not ItemRec.Get(ItemNo) then
            exit;

        // Priority 1: Item Preferred Vendor
        if ItemRec."Vendor No." <> '' then begin
            if Vendor.Get(ItemRec."Vendor No.") then
                VName := Vendor.Name;

            // Check if there is a specific Vendor Item No. for this variant
            if ItemVendor.Get(ItemRec."Vendor No.", ItemNo, VariantCode) then
                VSKU := ItemVendor."Vendor Item No."
            else
                VSKU := ItemRec."Vendor Item No.";

            exit;
        end;

        // Priority 2: First available Item Vendor for this specific Variant
        ItemVendor.SetRange("Item No.", ItemNo);
        ItemVendor.SetRange("Variant Code", VariantCode);
        if ItemVendor.FindFirst() then begin
            if Vendor.Get(ItemVendor."Vendor No.") then
                VName := Vendor.Name;
            VSKU := ItemVendor."Vendor Item No.";
            exit;
        end;

        // Priority 3: First available Item Vendor (any variant)
        ItemVendor.SetRange("Variant Code");
        if ItemVendor.FindFirst() then begin
            if Vendor.Get(ItemVendor."Vendor No.") then
                VName := Vendor.Name;
            VSKU := ItemVendor."Vendor Item No.";
        end;
    end;
}
