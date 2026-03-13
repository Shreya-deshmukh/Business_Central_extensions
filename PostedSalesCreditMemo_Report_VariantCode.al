reportextension 98908 PostedSalesCreditMemoReportExt extends 1307
{
    dataset
    {
        add(Header)
        {
            column(OrderNo; "Return Order No.")
            {
            }
        }

        add(Line)
        {
            column(VariantCode; Line."Variant Code")
            {
            }
            column(LineNo; GetDisplayLineNo())
            {
            }
            column(Ext_UnitOfMeasure; GetFormattedUOM())
            {
            }
        }

        modify(Line)
        {
            trigger OnBeforeAfterGetRecord()
            begin
                if Line."Document No." <> LastDocNo then begin
                    LastDocNo := Line."Document No.";
                    LineCounter := 0;
                end;
                // Only increment counter for non-comment lines
                if Line.Type <> Line.Type::" " then
                    LineCounter += 1;
            end;
        }
    }

    var
        LineCounter: Integer;
        LastDocNo: Code[20];

    local procedure GetDisplayLineNo(): Text
    begin
        // Skip numbering for comment lines
        if Line.Type = Line.Type::" " then
            exit('');
        // Return the line number for non-comment lines
        exit(Format(LineCounter));
    end;

    local procedure GetFormattedUOM(): Text
    begin
        if UpperCase(Line."Unit of Measure Code") = 'EA' then
            exit('Each');
        exit(Line."Unit of Measure Code");
    end;
}

