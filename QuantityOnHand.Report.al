report 98920 "Quantity on Hand"
{
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    Caption = 'Quantity on Hand & Usage';
    ProcessingOnly = true;
    AllowScheduling = true;

    dataset
    {
        dataitem(Item; Item)
        {
            RequestFilterFields = "No.", "Vendor No.", "Variant Filter";

            trigger OnPreDataItem()
            var
                CollectionLine: Record "Item Collection Line";
                VariantLine: Record "Item Collection Variant Line";
                ItemRef: Record Item;
                VariantFilterValue: Text;
            begin
                if ItemFilter <> '' then
                    Item.SetFilter("No.", ItemFilter);

                // Read Variant Filter from Item record filters if set
                VariantFilterValue := Item.GetFilter("Variant Filter");

                if SelectedCollection <> '' then begin
                    CollectionLine.SetCurrentKey("Collection Code", Sequence);
                    CollectionLine.SetRange("Collection Code", SelectedCollection);
                    if CollectionLine.FindSet() then begin
                        repeat
                            if ItemRef.Get(CollectionLine."Item No.") then begin
                                ItemRef.CopyFilters(Item);
                                ItemRef.SetRange("No.", CollectionLine."Item No.");

                                VariantLine.SetCurrentKey("Collection Code", "Item No.", "Sequence");
                                VariantLine.SetRange("Collection Code", SelectedCollection);
                                VariantLine.SetRange("Item No.", CollectionLine."Item No.");
                                if VariantLine.FindSet() then
                                    repeat
                                        ProcessItem(ItemRef, VariantLine."Variant Code");
                                    until VariantLine.Next() = 0
                                else
                                    ProcessItem(ItemRef, CollectionLine."Variant Code");
                            end;
                        until CollectionLine.Next() = 0;
                    end;

                    Item.SetRange("No.", '@@@@@@@@');
                end;
            end;

            trigger OnAfterGetRecord()
            var
                VariantFilterValue: Text;
            begin
                VariantFilterValue := Item.GetFilter("Variant Filter");
                if VariantFilterValue <> '' then
                    ProcessItem(Item, CopyStr(VariantFilterValue, 1, MaxStrLen(VariantFilterValue)))
                else
                    ProcessItem(Item, '');
            end;
        }
    }

    requestpage
    {
        layout
        {
            area(Content)
            {
                // ── Email delivery settings ─────────────────────────────────────────────
                // Fill this field before scheduling the report via Job Queue.
                // When non-empty the finished workbook is emailed rather than downloaded.
                group(EmailSettings)
                {
                    Caption = 'Email Settings';
                    field(EmailAddresses; EmailAddresses)
                    {
                        ApplicationArea = All;
                        Caption = 'Email Addresses';
                        // FIX 3: Increased from Text[500] to Text[2048] to support
                        // multiple long recipient addresses without truncation.
                        ToolTip = 'Enter one or more recipient e-mail addresses separated by semicolons (;). When this field is non-empty the report will be sent as an Excel attachment instead of being downloaded to the browser.';
                        ExtendedDatatype = EMail;
                    }
                }
                group(Options)
                {
                    Caption = 'Options';
                    field(SelectedCollection; SelectedCollection)
                    {
                        ApplicationArea = All;
                        Caption = 'Item Collection';
                        TableRelation = "Item Collection Header".Code;
                        ToolTip = 'Select an item collection to filter the report.';
                    }
                    field(ItemFilter; ItemFilter)
                    {
                        ApplicationArea = All;
                        Caption = 'Item Filter';
                        ToolTip = 'Filter by Item No. (Select multiple items)';

                        trigger OnLookup(var Text: Text): Boolean
                        var
                            ItemList: Page "Simple Item Lookup";
                            ItemRec: Record Item;
                            OldText: Text;
                        begin
                            OldText := Text;
                            ItemList.LookupMode(true);
                            if ItemList.RunModal() = Action::LookupOK then begin
                                ItemList.SetSelectionFilter(ItemRec);
                                if ItemRec.FindSet() then begin
                                    Text := OldText;
                                    repeat
                                        if (Text = '') or (StrPos('|' + Text + '|', '|' + ItemRec."No." + '|') = 0) then begin
                                            if Text <> '' then
                                                Text += '|';
                                            Text += ItemRec."No.";
                                        end;
                                    until ItemRec.Next() = 0;
                                    exit(true);
                                end;
                            end;
                            exit(false);
                        end;
                    }
                    field(VariantCodeFilter; VariantCodeFilter)
                    {
                        ApplicationArea = All;
                        Caption = 'Variant Code Filter';
                        ToolTip = 'Filter by Variant Code. The lookup shows variants for the item(s) in Item Filter (all variants if Item Filter is empty). Does not affect the Variant Filter under Filter totals by.';

                        trigger OnLookup(var Text: Text): Boolean
                        var
                            ItemVariantList: Page "Item Variant Lookup";
                            ItemVariantRec: Record "Item Variant";
                            OldText: Text;
                        begin
                            OldText := Text;
                            ItemVariantRec.Reset();
                            if ItemFilter <> '' then
                                ItemVariantRec.SetFilter("Item No.", ItemFilter);
                            ItemVariantList.SetTableView(ItemVariantRec);
                            ItemVariantList.LookupMode(true);
                            if ItemVariantList.RunModal() = Action::LookupOK then begin
                                ItemVariantList.SetSelectionFilter(ItemVariantRec);
                                if ItemVariantRec.FindSet() then begin
                                    Text := OldText;
                                    repeat
                                        if (Text = '') or (StrPos('|' + Text + '|', '|' + ItemVariantRec.Code + '|') = 0) then begin
                                            if Text <> '' then
                                                Text += '|';
                                            Text += ItemVariantRec.Code;
                                        end;
                                    until ItemVariantRec.Next() = 0;
                                    exit(true);
                                end;
                            end;
                            exit(false);
                        end;
                    }
                }
            }
        }
        actions
        {
            area(Processing)
            {
                action(CreateCollection)
                {
                    ApplicationArea = All;
                    Caption = 'Create Collection';
                    Image = Create;
                    ToolTip = 'Create a new collection of items.';

                    trigger OnAction()
                    var
                        ItemList: Page "Simple Item Lookup";
                        ItemRec: Record Item;
                        CollectionHeader: Record "Item Collection Header";
                        CollectionLine: Record "Item Collection Line";
                        NameInput: Page "Collection Name Input";
                        NewName: Code[20];
                        NextSeq: Integer;
                    begin
                        ItemList.LookupMode(true);
                        if ItemList.RunModal() = Action::LookupOK then begin
                            ItemList.SetSelectionFilter(ItemRec);
                            if ItemRec.FindSet() then begin
                                if NameInput.RunModal() = Action::OK then begin
                                    NewName := NameInput.GetCollectionName();
                                    if NewName = '' then
                                        Error('Collection Name cannot be empty.');

                                    if CollectionHeader.Get(NewName) then
                                        if not Confirm('Collection %1 already exists. Do you want to overwrite it?', false, NewName) then
                                            exit;

                                    if not CollectionHeader.Get(NewName) then begin
                                        CollectionHeader.Init();
                                        CollectionHeader.Code := NewName;
                                        CollectionHeader.Insert();
                                    end;

                                    CollectionLine.SetRange("Collection Code", NewName);
                                    CollectionLine.DeleteAll();

                                    NextSeq := 10000;

                                    repeat
                                        CollectionLine.Init();
                                        CollectionLine."Collection Code" := NewName;
                                        CollectionLine."Item No." := ItemRec."No.";
                                        CollectionLine.Sequence := NextSeq;
                                        if CollectionLine.Insert() then;
                                        NextSeq += 10000;
                                    until ItemRec.Next() = 0;

                                    Message('Collection %1 created successfully.', NewName);
                                    SelectedCollection := NewName;
                                end;
                            end;
                        end;
                    end;
                }
            }
        }
    }

    trigger OnPreReport()
    begin
        ExcelBuf.NewRow();
        ExcelBuf.AddColumn('Item No.', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Item Name', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Variant Code', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Vendor Name', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Vendor SKU', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Kit', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Quantity on Hand', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Quantity on Purchase Order', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Quantity on Sales Order', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Quantity on Assembly Order', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Quantity on Assembly Component', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Remaining Quantity', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Sales Last 3 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Assembly Consumption Last 3 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Usage Last 3 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Purchase Last 3 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Sales Last 6 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Assembly Consumption Last 6 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Usage Last 6 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Purchase Last 6 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Sales Last 12 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Assembly Consumption Last 12 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Usage Last 12 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Purchase Last 12 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Sales All Time', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Assembly Consumption All Time', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Usage All Time', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
        ExcelBuf.AddColumn('Purchase All Time', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
    end;

    trigger OnPostReport()
    var
        TempBlobExcel: Codeunit "Temp Blob";
        ExcelInStr: InStream;
    begin
        if EmailAddresses <> '' then begin
            // ── Email path (Job Queue or manual with recipients configured) ───────────
            // BuildXlsx uses ExcelBuf.CreateNewBook / WriteSheet / CloseBook to write
            // a genuine Open XML (.xlsx) workbook into a TempBlob stream — fully
            // server-side, no browser or DownloadFromStream required.
            BuildXlsx(TempBlobExcel);
            if not TempBlobExcel.HasValue() then
                Error('Failed to generate the report spreadsheet for email delivery.');
            TempBlobExcel.CreateInStream(ExcelInStr);
            SendReportByEmail(ExcelInStr);
        end else if GuiAllowed() then begin
            // ── Manual path (no email addresses set) ────────────────────────────────
            // Standard .xlsx download to the browser — unchanged from original behaviour.
            ExcelBuf.CreateNewBook('Quantity on Hand');
            ExcelBuf.WriteSheet('Quantity on Hand', CompanyName(), UserId());
            ExcelBuf.CloseBook();
            ExcelBuf.OpenExcel();
        end;
        // else: Job Queue run with no recipients configured — exit silently.
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
        QtyOnAsmComp: Decimal;
        RemainingQty: Decimal;
        SalesLast3M: Decimal;
        AsmConsLast3M: Decimal;
        UsageLast3M: Decimal;
        SalesLast6M: Decimal;
        AsmConsLast6M: Decimal;
        UsageLast6M: Decimal;
        SalesLast12M: Decimal;
        AsmConsLast12M: Decimal;
        UsageLast12M: Decimal;
        SalesAllTime: Decimal;
        AsmConsAllTime: Decimal;
        UsageAllTime: Decimal;
        PurchLast3M: Decimal;
        PurchLast6M: Decimal;
        PurchLast12M: Decimal;
        PurchAllTime: Decimal;
        IsKit: Boolean;
        Date3M: Date;
        Date6M: Date;
        Date12M: Date;
        SelectedCollection: Code[20];
        ItemFilter: Text;
        VariantCodeFilter: Text;
        // FIX 3: Increased from Text[500] → Text[2048] to support multiple long
        // recipient addresses without silent truncation.
        EmailAddresses: Text[2048];

    local procedure GetVendorInfo(ItemNo: Code[20]; VariantCode: Code[10]; var VName: Text[100]; var VSKU: Text[50])
    var
        ItemRec: Record Item;
        Vendor: Record Vendor;
        ItemVendor: Record "Item Vendor";
    begin
        if not ItemRec.Get(ItemNo) then
            exit;

        if ItemRec."Vendor No." <> '' then begin
            if Vendor.Get(ItemRec."Vendor No.") then
                VName := Vendor.Name;
            if ItemVendor.Get(ItemRec."Vendor No.", ItemNo, VariantCode) then
                VSKU := ItemVendor."Vendor Item No."
            else
                VSKU := ItemRec."Vendor Item No.";
            exit;
        end;

        ItemVendor.SetRange("Item No.", ItemNo);
        ItemVendor.SetRange("Variant Code", VariantCode);
        if ItemVendor.FindFirst() then begin
            if Vendor.Get(ItemVendor."Vendor No.") then
                VName := Vendor.Name;
            VSKU := ItemVendor."Vendor Item No.";
            exit;
        end;

        ItemVendor.SetRange("Variant Code");
        if ItemVendor.FindFirst() then begin
            if Vendor.Get(ItemVendor."Vendor No.") then
                VName := Vendor.Name;
            VSKU := ItemVendor."Vendor Item No.";
        end;
    end;

    local procedure GetPurchaseQty(ItemNo: Code[20]; VariantCode: Code[10]; LocationFilter: Text; StartDate: Date; EndDate: Date): Decimal
    var
        ILE: Record "Item Ledger Entry";
    begin
        ILE.SetCurrentKey("Item No.", "Entry Type", "Variant Code", "Drop Shipment", "Location Code", "Posting Date");
        ILE.SetRange("Item No.", ItemNo);
        ILE.SetRange("Variant Code", VariantCode);
        if LocationFilter <> '' then
            ILE.SetFilter("Location Code", LocationFilter);
        ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);
        if StartDate <> 0D then
            ILE.SetRange("Posting Date", StartDate, EndDate);
        ILE.CalcSums(Quantity);
        exit(ILE.Quantity);
    end;

    local procedure GetILEQty(ItemNo: Code[20]; VariantCode: Code[10]; LocationFilter: Text; EntryType: Enum "Item Ledger Entry Type"; StartDate: Date; EndDate: Date): Decimal
    var
        ILE: Record "Item Ledger Entry";
    begin
        ILE.SetCurrentKey("Item No.", "Entry Type", "Variant Code", "Drop Shipment", "Location Code", "Posting Date");
        ILE.SetRange("Item No.", ItemNo);
        ILE.SetRange("Variant Code", VariantCode);
        if LocationFilter <> '' then
            ILE.SetFilter("Location Code", LocationFilter);
        ILE.SetRange("Entry Type", EntryType);
        if StartDate <> 0D then
            ILE.SetRange("Posting Date", StartDate, EndDate);
        ILE.CalcSums(Quantity);
        exit(-ILE.Quantity);
    end;

    local procedure ProcessItem(var ItemInput: Record Item; VariantFilter: Code[10])
    var
        RealItemVariant: Record "Item Variant";
        ItemCheck: Record Item;
        ItemRec: Record Item;
        HasData: Boolean;
    begin
        TempItemVariant.Reset();
        TempItemVariant.DeleteAll();

        if VariantFilter <> '' then begin
            TempItemVariant.Init();
            TempItemVariant."Item No." := ItemInput."No.";
            TempItemVariant.Code := VariantFilter;
            TempItemVariant.Insert();
        end else begin
            RealItemVariant.SetRange("Item No.", ItemInput."No.");
            if RealItemVariant.FindSet() then
                repeat
                    if not TempItemVariant.Get(RealItemVariant."Item No.", RealItemVariant.Code) then begin
                        TempItemVariant := RealItemVariant;
                        TempItemVariant.Insert();
                    end;
                until RealItemVariant.Next() = 0;

            HasData := false;
            if ItemCheck.Get(ItemInput."No.") then begin
                ItemCheck.SetRange("Variant Filter", '');
                if ItemInput.GetFilter("Location Filter") <> '' then
                    ItemCheck.SetFilter("Location Filter", ItemInput.GetFilter("Location Filter"));
                ItemCheck.CalcFields(Inventory, "Qty. on Purch. Order", "Qty. on Sales Order", "Qty. on Assembly Order", "Qty. on Asm. Component");
                if (ItemCheck.Inventory <> 0) or
                    (ItemCheck."Qty. on Purch. Order" <> 0) or
                    (ItemCheck."Qty. on Sales Order" <> 0) or
                    (ItemCheck."Qty. on Assembly Order" <> 0) or
                    (ItemCheck."Qty. on Asm. Component" <> 0) then
                    HasData := true;
            end;

            if HasData or ((SelectedCollection <> '') and (TempItemVariant.IsEmpty())) then begin
                if not TempItemVariant.Get(ItemInput."No.", '') then begin
                    TempItemVariant.Init();
                    TempItemVariant."Item No." := ItemInput."No.";
                    TempItemVariant.Code := '';
                    TempItemVariant.Insert();
                end;
            end;
        end;

        if VariantCodeFilter <> '' then
            TempItemVariant.SetFilter(Code, VariantCodeFilter);

        if TempItemVariant.FindSet() then
            repeat
                Clear(VendorName);
                Clear(VendorSKU);
                IsKit := false;
                QtyOnHand := 0;
                QtyOnPOS := 0;
                QtyOnSO := 0;
                QtyOnAsm := 0;
                QtyOnAsmComp := 0;
                RemainingQty := 0;
                SalesLast3M := 0;
                AsmConsLast3M := 0;
                UsageLast3M := 0;
                PurchLast3M := 0;
                SalesLast6M := 0;
                AsmConsLast6M := 0;
                UsageLast6M := 0;
                PurchLast6M := 0;
                SalesLast12M := 0;
                AsmConsLast12M := 0;
                UsageLast12M := 0;
                PurchLast12M := 0;
                SalesAllTime := 0;
                AsmConsAllTime := 0;
                UsageAllTime := 0;
                PurchAllTime := 0;

                if ItemRec.Get(ItemInput."No.") then begin
                    ItemRec.SetRange("Variant Filter", TempItemVariant.Code);
                    if ItemInput.GetFilter("Location Filter") <> '' then
                        ItemRec.SetFilter("Location Filter", ItemInput.GetFilter("Location Filter"));

                    ItemRec.CalcFields(Inventory);
                    QtyOnHand := ItemRec.Inventory;

                    GetVendorInfo(ItemRec."No.", TempItemVariant.Code, VendorName, VendorSKU);

                    ItemRec.CalcFields("Assembly BOM");
                    IsKit := ItemRec."Assembly BOM";

                    ItemRec.CalcFields("Qty. on Purch. Order");
                    QtyOnPOS := ItemRec."Qty. on Purch. Order";

                    ItemRec.CalcFields("Qty. on Sales Order");
                    QtyOnSO := ItemRec."Qty. on Sales Order";

                    ItemRec.CalcFields("Qty. on Assembly Order");
                    QtyOnAsm := ItemRec."Qty. on Assembly Order";

                    ItemRec.CalcFields("Qty. on Asm. Component");
                    QtyOnAsmComp := ItemRec."Qty. on Asm. Component";

                    RemainingQty := QtyOnHand + QtyOnPOS - QtyOnSO + QtyOnAsm - QtyOnAsmComp;

                    Date3M := CalcDate('<-3M>', Today);
                    Date6M := CalcDate('<-6M>', Today);
                    Date12M := CalcDate('<-12M>', Today);

                    SalesLast3M := GetILEQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), "Item Ledger Entry Type"::Sale, Date3M, Today);
                    AsmConsLast3M := GetILEQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), "Item Ledger Entry Type"::"Assembly Consumption", Date3M, Today);
                    UsageLast3M := SalesLast3M + AsmConsLast3M;
                    PurchLast3M := GetPurchaseQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), Date3M, Today);

                    SalesLast6M := GetILEQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), "Item Ledger Entry Type"::Sale, Date6M, Today);
                    AsmConsLast6M := GetILEQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), "Item Ledger Entry Type"::"Assembly Consumption", Date6M, Today);
                    UsageLast6M := SalesLast6M + AsmConsLast6M;
                    PurchLast6M := GetPurchaseQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), Date6M, Today);

                    SalesLast12M := GetILEQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), "Item Ledger Entry Type"::Sale, Date12M, Today);
                    AsmConsLast12M := GetILEQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), "Item Ledger Entry Type"::"Assembly Consumption", Date12M, Today);
                    UsageLast12M := SalesLast12M + AsmConsLast12M;
                    PurchLast12M := GetPurchaseQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), Date12M, Today);

                    SalesAllTime := GetILEQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), "Item Ledger Entry Type"::Sale, 0D, 0D);
                    AsmConsAllTime := GetILEQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), "Item Ledger Entry Type"::"Assembly Consumption", 0D, 0D);
                    UsageAllTime := SalesAllTime + AsmConsAllTime;
                    PurchAllTime := GetPurchaseQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), 0D, 0D);
                end;

                if (TempItemVariant.Code = '') and
                   (QtyOnHand = 0) and
                   (QtyOnPOS = 0) and
                   (QtyOnSO = 0) and
                   (QtyOnAsm = 0) and
                   (QtyOnAsmComp = 0) and
                   (UsageAllTime = 0) and
                   not ((SelectedCollection <> '') and (TempItemVariant.Count = 1)) then begin
                    // Skip empty blank-variant rows
                end else begin
                    ExcelBuf.NewRow();
                    ExcelBuf.AddColumn(ItemInput."No.", false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
                    ExcelBuf.AddColumn(ItemInput.Description, false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
                    ExcelBuf.AddColumn(TempItemVariant.Code, false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
                    ExcelBuf.AddColumn(VendorName, false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
                    ExcelBuf.AddColumn(VendorSKU, false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
                    if IsKit then
                        ExcelBuf.AddColumn('Yes', false, '', false, false, false, '', ExcelBuf."Cell Type"::Text)
                    else
                        ExcelBuf.AddColumn('No', false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
                    ExcelBuf.AddColumn(QtyOnHand, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(QtyOnPOS, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(QtyOnSO, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(QtyOnAsm, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(QtyOnAsmComp, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(RemainingQty, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(SalesLast3M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(AsmConsLast3M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(UsageLast3M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(PurchLast3M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(SalesLast6M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(AsmConsLast6M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(UsageLast6M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(PurchLast6M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(SalesLast12M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(AsmConsLast12M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(UsageLast12M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(PurchLast12M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(SalesAllTime, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(AsmConsAllTime, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(UsageAllTime, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                    ExcelBuf.AddColumn(PurchAllTime, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
                end;

            until TempItemVariant.Next() = 0;
    end;

    // ────────────────────────────────────────────────────────────────────────────
    // EMAIL AUTOMATION
    // ────────────────────────────────────────────────────────────────────────────

    /// <summary>
    /// Builds and dispatches the email carrying the real .xlsx attachment.
    /// ExcelInStream must already be positioned at the start of the blob data
    /// (obtained from BuildXlsx + TempBlob.CreateInStream).
    /// </summary>
    local procedure SendReportByEmail(var ExcelInStream: InStream)
    var
        EmailMessage: Codeunit "Email Message";
        EmailModule: Codeunit Email;
        Recipients: List of [Text];
        Recipient: Text;
        Subject: Text;
        Body: Text;
        FileName: Text;
        CollectionName: Text;
        FormattedDate: Text;
    begin
        if SelectedCollection <> '' then
            CollectionName := SelectedCollection
        else
            CollectionName := 'All';
        FormattedDate := Format(Today, 0, '<Month Text,3> <Day>, <Year4>');

        Subject := 'Quantity on Hand & Usage Report - ' + CollectionName + ' - ' + FormattedDate;

        Body := '<p>Please find attached the Quantity on Hand &amp; Usage Report for ' +
                CollectionName + ' generated on ' + FormattedDate + '.</p>';

        // Real Open XML workbook — true .xlsx, opens in Excel with no warnings.
        FileName := 'QtyOnHandUsageReport_' +
                    Format(Today, 0, '<Year4><Month,2><Day,2>') + '.xlsx';

        // Initialise the message; recipients are added individually below.
        EmailMessage.Create('', Subject, Body, true);

        // ── Add each semicolon-separated address as an individual To recipient ──
        Recipients := SplitEmailAddresses(EmailAddresses);
        if Recipients.Count() = 0 then
            Error('No valid email addresses were found in the Email Addresses field.');

        foreach Recipient in Recipients do
            EmailMessage.AddRecipient(Enum::"Email Recipient Type"::"To", Recipient);

        // ── Attach the real .xlsx workbook ───────────────────────────────────────
        // MIME type for Open XML Excel format (.xlsx).
        EmailMessage.AddAttachment(FileName, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', ExcelInStream);

        // ── Send via the configured custom Email Scenario ────────────────────────
        // IMPORTANT: After deploying, map this scenario to your SMTP account in:
        //   Business Central → Email Accounts → Email Scenarios → QOH Report
        // The Send() call will throw a runtime error if the scenario has no
        // account mapped — the mapping is a one-time post-deploy setup step.
        EmailModule.Send(EmailMessage, Enum::"Email Scenario"::"QOH Report");
    end;

    /// <summary>
    /// Generates a genuine Open XML (.xlsx) workbook into ResultBlob using the
    /// ExcelBuf table's built-in CreateNewBook / WriteSheet / CloseBook / SaveToStream
    /// pipeline.  This is entirely server-side — no OpenExcel / DownloadFromStream
    /// is called — making it safe for Job Queue execution where GuiAllowed() = false.
    ///
    /// The output is a real .xlsx file (ZIP-based Open XML format), identical to
    /// what the manual download produces, with no format-mismatch warnings in Excel.
    /// </summary>
    local procedure BuildXlsx(var ResultBlob: Codeunit "Temp Blob")
    var
        OutStr: OutStream;
    begin
        // Build the workbook in memory using ExcelBuf's native Open XML engine.
        // CreateNewBook initialises the in-memory workbook structure.
        ExcelBuf.CreateNewBook('Quantity on Hand');

        // WriteSheet serialises all ExcelBuf rows/cells into the workbook sheet.
        // This is the same call the manual path uses before OpenExcel — it is
        // fully server-safe and does not trigger any client callback.
        ExcelBuf.WriteSheet('Quantity on Hand', CompanyName(), UserId());

        // CloseBook finalises the Open XML package (writes [Content_Types], rels, etc.).
        ExcelBuf.CloseBook();

        // SaveToStream writes the completed .xlsx binary into our TempBlob OutStream.
        // This replaces OpenExcel (which would DownloadFromStream to the browser).
        ResultBlob.CreateOutStream(OutStr);
        ExcelBuf.SaveToStream(OutStr, true);
    end;

    /// <summary>
    /// Splits a semicolon-delimited string of email addresses into a typed list.
    /// Trims whitespace from each token and skips empty entries.
    /// Example:  'a@x.com; b@y.com ; c@z.com'  →  ['a@x.com','b@y.com','c@z.com']
    /// </summary>
    local procedure SplitEmailAddresses(RawAddresses: Text): List of [Text]
    var
        AddressList: List of [Text];
        Parts: List of [Text];
        Part: Text;
        Trimmed: Text;
    begin
        Parts := RawAddresses.Split(';');
        foreach Part in Parts do begin
            Trimmed := Part.Trim();
            if Trimmed <> '' then
                AddressList.Add(Trimmed);
        end;
        exit(AddressList);
    end;
}
