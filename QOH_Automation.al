// report 98923 "Quantity on Hand Automation"
// {
//     UsageCategory = ReportsAndAnalysis;
//     ApplicationArea = All;
//     ProcessingOnly = true;
//     Caption = 'Quantity on Hand & Usage';

//     dataset
//     {
//         dataitem(Item; Item)
//         {
//             RequestFilterFields = "No.", "Vendor No.", "Variant Filter";

//             trigger OnPreDataItem()
//             var
//                 CollectionLine: Record "Item Collection Line";
//                 VariantLine: Record "Item Collection Variant Line";
//                 ItemRef: Record Item;
//                 VariantFilterValue: Text;
//             begin
//                 if ItemFilter <> '' then
//                     Item.SetFilter("No.", ItemFilter);

//                 // Read Variant Filter from Item record filters if set
//                 VariantFilterValue := Item.GetFilter("Variant Filter");

//                 if SelectedCollection <> '' then begin
//                     CollectionLine.SetCurrentKey("Collection Code", Sequence);
//                     CollectionLine.SetRange("Collection Code", SelectedCollection);
//                     if CollectionLine.FindSet() then begin
//                         repeat
//                             if ItemRef.Get(CollectionLine."Item No.") then begin
//                                 ItemRef.CopyFilters(Item);
//                                 ItemRef.SetRange("No.", CollectionLine."Item No.");

//                                 VariantLine.SetCurrentKey("Collection Code", "Item No.", "Sequence");
//                                 VariantLine.SetRange("Collection Code", SelectedCollection);
//                                 VariantLine.SetRange("Item No.", CollectionLine."Item No.");
//                                 if VariantLine.FindSet() then
//                                     repeat
//                                         ProcessItem(ItemRef, VariantLine."Variant Code");
//                                     until VariantLine.Next() = 0
//                                 else
//                                     ProcessItem(ItemRef, CollectionLine."Variant Code");
//                             end;
//                         until CollectionLine.Next() = 0;
//                     end;

//                     Item.SetRange("No.", '@@@@@@@@');
//                 end;
//             end;

//             trigger OnAfterGetRecord()
//             var
//                 VariantFilterValue: Text;
//             begin
//                 // This trigger only runs if SelectedCollection is empty (standard report behavior)
//                 // or if we didn't set the dummy filter (which we do if SelectedCollection is set).
//                 VariantFilterValue := Item.GetFilter("Variant Filter");
//                 if VariantFilterValue <> '' then
//                     ProcessItem(Item, CopyStr(VariantFilterValue, 1, MaxStrLen(VariantFilterValue)))
//                 else
//                     ProcessItem(Item, '');
//             end;
//         }
//     }

//     requestpage
//     {
//         layout
//         {
//             area(Content)
//             {
//                 group(Options)
//                 {
//                     Caption = 'Options';
//                     field(SelectedCollection; SelectedCollection)
//                     {
//                         ApplicationArea = All;
//                         Caption = 'Item Collection';
//                         TableRelation = "Item Collection Header".Code;
//                         ToolTip = 'Select an item collection to filter the report.';
//                     }
//                     field(ItemFilter; ItemFilter)
//                     {
//                         ApplicationArea = All;
//                         Caption = 'Item Filter';
//                         ToolTip = 'Filter by Item No. (Select multiple items)';

//                         trigger OnLookup(var Text: Text): Boolean
//                         var
//                             ItemList: Page "Simple Item Lookup";
//                             ItemRec: Record Item;
//                             OldText: Text;
//                         begin
//                             OldText := Text;
//                             ItemList.LookupMode(true);
//                             if ItemList.RunModal() = Action::LookupOK then begin
//                                 ItemList.SetSelectionFilter(ItemRec);
//                                 if ItemRec.FindSet() then begin
//                                     Text := OldText;
//                                     repeat
//                                         if (Text = '') or (StrPos('|' + Text + '|', '|' + ItemRec."No." + '|') = 0) then begin
//                                             if Text <> '' then
//                                                 Text += '|';
//                                             Text += ItemRec."No.";
//                                         end;
//                                     until ItemRec.Next() = 0;
//                                     exit(true);
//                                 end;
//                             end;
//                             exit(false);
//                         end;
//                     }
//                     field(VariantCodeFilter; VariantCodeFilter)
//                     {
//                         ApplicationArea = All;
//                         Caption = 'Variant Code Filter';
//                         ToolTip = 'Filter by Variant Code. The lookup shows variants for the item(s) in Item Filter (all variants if Item Filter is empty). Does not affect the Variant Filter under Filter totals by.';

