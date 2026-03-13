table 98922 "Item Collection Header"
{
    DataClassification = ToBeClassified;
    LookupPageId = "Item Collection List";
    DrillDownPageId = "Item Collection List";

    fields
    {
        field(1; "Code"; Code[20])
        {
            DataClassification = CustomerContent;
            Caption = 'Collection Name';
        }
        field(2; Description; Text[50])
        {
            DataClassification = CustomerContent;
            Caption = 'Description';
        }
    }

    keys
    {
        key(PK; "Code")
        {
            Clustered = true;
        }
    }
}

table 98923 "Item Collection Line"
{
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "Collection Code"; Code[20])
        {
            DataClassification = CustomerContent;
            TableRelation = "Item Collection Header".Code;
        }
        field(2; "Item No."; Code[20])
        {
            DataClassification = CustomerContent;
            TableRelation = Item."No.";
        }
        field(3; "Item Description"; Text[100])
        {
            FieldClass = FlowField;
            CalcFormula = lookup(Item.Description where("No." = field("Item No.")));
            Editable = false;
            Caption = 'Item Description';
        }
        field(7; "Vendor No."; Code[20])
        {
            FieldClass = FlowField;
            CalcFormula = lookup(Item."Vendor No." where("No." = field("Item No.")));
            Editable = false;
            Caption = 'Vendor No.';
        }
        field(8; "Vendor Name"; Text[100])
        {
            FieldClass = FlowField;
            CalcFormula = lookup(Vendor.Name where("No." = field("Vendor No.")));
            Editable = false;
            Caption = 'Vendor Name';
        }
        field(9; "Vendor Item No."; Text[35])
        {
            FieldClass = FlowField;
            CalcFormula = lookup(Item."Vendor Item No." where("No." = field("Item No.")));
            Editable = false;
            Caption = 'Vendor Item No.';
        }
        field(4; Sequence; Integer)
        {
            DataClassification = CustomerContent;
            Caption = 'Sequence';
        }
        field(5; "Variant Code"; Code[10])
        {
            DataClassification = CustomerContent;
            TableRelation = "Item Variant".Code where("Item No." = field("Item No."));
            Caption = 'Variant Code';
        }
        field(6; "Variant Description"; Text[100])
        {
            FieldClass = FlowField;
            CalcFormula = lookup("Item Variant".Description where("Item No." = field("Item No."), Code = field("Variant Code")));
            Editable = false;
            Caption = 'Variant Description';
        }
    }

    keys
    {
        key(PK; "Collection Code", "Item No.")
        {
            Clustered = true;
        }
        key(Sort; "Collection Code", "Sequence")
        {
        }
    }

    trigger OnDelete()
    var
        VariantLine: Record "Item Collection Variant Line";
    begin
        // When an item is removed from the collection, delete all its variant lines.
        // If the user re-adds the same item later, it will start with a fresh list (no variants).
        VariantLine.SetRange("Collection Code", Rec."Collection Code");
        VariantLine.SetRange("Item No.", Rec."Item No.");
        VariantLine.DeleteAll();
    end;
}

table 98927 "Item Collection Variant Line"
{
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "Collection Code"; Code[20])
        {
            DataClassification = CustomerContent;
            TableRelation = "Item Collection Header".Code;
        }
        field(2; "Item No."; Code[20])
        {
            DataClassification = CustomerContent;
            TableRelation = Item."No.";
        }
        field(3; "Variant Code"; Code[10])
        {
            DataClassification = CustomerContent;
            TableRelation = "Item Variant".Code where("Item No." = field("Item No."));
            Caption = 'Variant Code';
        }
        field(4; "Variant Description"; Text[100])
        {
            FieldClass = FlowField;
            CalcFormula = lookup("Item Variant".Description where("Item No." = field("Item No."), Code = field("Variant Code")));
            Editable = false;
            Caption = 'Variant Description';
        }
        field(5; Sequence; Integer)
        {
            DataClassification = CustomerContent;
            Caption = 'Sequence';
        }
    }

    keys
    {
        key(PK; "Collection Code", "Item No.", "Variant Code")
        {
            Clustered = true;
        }
        key(Sort; "Collection Code", "Item No.", Sequence)
        {
        }
    }
}

