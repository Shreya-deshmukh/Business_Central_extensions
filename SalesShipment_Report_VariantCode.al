reportextension 98907 SalesShipmentReportExt extends 1308
{
    dataset
    {
        add(Line)
        {
            column(VariantCode; Line."Variant Code")
            {
            }
            column(LineNo; GetDisplayLineNo())
            {
            }
            column(OrderedQuantity; OrderedQty)
            {
            }
            column(OrderedQuantityText; FormatQty(OrderedQty))
            {
            }
            column(ShippedQuantity; Line.Quantity)
            {
            }
            column(ShippedQuantityText; FormatQty(Line.Quantity))
            {
            }
            column(BackOrderedQuantity; BackOrderedQty)
            {
            }
            column(BackOrderedQuantityText; FormatQty(BackOrderedQty))
            {
            }
            column(TotalQuantityShipped; Line."Total Quantity Shipped")
            {
            }
            column(TotalQuantityShippedText; FormatQty(Line."Total Quantity Shipped"))
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

        addafter(Line)
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

        modify(Line)
        {
            trigger OnBeforeAfterGetRecord()
            var
                OtherShptLine: Record "Sales Shipment Line";
                SalesShptLineOrdered: Record "Sales Shipment Line";
                IsFirst: Boolean;
            begin
                if Line."Document No." <> LastDocNo then begin
                    LastDocNo := Line."Document No.";
                    LineCounter := 0;
                    SumOrderedQty := 0;
                    SumShippedQty := 0;
                    SumBackOrderedQty := 0;
                    SumTotalQtyShipped := 0;
                    SumTotalQuantityShippedTillCurrentShipment := 0;
                end;
                // Only increment counter for non-comment lines
                if Line.Type <> Line.Type::" " then
                    LineCounter += 1;

                OrderedQty := 0;
                BackOrderedQty := 0;

                if (Line."Order No." <> '') and (Line."Order Line No." <> 0) then begin
                    if SalesLine.Get(SalesLine."Document Type"::Order, Line."Order No.", Line."Order Line No.") then begin
                        OrderedQty := SalesLine.Quantity;
                    end else begin
                        // Logic to calculate Ordered Qty if Sales Line is missing (e.g. fully shipped/invoiced)
                        SalesShptLineOrdered.SetRange("Order No.", Line."Order No.");
                        SalesShptLineOrdered.SetRange("Order Line No.", Line."Order Line No.");
                        SalesShptLineOrdered.CalcSums(Quantity);
                        OrderedQty := SalesShptLineOrdered.Quantity;
                    end;
                end;

                // Calculate TotalQuantityShippedTillCurrentShipment
                TotalQuantityShippedTillCurrentShipment := 0;
                IsFirst := true;
                if (Line."Order No." <> '') and (Line."Order Line No." <> 0) then begin
                    OtherShptLine.SetRange("Order No.", Line."Order No.");
                    OtherShptLine.SetRange("Order Line No.", Line."Order Line No.");
                    OtherShptLine.SetFilter("Posting Date", '<%1', Line."Posting Date");
                    if not OtherShptLine.IsEmpty then
                        IsFirst := false
                    else begin
                        OtherShptLine.SetRange("Posting Date", Line."Posting Date");
                        OtherShptLine.SetFilter("Document No.", '<%1', Line."Document No.");
                        if not OtherShptLine.IsEmpty then
                            IsFirst := false;
                    end;
                end;

                if IsFirst then
                    TotalQuantityShippedTillCurrentShipment := Line.Quantity
                else
                    TotalQuantityShippedTillCurrentShipment := Line.Quantity + Line."Total Quantity Shipped";

                // Calculate Backorder using the new variable
                if OrderedQty <> 0 then
                    BackOrderedQty := OrderedQty - TotalQuantityShippedTillCurrentShipment;

                // Now add to sums AFTER all values are calculated
                if Line.Type <> Line.Type::" " then begin
                    SumOrderedQty += OrderedQty;
                    SumShippedQty += Line.Quantity;
                    SumBackOrderedQty += BackOrderedQty;
                    SumTotalQtyShipped += Line."Total Quantity Shipped";
                    SumTotalQuantityShippedTillCurrentShipment += TotalQuantityShippedTillCurrentShipment;
                end;

            end;
        }
    }

    var
        LineCounter: Integer;
        LastDocNo: Code[20];
        SalesLine: Record "Sales Line";
        OrderedQty: Decimal;
        BackOrderedQty: Decimal;
        SumOrderedQty: Decimal;
        SumShippedQty: Decimal;
        SumBackOrderedQty: Decimal;
        SumTotalQtyShipped: Decimal;
        TotalQuantityShippedTillCurrentShipment: Decimal;
        SumTotalQuantityShippedTillCurrentShipment: Decimal;

    local procedure GetDisplayLineNo(): Text
    begin
        // Skip numbering for comment lines
        if Line.Type = Line.Type::" " then
            exit('');
        // Return the line number for non-comment lines
        exit(Format(LineCounter));
    end;

    local procedure FormatQty(Qty: Decimal): Text
    begin
        if Line.Type = Line.Type::" " then
            exit('');
        exit(Format(Qty, 0, '<Integer>'));
    end;

    local procedure FormatQtyTotal(Qty: Decimal): Text
    begin
        exit(Format(Qty, 0, '<Integer>'));
    end;
}