//                         trigger OnLookup(var Text: Text): Boolean
//                         var
//                             ItemVariantList: Page "Item Variant Lookup";
//                             ItemVariantRec: Record "Item Variant";
//                             OldText: Text;
//                         begin
//                             OldText := Text;
//                             ItemVariantRec.Reset();
//                             if ItemFilter <> '' then
//                                 ItemVariantRec.SetFilter("Item No.", ItemFilter);
//                             ItemVariantList.SetTableView(ItemVariantRec);
//                             ItemVariantList.LookupMode(true);
//                             if ItemVariantList.RunModal() = Action::LookupOK then begin
//                                 ItemVariantList.SetSelectionFilter(ItemVariantRec);
//                                 if ItemVariantRec.FindSet() then begin
//                                     Text := OldText;
//                                     repeat
//                                         if (Text = '') or (StrPos('|' + Text + '|', '|' + ItemVariantRec.Code + '|') = 0) then begin
//                                             if Text <> '' then
//                                                 Text += '|';
//                                             Text += ItemVariantRec.Code;
//                                         end;
//                                     until ItemVariantRec.Next() = 0;
//                                     exit(true);
//                                 end;
//                             end;
//                             exit(false);
//                         end;
//                     }
//                 }
//             }
//         }
//         actions
//         {
//             area(Processing)
//             {
//                 action(CreateCollection)
//                 {
//                     ApplicationArea = All;
//                     Caption = 'Create Collection';
//                     Image = Create;
//                     ToolTip = 'Create a new collection of items.';

//                     trigger OnAction()
//                     var
//                         ItemList: Page "Simple Item Lookup";
//                         ItemRec: Record Item;
//                         CollectionHeader: Record "Item Collection Header";
//                         CollectionLine: Record "Item Collection Line";
//                         NameInput: Page "Collection Name Input";
//                         NewName: Code[20];
//                         NextSeq: Integer;
//                     begin
//                         // 1. Select Items
//                         ItemList.LookupMode(true);
//                         if ItemList.RunModal() = Action::LookupOK then begin
//                             ItemList.SetSelectionFilter(ItemRec);
//                             if ItemRec.FindSet() then begin
//                                 // 2. Get Name
//                                 if NameInput.RunModal() = Action::OK then begin
//                                     NewName := NameInput.GetCollectionName();
//                                     if NewName = '' then
//                                         Error('Collection Name cannot be empty.');

//                                     if CollectionHeader.Get(NewName) then
//                                         if not Confirm('Collection %1 already exists. Do you want to overwrite it?', false, NewName) then
//                                             exit;

//                                     // 3. Create/Update Collection
//                                     if not CollectionHeader.Get(NewName) then begin
//                                         CollectionHeader.Init();
//                                         CollectionHeader.Code := NewName;
//                                         CollectionHeader.Insert();
//                                     end;

//                                     // Clear existing lines if overwriting
//                                     CollectionLine.SetRange("Collection Code", NewName);
//                                     CollectionLine.DeleteAll();

//                                     NextSeq := 10000;

//                                     repeat
//                                         CollectionLine.Init();
//                                         CollectionLine."Collection Code" := NewName;
//                                         CollectionLine."Item No." := ItemRec."No.";
//                                         CollectionLine.Sequence := NextSeq;
//                                         if CollectionLine.Insert() then;
//                                         NextSeq += 10000;
//                                     until ItemRec.Next() = 0;

//                                     Message('Collection %1 created successfully.', NewName);
//                                     SelectedCollection := NewName;
//                                 end;
//                             end;
//                         end;
//                     end;
//                 }
//             }
//         }
//     }

//     trigger OnPreReport()
//     begin
//         ExcelBuf.NewRow();
//         ExcelBuf.AddColumn('Item No.', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Item Name', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Variant Code', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Vendor Name', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Vendor SKU', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Kit', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Quantity on Hand', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);

//         ExcelBuf.AddColumn('Quantity on Purchase Order', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Quantity on Sales Order', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Quantity on Assembly Order', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Quantity on Assembly Component', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Remaining Quantity', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);

