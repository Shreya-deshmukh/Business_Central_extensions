reportextension 98909 Report10077Ext extends 10077
{
    dataset
    {
        add("Sales Shipment Header")
        {
            column(Ext_DocumentNo; "No.")
            {
            }
            column(Ext_DocumentDate; Format("Document Date", 0, '<Month Text> <Day>, <Year4>'))
            {
            }
            column(Ext_PostingDate; "Posting Date")
            {
            }
            column(Ext_BillToCustomerNo; "Bill-to Customer No.")
            {
            }
            column(Ext_BillToName; "Bill-to Name")
            {
            }
            column(Ext_BillToAddress; "Bill-to Address")
            {
            }
            column(Ext_BillToAddress2; "Bill-to Address 2")
            {
            }
            column(Ext_BillToCity; "Bill-to City")
            {
            }
            column(Ext_BillToPostCode; "Bill-to Post Code")
            {
            }
            column(Ext_ShipToName; "Ship-to Name")
            {
            }
            column(Ext_ShipToAddress; "Ship-to Address")
            {
            }
            column(Ext_ShipToAddress2; "Ship-to Address 2")
            {
            }
            column(Ext_ShipToCity; "Ship-to City")
            {
            }
            column(Ext_ShipToPostCode; "Ship-to Post Code")
            {
            }
            column(Ext_OrderNo; "Order No.")
            {
            }
            column(Ext_ExternalDocumentNo; "External Document No.")
            {
            }
            column(Ext_ShipmentDate; Format("Shipment Date", 0, '<Month Text> <Day>, <Year4>'))
            {
            }
            column(Ext_ShippingAgentCode; "Shipping Agent Code")
            {
            }
            column(Ext_PackageTrackingNo; "Package Tracking No.")
            {
            }
            column(CompInfo_Name; CompInfo.Name)
            {
            }
            column(CompInfo_Address; CompInfo.Address)
            {
            }
            column(CompInfo_Address2; CompInfo."Address 2")
            {
            }
            column(CompInfo_City; CompInfo.City)
            {
            }
            column(CompInfo_PostCode; CompInfo."Post Code")
            {
            }
            column(CompInfo_Picture; CompInfo.Picture)
            {
            }
        }
        modify("Sales Shipment Header")
        {
            trigger OnAfterAfterGetRecord()
            var
                SSL: Record "Sales Shipment Line";
                SalesShptLineOrdered: Record "Sales Shipment Line";
                OtherShptLine: Record "Sales Shipment Line";
                TempOrderedQty: Decimal;
                TempBackOrderedQty: Decimal;
                TempTotalQtyShippedTillCurrent: Decimal;
                IsFirst: Boolean;
            begin
                // Initialize for the new document
                TempSSL_Global.Reset();
                TempSSL_Global.DeleteAll();
                SumOrderedQty_SSL := 0;
                SumShippedQty_SSL := 0;
                SumBackOrderedQty_SSL := 0;
                SumTotalQtyShipped_SSL := 0;
                SumTotalQuantityShippedTillCurrentShipment_SSL := 0;
                // Pre-calculate totals and populate temp table for the Integer loop
                SSL.SetRange("Document No.", "No.");
                if SSL.FindSet() then
                    repeat // Store the line in temp table
                        TempSSL_Global := SSL;
                        TempSSL_Global.Insert();
                        // Only calculate totals for non-comment lines
                        if SSL.Type <> SSL.Type::" " then begin
                            TempOrderedQty := 0;
                            TempBackOrderedQty := 0;
                            TempTotalQtyShippedTillCurrent := 0;
                            // Calculate Ordered Qty
                            if (SSL."Order No." <> '') and (SSL."Order Line No." <> 0) then begin
                                if SalesLine.Get(SalesLine."Document Type"::Order, SSL."Order No.", SSL."Order Line No.") then begin
                                    TempOrderedQty := SalesLine.Quantity;
                                end
                                else begin
                                    SalesShptLineOrdered.SetRange("Order No.", SSL."Order No.");
                                    SalesShptLineOrdered.SetRange("Order Line No.", SSL."Order Line No.");
                                    SalesShptLineOrdered.CalcSums(Quantity);
                                    TempOrderedQty := SalesShptLineOrdered.Quantity;
                                end;
                            end;
                            // Calculate Total Shipped Till Current
                            IsFirst := true;
                            if (SSL."Order No." <> '') and (SSL."Order Line No." <> 0) then begin
                                OtherShptLine.SetRange("Order No.", SSL."Order No.");
                                OtherShptLine.SetRange("Order Line No.", SSL."Order Line No.");
                                OtherShptLine.SetFilter("Posting Date", '<%1', SSL."Posting Date");
                                if not OtherShptLine.IsEmpty then
                                    IsFirst := false
                                else begin
                                    OtherShptLine.SetRange("Posting Date", SSL."Posting Date");
                                    OtherShptLine.SetFilter("Document No.", '<%1', SSL."Document No.");
                                    if not OtherShptLine.IsEmpty then IsFirst := false;
                                end;
                            end;
                            if IsFirst then
                                TempTotalQtyShippedTillCurrent := SSL.Quantity
                            else
                                TempTotalQtyShippedTillCurrent := SSL.Quantity + SSL."Total Quantity Shipped";
                            // Calculate Backorder
                            if TempOrderedQty <> 0 then TempBackOrderedQty := TempOrderedQty - TempTotalQtyShippedTillCurrent;
                            // Accumulate Grand Totals
                            SumOrderedQty_SSL += TempOrderedQty;
                            SumShippedQty_SSL += SSL.Quantity;
                            SumBackOrderedQty_SSL += TempBackOrderedQty;
                            SumTotalQtyShipped_SSL += SSL."Total Quantity Shipped";
                            SumTotalQuantityShippedTillCurrentShipment_SSL += TempTotalQtyShippedTillCurrent;
                        end;
                    until SSL.Next() = 0;
            end;
        }
        add("Sales Shipment Line")
        {
            column(Ext_ItemNo; "Sales Shipment Line"."No.")
            {
            }
            column(Ext_Description; "Sales Shipment Line".Description)
            {
            }
            column(Ext_UnitOfMeasure; FormatUOM("Sales Shipment Line"."Unit of Measure Code"))
            {
            }
            column(VariantCode; "Sales Shipment Line"."Variant Code")
            {
            }
            column(LineNo; GetDisplayLineNo())
            {
            }
            column(OrderedQuantityText; FormatQty(OrderedQty))
            {
            }
            column(ShippedQuantity; "Sales Shipment Line".Quantity)
            {
            }
            column(ShippedQuantityText; FormatQty("Sales Shipment Line".Quantity))
            {
            }
            column(BackOrderedQuantityText; FormatQty(BackOrderedQty))
            {
            }
            column(TotalQuantityShipped; "Sales Shipment Line"."Total Quantity Shipped")
            {
            }
            column(TotalQuantityShippedText; FormatQty("Sales Shipment Line"."Total Quantity Shipped"))
            {
            }
            column(SumOrderedQty; SumOrderedQty)
            {
            }
            column(SumShippedQty; SumShippedQty)
            {
            }
            column(SumBackOrderedQty; SumBackOrderedQty)
            {
            }
            column(SumTotalQtyShipped; SumTotalQtyShipped)
            {
            }
            column(TotalQuantityShippedTillCurrentShipment; TotalQuantityShippedTillCurrentShipment)
            {
            }
            column(TotalQuantityShippedTillCurrentShipmentText; FormatQty(TotalQuantityShippedTillCurrentShipment))
            {
            }
            column(SumTotalQuantityShippedTillCurrentShipment; SumTotalQuantityShippedTillCurrentShipment)
            {
            }
        }
        addafter("Sales Shipment Line")
        {
            dataitem(TotalsLine; Integer)
            {
                DataItemTableView = sorting(Number) where(Number = const(1));

                column(TotalOrderedQtyValue; SumOrderedQty)
                {
                }
                column(TotalOrderedQtyText; FormatQtyTotal(SumOrderedQty))
                {
                }
                column(TotalShippedQtyValue; SumShippedQty)
                {
                }
                column(TotalShippedQtyText; FormatQtyTotal(SumShippedQty))
                {
                }
                column(QuantitySum; FormatQtyTotal(SumOrderedQty))
                {
                }
                column(TotalBackOrderedQtyValue; SumBackOrderedQty)
                {
                }
                column(TotalBackOrderedQtyText; FormatQtyTotal(SumBackOrderedQty))
                {
                }
                column(TotalShippedTillCurrentValue; SumTotalQuantityShippedTillCurrentShipment)
                {
                }
                column(TotalShippedTillCurrentText; FormatQtyTotal(SumTotalQuantityShippedTillCurrentShipment))
                {
                }
            }
        }
        modify("Sales Shipment Line")
        {
            trigger OnBeforeAfterGetRecord()
            var
                OtherShptLine: Record "Sales Shipment Line";
                SalesShptLineOrdered: Record "Sales Shipment Line";
                IsFirst: Boolean;
            begin
                // Store parent item's variant code for assembly components
                ParentItemVariantCode := "Sales Shipment Line"."Variant Code";
                // Also store in temporary table for reliable retrieval in AsmLoop
                TempVariantCode.SetRange("Document No.", "Sales Shipment Line"."Document No.");
                TempVariantCode.SetRange("Line No.", "Sales Shipment Line"."Line No.");
                if not TempVariantCode.FindFirst() then begin
                    TempVariantCode := "Sales Shipment Line";
                    TempVariantCode.Insert();
                end;

                if "Sales Shipment Line"."Document No." <> LastDocNo then begin
                    LastDocNo := "Sales Shipment Line"."Document No.";
                    LineCounter := 0;
                    SumOrderedQty := 0;
                    SumShippedQty := 0;
                    SumBackOrderedQty := 0;
                    SumTotalQtyShipped := 0;
                    SumTotalQuantityShippedTillCurrentShipment := 0;
                end;
                // Only increment counter for non-comment lines
                if "Sales Shipment Line".Type <> "Sales Shipment Line".Type::" " then LineCounter += 1;
                OrderedQty := 0;
                BackOrderedQty := 0;
                if ("Sales Shipment Line"."Order No." <> '') and ("Sales Shipment Line"."Order Line No." <> 0) then begin
                    if SalesLine.Get(SalesLine."Document Type"::Order, "Sales Shipment Line"."Order No.", "Sales Shipment Line"."Order Line No.") then begin
                        OrderedQty := SalesLine.Quantity;
                    end
                    else begin
                        // Logic to calculate Ordered Qty if Sales Line is missing (e.g. fully shipped/invoiced)
                        SalesShptLineOrdered.SetRange("Order No.", "Sales Shipment Line"."Order No.");
                        SalesShptLineOrdered.SetRange("Order Line No.", "Sales Shipment Line"."Order Line No.");
                        SalesShptLineOrdered.CalcSums(Quantity);
                        OrderedQty := SalesShptLineOrdered.Quantity;
                    end;
                end;
                // Calculate TotalQuantityShippedTillCurrentShipment
                TotalQuantityShippedTillCurrentShipment := 0;
                IsFirst := true;
                if ("Sales Shipment Line"."Order No." <> '') and ("Sales Shipment Line"."Order Line No." <> 0) then begin
                    OtherShptLine.SetRange("Order No.", "Sales Shipment Line"."Order No.");
                    OtherShptLine.SetRange("Order Line No.", "Sales Shipment Line"."Order Line No.");
                    OtherShptLine.SetFilter("Posting Date", '<%1', "Sales Shipment Line"."Posting Date");
                    if not OtherShptLine.IsEmpty then
                        IsFirst := false
                    else begin
                        OtherShptLine.SetRange("Posting Date", "Sales Shipment Line"."Posting Date");
                        OtherShptLine.SetFilter("Document No.", '<%1', "Sales Shipment Line"."Document No.");
                        if not OtherShptLine.IsEmpty then IsFirst := false;
                    end;
                end;
                if IsFirst then
                    TotalQuantityShippedTillCurrentShipment := "Sales Shipment Line".Quantity
                else
                    TotalQuantityShippedTillCurrentShipment := "Sales Shipment Line".Quantity + "Sales Shipment Line"."Total Quantity Shipped";
                // Calculate Backorder using the new variable
                if OrderedQty <> 0 then BackOrderedQty := OrderedQty - TotalQuantityShippedTillCurrentShipment;
                // Now add to sums AFTER all values are calculated
                if "Sales Shipment Line".Type <> "Sales Shipment Line".Type::" " then begin
                    SumOrderedQty += OrderedQty;
                    SumShippedQty += "Sales Shipment Line".Quantity;
                    SumBackOrderedQty += BackOrderedQty;
                    SumTotalQtyShipped += "Sales Shipment Line"."Total Quantity Shipped";
                    SumTotalQuantityShippedTillCurrentShipment += TotalQuantityShippedTillCurrentShipment;
                end;
            end;
        }
        add(SalesShptLine)
        {
            column(Ext_ItemNo_SSL; TempSSL_Global."No.")
            {
            }
            column(Ext_Description_SSL; TempSSL_Global.Description)
            {
            }
            column(Ext_UnitOfMeasure_SSL; FormatUOM(TempSSL_Global."Unit of Measure Code"))
            {
            }
            column(VariantCode_SSL; TempSSL_Global."Variant Code")
            {
            }
            column(LineNo_SSL; GetDisplayLineNo_SSL(LineCounter_SSL, TempSSL_Global.Type = TempSSL_Global.Type::" "))
            {
            }
            column(OrderedQuantityText_SSL; FormatQty_SSL(OrderedQty_SSL, TempSSL_Global.Type = TempSSL_Global.Type::" "))
            {
            }
            column(ShippedQuantity_SSL; TempSSL_Global.Quantity)
            {
            }
            column(ShippedQuantityText_SSL; FormatQty_SSL(TempSSL_Global.Quantity, TempSSL_Global.Type = TempSSL_Global.Type::" "))
            {
            }
            column(BackOrderedQuantityText_SSL; FormatQty_SSL(BackOrderedQty_SSL, TempSSL_Global.Type = TempSSL_Global.Type::" "))
            {
            }
            column(TotalQuantityShipped_SSL; TempSSL_Global."Total Quantity Shipped")
            {
            }
            column(TotalQuantityShippedText_SSL; FormatQty_SSL(TempSSL_Global."Total Quantity Shipped", TempSSL_Global.Type = TempSSL_Global.Type::" "))
            {
            }
            column(SumOrderedQty_SSL; SumOrderedQty_SSL)
            {
            }
            column(SumShippedQty_SSL; SumShippedQty_SSL)
            {
            }
            column(SumBackOrderedQty_SSL; SumBackOrderedQty_SSL)
            {
            }
            column(SumTotalQtyShipped_SSL; SumTotalQtyShipped_SSL)
            {
            }
            column(TotalQuantityShippedTillCurrentShipment_SSL; TotalQuantityShippedTillCurrentShipment_SSL)
            {
            }
            column(TotalQuantityShippedTillCurrentShipmentText_SSL; FormatQty_SSL(TotalQuantityShippedTillCurrentShipment_SSL, TempSSL_Global.Type = TempSSL_Global.Type::" "))
            {
            }
            column(SumTotalQuantityShippedTillCurrentShipment_SSL; SumTotalQuantityShippedTillCurrentShipment_SSL)
            {
            }
        }
        modify(SalesShptLine)
        {
            trigger OnBeforeAfterGetRecord()
            var
                OtherShptLine: Record "Sales Shipment Line";
                SalesShptLineOrdered: Record "Sales Shipment Line";
                IsFirst: Boolean;
            begin
                if Number = 1 then begin
                    if not TempSSL_Global.FindSet() then Clear(TempSSL_Global);
                end
                else begin
                    if TempSSL_Global.Next() = 0 then Clear(TempSSL_Global);
                end;
                if TempSSL_Global."Document No." <> LastDocNo_SSL then begin
                    LastDocNo_SSL := TempSSL_Global."Document No.";
                    LineCounter_SSL := 0;
                    // Note: Sums are now pre-calculated in Header and remain constant (Grand Total)
                    // If running total is needed, we would reset and accumulate here. 
                    // But assuming "Incorrect values" means they want the actual totals.
                end;
                if TempSSL_Global.Type <> TempSSL_Global.Type::" " then LineCounter_SSL += 1;
                OrderedQty_SSL := 0;
                BackOrderedQty_SSL := 0;
                // Re-calculate line-specific values for display
                if (TempSSL_Global."Order No." <> '') and (TempSSL_Global."Order Line No." <> 0) then begin
                    if SalesLine.Get(SalesLine."Document Type"::Order, TempSSL_Global."Order No.", TempSSL_Global."Order Line No.") then begin
                        OrderedQty_SSL := SalesLine.Quantity;
                    end
                    else begin
                        SalesShptLineOrdered.SetRange("Order No.", TempSSL_Global."Order No.");
                        SalesShptLineOrdered.SetRange("Order Line No.", TempSSL_Global."Order Line No.");
                        SalesShptLineOrdered.CalcSums(Quantity);
                        OrderedQty_SSL := SalesShptLineOrdered.Quantity;
                    end;
                end;
                TotalQuantityShippedTillCurrentShipment_SSL := 0;
                IsFirst := true;
                if (TempSSL_Global."Order No." <> '') and (TempSSL_Global."Order Line No." <> 0) then begin
                    OtherShptLine.SetRange("Order No.", TempSSL_Global."Order No.");
                    OtherShptLine.SetRange("Order Line No.", TempSSL_Global."Order Line No.");
                    OtherShptLine.SetFilter("Posting Date", '<%1', TempSSL_Global."Posting Date");
                    if not OtherShptLine.IsEmpty then
                        IsFirst := false
                    else begin
                        OtherShptLine.SetRange("Posting Date", TempSSL_Global."Posting Date");
                        OtherShptLine.SetFilter("Document No.", '<%1', TempSSL_Global."Document No.");
                        if not OtherShptLine.IsEmpty then IsFirst := false;
                    end;
                end;
                if IsFirst then
                    TotalQuantityShippedTillCurrentShipment_SSL := TempSSL_Global.Quantity
                else
                    TotalQuantityShippedTillCurrentShipment_SSL := TempSSL_Global.Quantity + TempSSL_Global."Total Quantity Shipped";
                if OrderedQty_SSL <> 0 then BackOrderedQty_SSL := OrderedQty_SSL - TotalQuantityShippedTillCurrentShipment_SSL;
            end;
        }
        modify(AsmLoop)
        {
            trigger OnBeforeAfterGetRecord()
            var
                ATOLink: Record "Posted Assemble-to-Order Link";
                PostedAsmHeader: Record "Posted Assembly Header";
                ParentShipmentLine: Record "Sales Shipment Line";
                SalesOrderLine: Record "Sales Line";
            begin
                if Number = 1 then begin
                    MyPostedAsmLine.Reset();
                    // Try to find ATOLink using current Sales Shipment Line context
                    ATOLink.SetRange("Document Type", ATOLink."Document Type"::"Sales Shipment");
                    ATOLink.SetRange("Document No.", "Sales Shipment Line"."Document No.");
                    ATOLink.SetRange("Document Line No.", "Sales Shipment Line"."Line No.");
                    if ATOLink.FindFirst() then begin
                        MyPostedAsmLine.SetRange("Document No.", ATOLink."Assembly Document No.");
                        // Since AsmLoop is nested under Sales Shipment Line, the current "Sales Shipment Line" 
                        // IS the parent line. Use its variant code directly.
                        // First try to get from Sales Order Line (most reliable)
                        if ("Sales Shipment Line"."Order No." <> '') and ("Sales Shipment Line"."Order Line No." <> 0) then begin
                            if SalesOrderLine.Get(SalesOrderLine."Document Type"::Order, "Sales Shipment Line"."Order No.", "Sales Shipment Line"."Order Line No.") then begin
                                ParentItemVariantCode := SalesOrderLine."Variant Code";
                                DebugGetSuccess := true;
                            end;
                        end;
                        // If Sales Order Line lookup failed, use current Sales Shipment Line variant code
                        if ParentItemVariantCode = '' then begin
                            ParentItemVariantCode := "Sales Shipment Line"."Variant Code";
                            // Set DebugGetSuccess based on whether variant code exists
                            DebugGetSuccess := (ParentItemVariantCode <> '');
                        end;
                        // Debug: Store ATOLink values
                        DebugATODocNo := ATOLink."Document No.";
                        DebugATOLineNo := ATOLink."Document Line No.";
                        if not MyPostedAsmLine.FindSet() then
                            Clear(MyPostedAsmLine);
                    end
                    else begin
                        // ATOLink not found - use stored value from Sales Shipment Line trigger
                        // ParentItemVariantCode should already be set when processing the parent line
                        if ParentItemVariantCode = '' then
                            ParentItemVariantCode := "Sales Shipment Line"."Variant Code";
                        DebugATODocNo := '';
                        DebugATOLineNo := 0;
                        DebugGetSuccess := false;
                    end;
                    AsmComponentLineNo := 1;
                    IsFirstAsmComponent := true;
                end
                else begin
                    MyPostedAsmLine.Next();
                    AsmComponentLineNo += 1;
                    IsFirstAsmComponent := false;
                end;
            end;
        }
        add(AsmLoop)
        {
            column(PostedAsmLineVariantCode; GetAsmVariantCode())
            {
            }
            column(AsmComponentLineNo; AsmComponentLineNo)
            {
            }
            column(DebugParentVariantCode; ParentItemVariantCode)
            {
            }
            column(DebugIsFirst; IsFirstAsmComponent)
            {
            }
            column(DebugSalesShptLineDocNo; "Sales Shipment Line"."Document No.")
            {
            }
            column(DebugSalesShptLineNo; "Sales Shipment Line"."Line No.")
            {
            }
            column(DebugSalesShptVariant; "Sales Shipment Line"."Variant Code")
            {
            }
            column(DebugATODocNo; DebugATODocNo)
            {
            }
            column(DebugATOLineNo; DebugATOLineNo)
            {
            }
            column(DebugGetSuccess; DebugGetSuccess)
            {
            }
        }
    }
    var
        LineCounter: Integer;
        LastDocNo: Code[20];
        SalesLine: Record "Sales Line";
        CompInfo: Record "Company Information";
        OrderedQty: Decimal;
        BackOrderedQty: Decimal;
        SumOrderedQty: Decimal;
        SumShippedQty: Decimal;
        SumBackOrderedQty: Decimal;
        SumTotalQtyShipped: Decimal;
        TotalQuantityShippedTillCurrentShipment: Decimal;
        SumTotalQuantityShippedTillCurrentShipment: Decimal;
        // New variables for SalesShptLine
        TempSSL_Global: Record "Sales Shipment Line" temporary;
        LineCounter_SSL: Integer;
        LastDocNo_SSL: Code[20];
        OrderedQty_SSL: Decimal;
        BackOrderedQty_SSL: Decimal;
        SumOrderedQty_SSL: Decimal;
        SumShippedQty_SSL: Decimal;
        SumBackOrderedQty_SSL: Decimal;
        SumTotalQtyShipped_SSL: Decimal;
        TotalQuantityShippedTillCurrentShipment_SSL: Decimal;
        SumTotalQuantityShippedTillCurrentShipment_SSL: Decimal;
        MyPostedAsmLine: Record "Posted Assembly Line";
        IsFirstAsmComponent: Boolean;
        AsmComponentLineNo: Integer;
        ParentItemVariantCode: Code[10];
        DebugATODocNo: Code[20];
        DebugATOLineNo: Integer;
        DebugGetSuccess: Boolean;
        TempVariantCode: Record "Sales Shipment Line" temporary;

    trigger OnPreReport()
    begin
        CompInfo.Get();
        CompInfo.CalcFields(Picture);
    end;

    local procedure GetDisplayLineNo(): Text
    begin
        // Skip numbering for comment lines
        if "Sales Shipment Line".Type = "Sales Shipment Line".Type::" " then exit('');
        // Return the line number for non-comment lines
        exit(Format(LineCounter));
    end;

    local procedure FormatQty(Qty: Decimal): Text
    begin
        if "Sales Shipment Line".Type = "Sales Shipment Line".Type::" " then exit('');
        exit(Format(Qty, 0, '<Integer>'));
    end;

    local procedure FormatQtyTotal(Qty: Decimal): Text
    begin
        exit(Format(Qty, 0, '<Integer>'));
    end;

    local procedure GetDisplayLineNo_SSL(LineCount: Integer; IsComment: Boolean): Text
    begin
        if IsComment then exit('');
        exit(Format(LineCount));
    end;

    local procedure FormatQty_SSL(Qty: Decimal; IsComment: Boolean): Text
    begin
        if IsComment then exit('');
        exit(Format(Qty, 0, '<Integer>'));
    end;

    local procedure FormatUOM(UOMCode: Code[10]): Text
    begin
        if UpperCase(UOMCode) = 'EA' then exit('Each');
        exit(UOMCode);
    end;

    local procedure GetAsmVariantCode(): Code[10]
    begin
        // Show parent item's variant code for all assembly component lines
        exit(ParentItemVariantCode);
    end;
}
