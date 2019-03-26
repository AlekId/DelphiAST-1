﻿unit AST.Parser.Contexts;

interface

uses System.SysUtils,
     NPCompiler.Operators,
     IL.Types,
     NPCompiler.Classes,
     AST.Classes;

type

  TASTSContext<TProc> = record
  private
    fModule: TASTModule;
    fProc: TProc;
    fBlock: TASTBlock;
  public
    constructor Create(const Module: TASTModule; Proc: TProc; Block: TASTBlock); overload;
    constructor Create(const Module: TASTModule); overload;
    function MakeChild(Block: TASTBlock): TASTSContext<TProc>; inline;
    function Add<T: TASTItem>: T;
    procedure AddItem(const Item: TASTItem);
    property Module: TASTModule read fModule;
    property Proc: TProc read fProc;
    property Block: TASTBlock read fBlock;
  end;

  TExpessionPosition = NPCompiler.Classes.TExpessionPosition;// (ExprNested, ExprLValue, ExprRValue, ExprNestedGeneric);

  TRPNStatus = (rprOk, rpOperand, rpOperation);

  {expression context - use RPN (Reverse Polish Notation) stack}
  TASTEContext<TProc> = record
  type
    TRPNItems = array of TOperatorID;
    TRPNError = (reDublicateOperation, reUnnecessaryClosedBracket, reUnclosedOpenBracket);
    TRPNPocessProc = function (var EContext: TASTEContext<TProc>; OpID: TOperatorID): TIDExpression of object;
  private
    fRPNOArray: TRPNItems;              // Operations array
    fRPNEArray: TIDExpressions;         // Operands array
    fRPNOArrayLen: Integer;             // пердвычисленный размер входного списка
    fRPNOpCount: Integer;               // указывает на следющий свободный элемент входного списка
    fRPNEArrayLen: Integer;             // пердвычисленный размер выходного списка
    fRPNExprCount: Integer;             // указывает на следющий свободный элемент выходного списка
    fRPNLastOp: TOperatorID;
    fRPNPrevPriority: Integer;
    fProcessProc: TRPNPocessProc;
    fPosition: TExpessionPosition;      // позиция выражения (Nested, LValue, RValue...);
    fSContext: TASTSContext<TProc>;
    procedure RPNCheckInputSize;
    function GetExpression: TIDExpression;
    function GetProc: TProc;
  public
    procedure Initialize(const SContext: TASTSContext<TProc>; const ProcessProc: TRPNPocessProc);
    procedure Reset;                    // clear RPN stack and reinit
    procedure RPNPushExpression(Expr: TIDExpression);
    procedure RPNError(Status: TRPNError);
    procedure RPNPushOpenRaund;
    procedure RPNPushCloseRaund;
    procedure RPNEraiseTopOperator;
    procedure RPNFinish;
    function RPNPopOperator: TIDExpression;
    function RPNPushOperator(OpID: TOperatorID): TRPNStatus;
    function RPNReadExpression(Index: Integer): TIDExpression; inline;
    function RPNLastOperator: TOperatorID;
    function RPNPopExpression: TIDExpression;
    property RPNExprCount: Integer read fRPNExprCount;
    property RPNLastOp: TOperatorID read fRPNLastOp;
    property Result: TIDExpression read GetExpression;
    property EPosition: TExpessionPosition read fPosition write fPosition;
    property SContext: TASTSContext<TProc> read fSContext;
    property Proc: TProc read GetProc;
  end;


implementation

uses
  OPCompiler, NPCompiler.Errors;

{ TRPN }

procedure TASTEContext<TProc>.RPNCheckInputSize;
begin
  if fRPNOpCount >= fRPNOArrayLen then begin
    Inc(fRPNOArrayLen, 8);
    SetLength(fRPNOArray, fRPNOArrayLen);
  end;
end;

procedure TASTEContext<TProc>.RPNPushExpression(Expr: TIDExpression);
begin
  fRPNEArray[fRPNExprCount] := Expr;
  Inc(fRPNExprCount);
  if fRPNExprCount >= fRPNEArrayLen then begin
    Inc(fRPNEArrayLen, 8);
    SetLength(fRPNEArray, fRPNEArrayLen);
  end;
  fRPNLastOp := opNone;
end;

procedure TASTEContext<TProc>.RPNError(Status: TRPNError);
begin
  case Status of
    reUnclosedOpenBracket: AbortWork(sUnclosedOpenBracket);
    reDublicateOperation: AbortWork(sDublicateOperationFmt);
  end;
end;

procedure TASTEContext<TProc>.RPNPushOpenRaund;
begin
  fRPNOArray[fRPNOpCount] := opOpenRound;
  Inc(fRPNOpCount);
  RPNCheckInputSize;
  fRPNLastOp := opOpenRound;
end;

procedure TASTEContext<TProc>.RPNPushCloseRaund;
var
  op: TOperatorID;
begin
  fRPNLastOp := opCloseRound;
  while fRPNOpCount > 0 do begin
    Dec(fRPNOpCount);
    op := fRPNOArray[fRPNOpCount];
    if op <> opOpenRound then begin
      fRPNEArray[fRPNExprCount] := fProcessProc(Self, Op);
      Inc(fRPNExprCount);
    end else
      Exit;
  end;
  RPNError(reUnnecessaryClosedBracket);