//         ExcelBuf.AddColumn('Sales Last 3 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Assembly Consumption Last 3 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Usage Last 3 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Purchase Last 3 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);

//         ExcelBuf.AddColumn('Sales Last 6 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Assembly Consumption Last 6 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Usage Last 6 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Purchase Last 6 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);

//         ExcelBuf.AddColumn('Sales Last 12 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Assembly Consumption Last 12 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Usage Last 12 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Purchase Last 12 Months', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);

//         ExcelBuf.AddColumn('Sales All Time', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Assembly Consumption All Time', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Usage All Time', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//         ExcelBuf.AddColumn('Purchase All Time', false, '', true, false, true, '', ExcelBuf."Cell Type"::Text);
//     end;

//     trigger OnPostReport()
//     begin
//         ExcelBuf.CreateNewBook('Quantity on Hand');
//         ExcelBuf.WriteSheet('Quantity on Hand', CompanyName(), UserId());
//         ExcelBuf.CloseBook();
//         ExcelBuf.OpenExcel();
//     end;

//     var
//         TempItemVariant: Record "Item Variant" temporary;
//         ExcelBuf: Record "Excel Buffer" temporary;
//         VendorName: Text[100];
//         VendorSKU: Text[50];
//         QtyOnHand: Decimal;
//         QtyOnPOS: Decimal;
//         QtyOnSO: Decimal;
//         QtyOnAsm: Decimal;
//         QtyOnAsmComp: Decimal;
//         RemainingQty: Decimal;
//         SalesLast3M: Decimal;
//         AsmConsLast3M: Decimal;
//         UsageLast3M: Decimal;
//         SalesLast6M: Decimal;
//         AsmConsLast6M: Decimal;
//         UsageLast6M: Decimal;
//         SalesLast12M: Decimal;
//         AsmConsLast12M: Decimal;
//         UsageLast12M: Decimal;
//         SalesAllTime: Decimal;
//         AsmConsAllTime: Decimal;
//         UsageAllTime: Decimal;
//         PurchLast3M: Decimal;
//         PurchLast6M: Decimal;
//         PurchLast12M: Decimal;
//         PurchAllTime: Decimal;
//         IsKit: Boolean;

//         Date3M: Date;
//         Date6M: Date;
//         Date12M: Date;

//         SelectedCollection: Code[20];
//         ItemFilter: Text;
//         VariantCodeFilter: Text;

//     local procedure GetVendorInfo(ItemNo: Code[20]; VariantCode: Code[10]; var VName: Text[100]; var VSKU: Text[50])
//     var
//         ItemRec: Record Item;
//         Vendor: Record Vendor;
//         ItemVendor: Record "Item Vendor";
//     begin
//         if not ItemRec.Get(ItemNo) then
//             exit;

//         // Priority 1: Item Preferred Vendor
//         if ItemRec."Vendor No." <> '' then begin
//             if Vendor.Get(ItemRec."Vendor No.") then
//                 VName := Vendor.Name;

//             if ItemVendor.Get(ItemRec."Vendor No.", ItemNo, VariantCode) then
//                 VSKU := ItemVendor."Vendor Item No."
//             else
//                 VSKU := ItemRec."Vendor Item No.";

//             exit;
//         end;

//         // Priority 2: First available Item Vendor for this specific Variant
//         ItemVendor.SetRange("Item No.", ItemNo);
//         ItemVendor.SetRange("Variant Code", VariantCode);
//         if ItemVendor.FindFirst() then begin
//             if Vendor.Get(ItemVendor."Vendor No.") then
//                 VName := Vendor.Name;
//             VSKU := ItemVendor."Vendor Item No.";
//             exit;
//         end;

//         // Priority 3: First available Item Vendor (any variant)
//         ItemVendor.SetRange("Variant Code");
//         if ItemVendor.FindFirst() then begin
//             if Vendor.Get(ItemVendor."Vendor No.") then
//                 VName := Vendor.Name;
//             VSKU := ItemVendor."Vendor Item No.";
//         end;
//     end;