page 98924 "Collection Name Input"
{
    PageType = StandardDialog;
    Caption = 'Enter Collection Name';

    layout
    {
        area(Content)
        {
            field(CollectionName; CollectionName)
            {
                ApplicationArea = All;
                Caption = 'Collection Name';
                NotBlank = true;
            }
        }
    }

    var
        CollectionName: Code[20];

    procedure GetCollectionName(): Code[20]
    begin
        exit(CollectionName);
    end;
}

page 98929 "Collection Move Position"
{
    PageType = StandardDialog;
    Caption = 'Move to Position';

    layout
    {
        area(Content)
        {
            field(Position; Position)
            {
                ApplicationArea = All;
                Caption = 'Position (1 = first)';
                MinValue = 1;
                ToolTip = 'Enter the target position (1 = first, higher number = last).';
            }
        }
    }

    var
        Position: Integer;

    procedure GetPosition(): Integer
    begin
        exit(Position);
    end;
}

page 98925 "Item Collection List"
{
    PageType = List;
    SourceTable = "Item Collection Header";
    Caption = 'Item Collection';
    UsageCategory = Lists;
    ApplicationArea = All;
    InsertAllowed = false;
    // CardPageId = "Item Collection Editor"; // Removed to fix table mismatch error

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Code"; Rec."Code")
                {
                    ApplicationArea = All;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
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
                Promoted = true;
                PromotedCategory = New;
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
                    // 1. Select Items
                    ItemList.LookupMode(true);
                    if ItemList.RunModal() = Action::LookupOK then begin
                        ItemList.SetSelectionFilter(ItemRec);
                        if ItemRec.FindSet() then begin
                            // 2. Get Name
                            if NameInput.RunModal() = Action::OK then begin
                                NewName := NameInput.GetCollectionName();
                                if NewName = '' then
                                    Error('Collection Name cannot be empty.');

                                if CollectionHeader.Get(NewName) then
                                    if not Confirm('Collection %1 already exists. Do you want to overwrite it?', false, NewName) then
                                        exit;

                                // 3. Create/Update Collection
                                if not CollectionHeader.Get(NewName) then begin
                                    CollectionHeader.Init();
                                    CollectionHeader.Code := NewName;
                                    CollectionHeader.Insert();
                                end;

                                // Clear existing lines if overwriting
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
                            end;
                        end;
                    end;
                end;
            }
            action(EditCollection)
            {
                ApplicationArea = All;
                Caption = 'Edit Items';
                Image = Edit;
                Promoted = true;
                PromotedCategory = Process;
                Scope = Repeater;
                ToolTip = 'Edit the list of items in this collection.';
                RunObject = Page "Item Collection Editor";
                RunPageLink = "Collection Code" = field(Code);
            }
        }
    }
}

