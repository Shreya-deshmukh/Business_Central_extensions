codeunit 98909 "Sales Post Subscriber"
{
    Permissions = TableData "Sales Shipment Line" = rm;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterInsertShipmentLine', '', false, false)]
    local procedure OnAfterInsertShipmentLine(var SalesShptLine: Record "Sales Shipment Line"; SalesLine: Record "Sales Line"; SalesHeader: Record "Sales Header")
    begin
        // Store the current outstanding quantity as the backorder at the time of shipment
        SalesShptLine."Total Quantity Shipped" := SalesLine."Quantity Shipped";
        SalesShptLine.Modify();
    end;
}