//     local procedure GetPurchaseQty(ItemNo: Code[20]; VariantCode: Code[10]; LocationFilter: Text; StartDate: Date; EndDate: Date): Decimal
//     var
//         ILE: Record "Item Ledger Entry";
//     begin
//         ILE.SetCurrentKey("Item No.", "Entry Type", "Variant Code", "Drop Shipment", "Location Code", "Posting Date");
//         ILE.SetRange("Item No.", ItemNo);
//         ILE.SetRange("Variant Code", VariantCode);
//         if LocationFilter <> '' then
//             ILE.SetFilter("Location Code", LocationFilter);

//         ILE.SetRange("Entry Type", ILE."Entry Type"::Purchase);

//         if StartDate <> 0D then
//             ILE.SetRange("Posting Date", StartDate, EndDate);

//         ILE.CalcSums(Quantity);

//         exit(ILE.Quantity);
//     end;

//     local procedure GetILEQty(ItemNo: Code[20]; VariantCode: Code[10]; LocationFilter: Text; EntryType: Enum "Item Ledger Entry Type"; StartDate: Date; EndDate: Date): Decimal
//     var
//         ILE: Record "Item Ledger Entry";
//     begin
//         ILE.SetCurrentKey("Item No.", "Entry Type", "Variant Code", "Drop Shipment", "Location Code", "Posting Date");
//         ILE.SetRange("Item No.", ItemNo);
//         ILE.SetRange("Variant Code", VariantCode);
//         if LocationFilter <> '' then
//             ILE.SetFilter("Location Code", LocationFilter);

//         ILE.SetRange("Entry Type", EntryType);

//         if StartDate <> 0D then
//             ILE.SetRange("Posting Date", StartDate, EndDate);

//         ILE.CalcSums(Quantity);

//         // ILE Quantities for Sales/Consumption are negative. Return positive value for report.
//         exit(-ILE.Quantity);
//     end;

//     local procedure ProcessItem(var ItemInput: Record Item; VariantFilter: Code[10])
//     var
//         RealItemVariant: Record "Item Variant";
//         ItemCheck: Record Item;
//         ItemRec: Record Item;
//         HasData: Boolean;
//     begin
//         TempItemVariant.Reset();
//         TempItemVariant.DeleteAll();

//         if VariantFilter <> '' then begin
//             TempItemVariant.Init();
//             TempItemVariant."Item No." := ItemInput."No.";
//             TempItemVariant.Code := VariantFilter;
//             TempItemVariant.Insert();
//         end else begin
//             // 1. Insert all defined variants
//             RealItemVariant.SetRange("Item No.", ItemInput."No.");
//             if RealItemVariant.FindSet() then
//                 repeat
//                     if not TempItemVariant.Get(RealItemVariant."Item No.", RealItemVariant.Code) then begin
//                         TempItemVariant := RealItemVariant;
//                         TempItemVariant.Insert();
//                     end;
//                 until RealItemVariant.Next() = 0;

//             // 2. Conditionally insert "Blank" variant
//             HasData := false;
//             if ItemCheck.Get(ItemInput."No.") then begin
//                 ItemCheck.SetRange("Variant Filter", '');
//                 if ItemInput.GetFilter("Location Filter") <> '' then
//                     ItemCheck.SetFilter("Location Filter", ItemInput.GetFilter("Location Filter"));

//                 ItemCheck.CalcFields(Inventory, "Qty. on Purch. Order", "Qty. on Sales Order", "Qty. on Assembly Order", "Qty. on Asm. Component");

//                 if (ItemCheck.Inventory <> 0) or
//                     (ItemCheck."Qty. on Purch. Order" <> 0) or
//                     (ItemCheck."Qty. on Sales Order" <> 0) or
//                     (ItemCheck."Qty. on Assembly Order" <> 0) or
//                     (ItemCheck."Qty. on Asm. Component" <> 0) then
//                     HasData := true;
//             end;

//             // If filtering by collection, ensure items with no variants/data are still included
//             if HasData or ((SelectedCollection <> '') and (TempItemVariant.IsEmpty())) then begin
//                 if not TempItemVariant.Get(ItemInput."No.", '') then begin
//                     TempItemVariant.Init();
//                     TempItemVariant."Item No." := ItemInput."No.";
//                     TempItemVariant.Code := '';
//                     TempItemVariant.Insert();
//                 end;
//             end;
//         end;

//         // Apply Options Variant Code Filter (does not affect request "Variant Filter" under Filter totals by)
//         if VariantCodeFilter <> '' then
//             TempItemVariant.SetFilter(Code, VariantCodeFilter);