page 98928 "Item Collection Variant Lines"
{
    PageType = ListPart;
    SourceTable = "Item Collection Variant Line";
    Caption = 'Variants for Item';
    SourceTableView = sorting("Collection Code", "Item No.", Sequence) order(ascending);

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(Sequence; Rec.Sequence)
                {
                    ApplicationArea = All;
                    Visible = false;
                }
                field("Variant Code"; Rec."Variant Code")
                {
                    ApplicationArea = All;
                }
                field("Variant Description"; Rec."Variant Description")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(MoveVariantUp)
            {
                ApplicationArea = All;
                Caption = 'Move Up';
                Image = MoveUp;
                Scope = Repeater;
                ToolTip = 'Move the selected variant up in the list.';

                trigger OnAction()
                var
                    CurrentLine: Record "Item Collection Variant Line";
                    PreviousLine: Record "Item Collection Variant Line";
                    TempSeq: Integer;
                begin
                    CurrentLine := Rec;
                    PreviousLine.SetCurrentKey("Collection Code", "Item No.", Sequence);
                    PreviousLine.SetRange("Collection Code", Rec."Collection Code");
                    PreviousLine.SetRange("Item No.", Rec."Item No.");
                    PreviousLine.SetFilter(Sequence, '<%1', Rec.Sequence);
                    if PreviousLine.FindLast() then begin
                        TempSeq := CurrentLine.Sequence;
                        CurrentLine.Sequence := PreviousLine.Sequence;
                        PreviousLine.Sequence := TempSeq;
                        PreviousLine.Modify();
                        CurrentLine.Modify();
                        CurrPage.Update(false);
                    end;
                end;
            }
            action(MoveVariantDown)
            {
                ApplicationArea = All;
                Caption = 'Move Down';
                Image = MoveDown;
                Scope = Repeater;
                ToolTip = 'Move the selected variant down in the list.';

                trigger OnAction()
                var
                    CurrentLine: Record "Item Collection Variant Line";
                    NextLine: Record "Item Collection Variant Line";
                    TempSeq: Integer;
                begin
                    CurrentLine := Rec;
                    NextLine.SetCurrentKey("Collection Code", "Item No.", Sequence);
                    NextLine.SetRange("Collection Code", Rec."Collection Code");
                    NextLine.SetRange("Item No.", Rec."Item No.");
                    NextLine.SetFilter(Sequence, '>%1', Rec.Sequence);
                    if NextLine.FindFirst() then begin
                        TempSeq := CurrentLine.Sequence;
                        CurrentLine.Sequence := NextLine.Sequence;
                        NextLine.Sequence := TempSeq;
                        NextLine.Modify();
                        CurrentLine.Modify();
                        CurrPage.Update(false);
                    end;
                end;
            }
            action(MoveVariantToTop)
            {
                ApplicationArea = All;
                Caption = 'Move to Top';
                Image = MoveUp;
                Scope = Repeater;
                ToolTip = 'Move the selected variant to the first position.';

                trigger OnAction()
                begin
                    MoveVariantLineToPosition(Rec, true, 0);
                end;
            }
            action(MoveVariantToBottom)
            {
                ApplicationArea = All;
                Caption = 'Move to Bottom';
                Image = MoveDown;
                Scope = Repeater;
                ToolTip = 'Move the selected variant to the last position.';

                trigger OnAction()
                begin
                    MoveVariantLineToPosition(Rec, false, 0);
                end;
            }
            action(MoveVariantToPosition)
            {
                ApplicationArea = All;
                Caption = 'Move to Position...';
                Image = Edit;
                Scope = Repeater;
                ToolTip = 'Move the selected variant to a specific position (1 = first).';

                trigger OnAction()
                var
                    PosInput: Page "Collection Move Position";
                    TargetPos: Integer;
                begin
                    if PosInput.RunModal() = Action::OK then begin
                        TargetPos := PosInput.GetPosition();
                        if TargetPos <= 1 then
                            MoveVariantLineToPosition(Rec, true, 0)
                        else
                            MoveVariantLineToPosition(Rec, false, TargetPos);
                    end;
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
        VariantLine: Record "Item Collection Variant Line";
        VariantLine2: Record "Item Collection Variant Line";
        Seq: Integer;
    begin
        VariantLine.SetRange(Sequence, 0);
        if VariantLine.FindSet() then
            repeat
                VariantLine2.SetCurrentKey("Collection Code", "Item No.", Sequence);
                VariantLine2.SetRange("Collection Code", VariantLine."Collection Code");
                VariantLine2.SetRange("Item No.", VariantLine."Item No.");
                VariantLine2.SetFilter(Sequence, '>0');
                if VariantLine2.FindLast() then
                    Seq := VariantLine2.Sequence + 10000
                else
                    Seq := 10000;
                VariantLine.Sequence := Seq;
                VariantLine.Modify();
            until VariantLine.Next() = 0;
    end;

    local procedure MoveVariantLineToPosition(CurrentRec: Record "Item Collection Variant Line"; MoveToFirst: Boolean; TargetPosition: Integer)
    var
        VariantLine: Record "Item Collection Variant Line";
        NewList: Text;
        CurrentVariant: Code[10];
        Seq: Integer;
        Count: Integer;
        InsertPos: Integer;
        i: Integer;
        Start: Integer;
        NextPos: Integer;
        SegmentLen: Integer;
        VariantCode: Code[10];
        CollCode: Code[20];
        ItemNo: Code[20];
    begin
        CollCode := CurrentRec."Collection Code";
        ItemNo := CurrentRec."Item No.";
        CurrentVariant := CurrentRec."Variant Code";

        VariantLine.SetCurrentKey("Collection Code", "Item No.", Sequence);
        VariantLine.SetRange("Collection Code", CollCode);
        VariantLine.SetRange("Item No.", ItemNo);
        if not VariantLine.FindSet() then
            exit;

        Count := 0;
        repeat
            Count += 1;
        until VariantLine.Next() = 0;

        // Build new order: remove current variant from list (same order)
        NewList := '';
        VariantLine.SetRange("Collection Code", CollCode);
        VariantLine.SetRange("Item No.", ItemNo);
        VariantLine.FindSet();
        repeat
            if VariantLine."Variant Code" <> CurrentVariant then
                NewList := NewList + '|' + VariantLine."Variant Code";
        until VariantLine.Next() = 0;

        if MoveToFirst then
            NewList := '|' + CurrentVariant + NewList
        else
            if (TargetPosition <= 0) or (TargetPosition >= Count) then
                NewList := NewList + '|' + CurrentVariant
            else begin
                InsertPos := 1;
                for i := 1 to TargetPosition do begin
                    NextPos := StrPos(CopyStr(NewList, InsertPos), '|');
                    if NextPos = 0 then
                        break;
                    InsertPos := InsertPos + NextPos;
                end;
                NewList := CopyStr(NewList, 1, InsertPos - 1) + CurrentVariant + '|' + CopyStr(NewList, InsertPos);
            end;

        // Assign new sequences from new order
        Seq := 10000;
        Start := 2;
        repeat
            NextPos := StrPos(CopyStr(NewList, Start), '|');
            if NextPos = 0 then
                SegmentLen := StrLen(NewList) - Start + 1
            else
                SegmentLen := NextPos - 1;
            if SegmentLen > 0 then begin
                VariantCode := CopyStr(CopyStr(NewList, Start, SegmentLen), 1, MaxStrLen(VariantCode));
                if (VariantCode <> '') and VariantLine.Get(CollCode, ItemNo, VariantCode) then begin
                    VariantLine.Sequence := Seq;
                    VariantLine.Modify();
                    Seq += 10000;
                end;
            end;
            if NextPos = 0 then
                break;
            Start := Start + NextPos;
        until false;

        CurrPage.Update(false);
    end;
}

page 98926 "Item Collection Editor"
{
    PageType = List;
    SourceTable = "Item Collection Line";
    Caption = 'Edit Collection Items';
    DataCaptionFields = "Collection Code";
    InsertAllowed = false;
    SourceTableView = sorting("Collection Code", "Sequence") order(ascending);

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(Sequence; Rec.Sequence)
                {
                    ApplicationArea = All;
                    Visible = false;
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Item Description"; Rec."Item Description")
                {
                    ApplicationArea = All;
                }
                field("Vendor Name"; Rec."Vendor Name")
                {
                    ApplicationArea = All;
                    DrillDown = false;
                    ToolTip = 'Vendor name from the item card.';
                }
                field("Vendor Item No."; Rec."Vendor Item No.")
                {
                    ApplicationArea = All;
                    DrillDown = false;
                    ToolTip = 'Vendor item number from the item card.';
                }

                // field("Variant Code"; Rec."Variant Code")
                // {
                //     ApplicationArea = All;
                //     Editable = false;
                // }
                // field("Variant Description"; Rec."Variant Description")
                // {
                //     ApplicationArea = All;
                // }

            }
            part(VariantLines; "Item Collection Variant Lines")
            {
                ApplicationArea = All;
                Caption = 'Variants for Selected Item';
                SubPageLink = "Collection Code" = field("Collection Code"), "Item No." = field("Item No.");
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AddItems)
            {
                ApplicationArea = All;
                Caption = 'Add Items';
                Image = Add;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Add items to the collection.';

                trigger OnAction()
                var
                    SimpleItemLookupPage: Page "Simple Item Lookup";
                    ItemRec: Record Item;
                    CollectionLine: Record "Item Collection Line";
                    LastLine: Record "Item Collection Line";
                    CurrentCollectionCode: Code[20];
                    NextSeq: Integer;
                begin
                    CurrentCollectionCode := Rec.GetRangeMax("Collection Code");

                    LastLine.SetCurrentKey("Collection Code", Sequence);
                    LastLine.SetRange("Collection Code", CurrentCollectionCode);
                    if LastLine.FindLast() then
                        NextSeq := LastLine.Sequence + 10000
                    else
                        NextSeq := 10000;

                    SimpleItemLookupPage.LookupMode(true);
                    if SimpleItemLookupPage.RunModal() = Action::LookupOK then begin
                        SimpleItemLookupPage.SetSelectionFilter(ItemRec);
                        if ItemRec.FindSet() then begin
                            repeat
                                CollectionLine.Init();
                                CollectionLine."Collection Code" := CurrentCollectionCode;
                                CollectionLine."Item No." := ItemRec."No.";
                                CollectionLine.Sequence := NextSeq;
                                if CollectionLine.Insert() then;
                                NextSeq += 10000;
                            until ItemRec.Next() = 0;
                        end;
                    end;
                end;
            }
            action(AddVariants)
            {
                ApplicationArea = All;
                Caption = 'Add Variants';
                Image = ItemVariant;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Add variant codes for the selected item.';
                Scope = Repeater;

                trigger OnAction()
                var
                    ItemVariant: Record "Item Variant";
                    ItemVariantPage: Page "Item Variant Lookup";
                    VariantLine: Record "Item Collection Variant Line";
                    LastVariant: Record "Item Collection Variant Line";
                    CurrentCollectionCode: Code[20];
                    CurrentItemNo: Code[20];
                    NextSeq: Integer;
                begin
                    CurrentCollectionCode := Rec."Collection Code";
                    CurrentItemNo := Rec."Item No.";

                    LastVariant.SetCurrentKey("Collection Code", "Item No.", Sequence);
                    LastVariant.SetRange("Collection Code", CurrentCollectionCode);
                    LastVariant.SetRange("Item No.", CurrentItemNo);
                    if LastVariant.FindLast() then
                        NextSeq := LastVariant.Sequence + 10000
                    else
                        NextSeq := 10000;

                    ItemVariant.SetRange("Item No.", CurrentItemNo);
                    ItemVariantPage.SetTableView(ItemVariant);
                    ItemVariantPage.LookupMode(true);
                    if ItemVariantPage.RunModal() = Action::LookupOK then begin
                        ItemVariantPage.SetSelectionFilter(ItemVariant);
                        if ItemVariant.FindSet() then begin
                            repeat
                                if not VariantLine.Get(CurrentCollectionCode, CurrentItemNo, ItemVariant.Code) then begin
                                    VariantLine.Init();
                                    VariantLine."Collection Code" := CurrentCollectionCode;
                                    VariantLine."Item No." := CurrentItemNo;
                                    VariantLine."Variant Code" := ItemVariant.Code;
                                    VariantLine.Sequence := NextSeq;
                                    VariantLine.Insert();
                                    NextSeq += 10000;
                                end;
                            until ItemVariant.Next() = 0;

                            CurrPage.Update(false);
                        end;
                    end;
                end;
            }
            action(RemoveVariants)
            {
                ApplicationArea = All;
                Caption = 'Remove Variants';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Remove all variant filters for the selected item (report will show all variants).';
                Scope = Repeater;

                trigger OnAction()
                var
                    VariantLine: Record "Item Collection Variant Line";
                begin
                    VariantLine.SetRange("Collection Code", Rec."Collection Code");
                    VariantLine.SetRange("Item No.", Rec."Item No.");
                    VariantLine.DeleteAll();
                    CurrPage.Update(false);
                end;
            }
            action(MoveUp)
            {
                ApplicationArea = All;
                Caption = 'Move Up';
                Image = MoveUp;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Move the selected item up in the list.';
                Scope = Repeater;

                trigger OnAction()
                var
                    CurrentLine: Record "Item Collection Line";
                    PreviousLine: Record "Item Collection Line";
                    TempSeq: Integer;
                begin
                    CurrentLine := Rec;
                    PreviousLine.SetCurrentKey("Collection Code", "Sequence");
                    PreviousLine.SetRange("Collection Code", Rec."Collection Code");
                    PreviousLine.SetFilter("Sequence", '<%1', Rec.Sequence);
                    if PreviousLine.FindLast() then begin
                        TempSeq := CurrentLine.Sequence;
                        CurrentLine.Sequence := PreviousLine.Sequence;
                        PreviousLine.Sequence := TempSeq;
                        PreviousLine.Modify();
                        CurrentLine.Modify();
                        CurrPage.Update(false);
                    end;
                end;
            }
            action(MoveDown)
            {
                ApplicationArea = All;
                Caption = 'Move Down';
                Image = MoveDown;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Move the selected item down in the list.';
                Scope = Repeater;

                trigger OnAction()
                var
                    CurrentLine: Record "Item Collection Line";
                    NextLine: Record "Item Collection Line";
                    TempSeq: Integer;
                begin
                    CurrentLine := Rec;
                    NextLine.SetCurrentKey("Collection Code", "Sequence");
                    NextLine.SetRange("Collection Code", Rec."Collection Code");
                    NextLine.SetFilter("Sequence", '>%1', Rec.Sequence);
                    if NextLine.FindFirst() then begin
                        TempSeq := CurrentLine.Sequence;
                        CurrentLine.Sequence := NextLine.Sequence;
                        NextLine.Sequence := TempSeq;
                        NextLine.Modify();
                        CurrentLine.Modify();
                        CurrPage.Update(false);
                    end;
                end;
            }
            action(MoveToTop)
            {
                ApplicationArea = All;
                Caption = 'Move to Top';
                Image = MoveUp;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Move the selected item to the first position in the collection.';
                Scope = Repeater;

                trigger OnAction()
                begin
                    MoveCollectionLineToPosition(Rec, true, 0);
                end;
            }
            action(MoveToBottom)
            {
                ApplicationArea = All;
                Caption = 'Move to Bottom';
                Image = MoveDown;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Move the selected item to the last position in the collection (e.g. drag first item to end).';
                Scope = Repeater;

                trigger OnAction()
                begin
                    MoveCollectionLineToPosition(Rec, false, 0);
                end;
            }
            action(MoveToPosition)
            {
                ApplicationArea = All;
                Caption = 'Move to Position...';
                Image = Edit;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                ToolTip = 'Move the selected item to a specific position (1 = first, last = bottom).';
                Scope = Repeater;

                trigger OnAction()
                var
                    PosInput: Page "Collection Move Position";
                    TargetPos: Integer;
                begin
                    if PosInput.RunModal() = Action::OK then begin
                        TargetPos := PosInput.GetPosition();
                        if TargetPos <= 1 then
                            MoveCollectionLineToPosition(Rec, true, 0)
                        else
                            MoveCollectionLineToPosition(Rec, false, TargetPos);
                    end;
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
        CollectionLine: Record "Item Collection Line";
        Seq: Integer;
        CurrentCode: Code[20];
    begin
        if Rec.GetFilter("Collection Code") <> '' then
            CurrentCode := Rec.GetRangeMin("Collection Code");

        if CurrentCode <> '' then begin
            CollectionLine.SetRange("Collection Code", CurrentCode);
            CollectionLine.SetRange(Sequence, 0);
            if not CollectionLine.IsEmpty() then begin
                CollectionLine.SetRange(Sequence);
                if CollectionLine.FindSet() then begin
                    Seq := 10000;
                    repeat
                        CollectionLine.Sequence := Seq;
                        CollectionLine.Modify();
                        Seq += 10000;
                    until CollectionLine.Next() = 0;
                end;
            end;
        end;
    end;

    local procedure MoveCollectionLineToPosition(CurrentRec: Record "Item Collection Line"; MoveToFirst: Boolean; TargetPosition: Integer)
    var
        CollectionLine: Record "Item Collection Line";
        NewList: Text;
        CurrentItem: Code[20];
        Seq: Integer;
        Count: Integer;
        InsertPos: Integer;
        i: Integer;
        Start: Integer;
        NextPos: Integer;
        SegmentLen: Integer;
        ItemNo: Code[20];
        CollCode: Code[20];
    begin
        CollCode := CurrentRec."Collection Code";
        CurrentItem := CurrentRec."Item No.";

        CollectionLine.SetCurrentKey("Collection Code", "Sequence");
        CollectionLine.SetRange("Collection Code", CollCode);
        if not CollectionLine.FindSet() then
            exit;

        Count := 0;
        repeat
            Count += 1;
        until CollectionLine.Next() = 0;

        // Build new order: remove current item from list (same order)
        NewList := '';
        CollectionLine.SetRange("Collection Code", CollCode);
        CollectionLine.FindSet();
        repeat
            if CollectionLine."Item No." <> CurrentItem then
                NewList := NewList + '|' + CollectionLine."Item No.";
        until CollectionLine.Next() = 0;

        if MoveToFirst then
            NewList := '|' + CurrentItem + NewList
        else
            if (TargetPosition <= 0) or (TargetPosition >= Count) then
                NewList := NewList + '|' + CurrentItem
            else begin
                // Insert current item at 1-based TargetPosition; advance to start of that position
                InsertPos := 1;
                for i := 1 to TargetPosition do begin
                    NextPos := StrPos(CopyStr(NewList, InsertPos), '|');
                    if NextPos = 0 then
                        break;
                    InsertPos := InsertPos + NextPos;
                end;
                // Insert without extra '|' so we don't create an empty segment when parsing
                NewList := CopyStr(NewList, 1, InsertPos - 1) + CurrentItem + '|' + CopyStr(NewList, InsertPos);
            end;

        // Assign new sequences from new order (parse NewList and update)
        Seq := 10000;
        Start := 2; // skip leading |
        repeat
            NextPos := StrPos(CopyStr(NewList, Start), '|');
            if NextPos = 0 then
                SegmentLen := StrLen(NewList) - Start + 1
            else
                SegmentLen := NextPos - 1;
            if SegmentLen > 0 then begin
                ItemNo := CopyStr(CopyStr(NewList, Start, SegmentLen), 1, MaxStrLen(ItemNo));
                if (ItemNo <> '') and CollectionLine.Get(CollCode, ItemNo) then begin
                    CollectionLine.Sequence := Seq;
                    CollectionLine.Modify();
                    Seq += 10000;
                end;
            end;
            if NextPos = 0 then
                break;
            Start := Start + NextPos;
        until false;

        CurrPage.Update(false);
    end;
}
