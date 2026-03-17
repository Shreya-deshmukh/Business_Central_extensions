enum 98932 RunFrequency
{
    Extensible = true;

    /// <summary>
    /// No frequency configured (e.g. schedule left blank in Job Queue).
    /// Per BC convention, the first enum value is the default and represents "not set".
    /// </summary>
    value(0; "Not Set")
    {
        Caption = 'Not Set';
    }
    value(1; Daily)
    {
        Caption = 'Daily';
    }
    value(2; Weekly)
    {
        Caption = 'Weekly';
    }
    value(3; Monthly)
    {
        Caption = 'Monthly';
    }
    value(4; Custom)
    {
        Caption = 'Custom';
    }
}