//         if TempItemVariant.FindSet() then
//             repeat
//                 // Initialize variables
//                 Clear(VendorName);
//                 Clear(VendorSKU);
//                 IsKit := false;
//                 QtyOnHand := 0;
//                 QtyOnPOS := 0;
//                 QtyOnSO := 0;
//                 QtyOnAsm := 0;
//                 QtyOnAsmComp := 0;
//                 RemainingQty := 0;

//                 SalesLast3M := 0;
//                 AsmConsLast3M := 0;
//                 UsageLast3M := 0;
//                 PurchLast3M := 0;

//                 SalesLast6M := 0;
//                 AsmConsLast6M := 0;
//                 UsageLast6M := 0;
//                 PurchLast6M := 0;

//                 SalesLast12M := 0;
//                 AsmConsLast12M := 0;
//                 UsageLast12M := 0;
//                 PurchLast12M := 0;

//                 SalesAllTime := 0;
//                 AsmConsAllTime := 0;
//                 UsageAllTime := 0;
//                 PurchAllTime := 0;

//                 if ItemRec.Get(ItemInput."No.") then begin
//                     // Set standard filters on the Item record
//                     ItemRec.SetRange("Variant Filter", TempItemVariant.Code);
//                     if ItemInput.GetFilter("Location Filter") <> '' then
//                         ItemRec.SetFilter("Location Filter", ItemInput.GetFilter("Location Filter"));

//                     // 1. Quantity on Hand
//                     ItemRec.CalcFields(Inventory);
//                     QtyOnHand := ItemRec.Inventory;

//                     // Get Vendor Info
//                     GetVendorInfo(ItemRec."No.", TempItemVariant.Code, VendorName, VendorSKU);

//                     // Check if item is a Kit (Assembly BOM)
//                     ItemRec.CalcFields("Assembly BOM");
//                     IsKit := ItemRec."Assembly BOM";

//                     // 2. Quantity on POS 
//                     ItemRec.CalcFields("Qty. on Purch. Order");
//                     QtyOnPOS := ItemRec."Qty. on Purch. Order";

//                     // 3. Quantity on SO (Document Type = Order)
//                     ItemRec.CalcFields("Qty. on Sales Order");
//                     QtyOnSO := ItemRec."Qty. on Sales Order";

//                     // 4. Quantity on Assembly Order
//                     // If the item is a kit (has Assembly BOM), don't show assembly order qty on the kit row.
//                     // Instead, show it on the parent/component item via "Qty. on Asm. Component".
//                     // ItemRec.CalcFields("Assembly BOM");
//                     // if ItemRec."Assembly BOM" then
//                     //     QtyOnAsm := 0
//                     // else begin
//                     //     ItemRec.CalcFields("Qty. on Asm. Component");
//                     //     QtyOnAsm := ItemRec."Qty. on Asm. Component";
//                     // end;


//                     // 4. Quantity on Assembly Order
//                     ItemRec.CalcFields("Qty. on Assembly Order");
//                     QtyOnAsm := ItemRec."Qty. on Assembly Order";

//                     // 5. Quantity on Assembly Component
//                     ItemRec.CalcFields("Qty. on Asm. Component");
//                     QtyOnAsmComp := ItemRec."Qty. on Asm. Component";

//                     RemainingQty := QtyOnHand + QtyOnPOS - QtyOnSO + QtyOnAsm - QtyOnAsmComp;

//                     // Calculate Date Ranges
//                     Date3M := CalcDate('<-3M>', Today);
//                     Date6M := CalcDate('<-6M>', Today);
//                     Date12M := CalcDate('<-12M>', Today);

//                     // 5-6. Last 3 Months
//                     SalesLast3M := GetILEQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), "Item Ledger Entry Type"::Sale, Date3M, Today);
//                     AsmConsLast3M := GetILEQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), "Item Ledger Entry Type"::"Assembly Consumption", Date3M, Today);
//                     UsageLast3M := SalesLast3M + AsmConsLast3M;
//                     PurchLast3M := GetPurchaseQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), Date3M, Today);

