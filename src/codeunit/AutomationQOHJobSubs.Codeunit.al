codeunit 98946 "Automation QOH Job Subs"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Job Queue Start Report", 'OnBeforeRunReport', '', false, false)]
    local procedure OnBeforeRunJQReport(ReportID: Integer; var JobQueueEntry: Record "Job Queue Entry"; var IsHandled: Boolean)
    var
        Ctx: Codeunit "Automation Job Context";
    begin
        if ReportID <> 98920 then
            exit;
        Ctx.SetCurrentJobQueueEntryNo(JobQueueEntry."Entry No.");
    end;
}