end;

function TASTEContext<TProc>.RPNPopOperator: TIDExpression;
var
  Op: TOperatorID;
begin
  if fRPNOpCount > 0 then
  begin
    Dec(fRPNOpCount);
    Op := fRPNOArray[fRPNOpCount];
    Result := fProcessProc(Self, op);
  end else
    Result := nil;
end;

procedure TASTEContext<TProc>.RPNFinish;
var
  op: TOperatorID;
  Expr: TIDExpression;
begin
  while fRPNOpCount > 0 do
  begin
    Dec(fRPNOpCount);
    op := fRPNOArray[fRPNOpCount];
    if op <> opOpenRound then
    begin
      Expr := fProcessProc(Self, op);
      fRPNEArray[fRPNExprCount] := Expr;
      if Assigned(Expr) then
        Inc(fRPNExprCount);

      if fRPNOpCount > 0 then
        fRPNLastOp := fRPNOArray[fRPNOpCount - 1]
      else
        fRPNLastOp := opNone;

      fRPNPrevPriority := cOperatorPriorities[fRPNLastOp];
    end else
      RPNError(reUnclosedOpenBracket);
  end;
end;

function TASTEContext<TProc>.RPNPushOperator(OpID: TOperatorID): TRPNStatus;
var
  Priority: Integer;
  Op: TOperatorID;
begin
  if OpID = fRPNLastOp then
    RPNError(reDublicateOperation);

  fRPNLastOp := OpID;
  Priority := cOperatorPriorities[OpID];

  if cOperatorTypes[OpID] <> opUnarPrefix then
  begin
    if (Priority <= fRPNPrevPriority) then
    begin
    while fRPNOpCount > 0 do begin
      Op := fRPNOArray[fRPNOpCount - 1];
      if (cOperatorPriorities[Op] >= Priority) and (Op <> opOpenRound) then
      begin
        Dec(fRPNOpCount);
        fRPNEArray[fRPNExprCount] := fProcessProc(Self, Op);
        Inc(fRPNExprCount);
      end else
        Break;
    end;
  end;
  end;

  fRPNPrevPriority := Priority;
  fRPNOArray[fRPNOpCount] := OpID;
  Inc(fRPNOpCount);
  RPNCheckInputSize;
  Result := rpOperation;
end;

function TASTEContext<TProc>.RPNReadExpression(Index: Integer): TIDExpression;
begin
  Result := fRPNEArray[Index];
end;

function TASTEContext<TProc>.RPNLastOperator: TOperatorID;
begin
  if fRPNOpCount > 0 then
    Result := fRPNOArray[fRPNOpCount - 1]
  else
    Result := TOperatorID.opNone;
end;

function TASTEContext<TProc>.RPNPopExpression: TIDExpression;
begin
  Dec(fRPNExprCount);
  if fRPNExprCount >= 0 then begin
    Result := fRPNEArray[fRPNExprCount];
    if Assigned(Result) then
      Exit;
  end;
  AbortWorkInternal('Empty Expression');
  Result := nil; // for prevent compiler warning
end;

function TASTEContext<TProc>.GetProc: TProc;
begin
  Result := fSContext.fProc;
end;

procedure TASTEContext<TProc>.Initialize(const SContext: TASTSContext<TProc>; const ProcessProc: TRPNPocessProc);
begin
  SetLength(fRPNOArray, 4);
  fRPNOArrayLen := 4;
  SetLength(fRPNEArray, 8);
  fRPNEArrayLen := 8;
  fRPNOpCount := 0;
  fRPNExprCount := 0;
  fRPNLastOp := opNone;
  fRPNPrevPriority := 0;
  fProcessProc := ProcessProc;
  fSContext := SContext;
end;

procedure TASTEContext<TProc>.RPNEraiseTopOperator;
begin
  Dec(fRPNOpCount);
end;

procedure TASTEContext<TProc>.Reset;
begin
  fRPNLastOp := opNone;
  fRPNPrevPriority := 0;
  fRPNOpCount := 0;
  fRPNExprCount := 0;
end;

function TASTEContext<TProc>.GetExpression: TIDExpression;
begin
  if fRPNExprCount > 0 then
    Result := fRPNEArray[fRPNExprCount - 1]
  else
    Result := nil;
end;

{ TASTSContext }

function TASTSContext<TProc>.Add<T>: T;
begin
  Result := T.Create(Block);
  Block.AddChild(Result);
end;

procedure TASTSContext<TProc>.AddItem(const Item: TASTItem);
begin
  fBlock.AddChild(Item)
end;

constructor TASTSContext<TProc>.Create(const Module: TASTModule; Proc: TProc; Block: TASTBlock);
begin
  fModule := Module;
  fProc := Proc;
  fBlock := Block;
end;

constructor TASTSContext<TProc>.Create(const Module: TASTModule);
begin
  fModule := Module;
  fProc := default(TProc);
  fBlock := nil;
end;

function TASTSContext<TProc>.MakeChild(Block: TASTBlock): TASTSContext<TProc>;
begin
  Result := TASTSContext<TProc>.Create(fModule, fProc, Block);
end;

end.