//                     // 7-9. Last 6 Months
//                     SalesLast6M := GetILEQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), "Item Ledger Entry Type"::Sale, Date6M, Today);
//                     AsmConsLast6M := GetILEQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), "Item Ledger Entry Type"::"Assembly Consumption", Date6M, Today);
//                     UsageLast6M := SalesLast6M + AsmConsLast6M;
//                     PurchLast6M := GetPurchaseQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), Date6M, Today);

//                     // 10-12. Last 12 Months
//                     SalesLast12M := GetILEQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), "Item Ledger Entry Type"::Sale, Date12M, Today);
//                     AsmConsLast12M := GetILEQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), "Item Ledger Entry Type"::"Assembly Consumption", Date12M, Today);
//                     UsageLast12M := SalesLast12M + AsmConsLast12M;
//                     PurchLast12M := GetPurchaseQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), Date12M, Today);

//                     // 13-15. All Time
//                     SalesAllTime := GetILEQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), "Item Ledger Entry Type"::Sale, 0D, 0D);
//                     AsmConsAllTime := GetILEQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), "Item Ledger Entry Type"::"Assembly Consumption", 0D, 0D);
//                     UsageAllTime := SalesAllTime + AsmConsAllTime;
//                     PurchAllTime := GetPurchaseQty(ItemRec."No.", TempItemVariant.Code, ItemInput.GetFilter("Location Filter"), 0D, 0D);
//                 end;

//                 // If this is the "Blank" variant and it has absolutely no data, skip it to keep the report clean.
//                 // However, if we are in "Collection" mode and this is the only variant, show it anyway.
//                 if (TempItemVariant.Code = '') and
//                    (QtyOnHand = 0) and
//                    (QtyOnPOS = 0) and
//                    (QtyOnSO = 0) and
//                    (QtyOnAsm = 0) and
//                    (QtyOnAsmComp = 0) and
//                    (UsageAllTime = 0) and
//                    not ((SelectedCollection <> '') and (TempItemVariant.Count = 1)) then begin
//                     // Skip
//                 end else begin
//                     // Excel Buffer Output
//                     ExcelBuf.NewRow();
//                     ExcelBuf.AddColumn(ItemInput."No.", false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
//                     ExcelBuf.AddColumn(ItemInput.Description, false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
//                     ExcelBuf.AddColumn(TempItemVariant.Code, false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
//                     ExcelBuf.AddColumn(VendorName, false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
//                     ExcelBuf.AddColumn(VendorSKU, false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
//                     if IsKit then
//                         ExcelBuf.AddColumn('Yes', false, '', false, false, false, '', ExcelBuf."Cell Type"::Text)
//                     else
//                         ExcelBuf.AddColumn('No', false, '', false, false, false, '', ExcelBuf."Cell Type"::Text);
//                     ExcelBuf.AddColumn(QtyOnHand, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);

//                     ExcelBuf.AddColumn(QtyOnPOS, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
//                     ExcelBuf.AddColumn(QtyOnSO, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
//                     ExcelBuf.AddColumn(QtyOnAsm, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
//                     ExcelBuf.AddColumn(QtyOnAsmComp, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
//                     ExcelBuf.AddColumn(RemainingQty, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);

//                     ExcelBuf.AddColumn(SalesLast3M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
//                     ExcelBuf.AddColumn(AsmConsLast3M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
//                     ExcelBuf.AddColumn(UsageLast3M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
//                     ExcelBuf.AddColumn(PurchLast3M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);

//                     ExcelBuf.AddColumn(SalesLast6M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
//                     ExcelBuf.AddColumn(AsmConsLast6M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
//                     ExcelBuf.AddColumn(UsageLast6M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
//                     ExcelBuf.AddColumn(PurchLast6M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);

//                     ExcelBuf.AddColumn(SalesLast12M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
//                     ExcelBuf.AddColumn(AsmConsLast12M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
//                     ExcelBuf.AddColumn(UsageLast12M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
//                     ExcelBuf.AddColumn(PurchLast12M, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);

//                     ExcelBuf.AddColumn(SalesAllTime, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
//                     ExcelBuf.AddColumn(AsmConsAllTime, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
//                     ExcelBuf.AddColumn(UsageAllTime, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
//                     ExcelBuf.AddColumn(PurchAllTime, false, '', false, false, false, '', ExcelBuf."Cell Type"::Number);
//                 end;

//             until TempItemVariant.Next() = 0;
//     end;
// }
