reportextension 98906 PostedSalesInvoiceReportExt extends 1306
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
}
