unit NPCompiler.ConstCalculator;

interface

uses System.SysUtils, NPCompiler.Classes, NPCompiler.Operators;

function ProcessConstOperation(Left, Right: TIDExpression; Operation: TOperatorID): TIDExpression; overload;
function ProcessConstOperation(const Left, Right: TIDConstant; Operation: TOperatorID): TIDConstant; overload;

implementation

uses SystemUnit, OPCompiler, NPCompiler.DataTypes, NPCompiler.Utils;

function ProcessConstOperation(const Left, Right: TIDConstant; Operation: TOperatorID): TIDConstant; overload;
  //////////////////////////////////////////////////////////////
  function CalcInteger(LValue, RValue: Int64; Operation: TOperatorID): TIDConstant;
  var
    iValue: Int64;
    fValue: Double;
    bValue: Boolean;
    DT: TIDType;
  begin
    case Operation of
      opAdd: iValue := LValue + RValue;
      opSubtract: iValue := LValue - RValue;
      opMultiply: iValue := LValue * RValue;
      opNegative: iValue := -RValue;
      opIntDiv, opDivide: begin
        if RValue = 0 then
          TNPUnit.ERROR_DIVISION_BY_ZERO(SYSUnit._EmptyStrExpression);
        if Operation = opIntDiv then
          iValue := LValue div RValue
        else begin
         fValue := LValue / RValue;
         Exit(TIDFloatConstant.CreateAnonymous(Left.Scope, SYSUnit._Float64, fValue));
        end;
      end;
      opEqual,
      opNotEqual,
      opGreater,
      opGreaterOrEqual,
      opLess,
      opLessOrEqual: begin
        case Operation of
          opEqual: bValue := (LValue = RValue);
          opNotEqual: bValue := (LValue <> RValue);
          opGreater: bValue := (LValue > RValue);
          opGreaterOrEqual: bValue := (LValue >= RValue);
          opLess: bValue := (LValue < RValue);
          opLessOrEqual: bValue := (LValue <= RValue);
          else bValue := False;
        end;
        Exit(TIDBooleanConstant.CreateAnonymous(Left.Scope, SYSUnit._Boolean, bValue));
      end;
      opAnd: iValue := LValue and RValue;
      opOr: iValue := LValue or RValue;
      opXor: iValue := LValue xor RValue;
      opNot: iValue := not RValue;
      opShiftLeft: iValue := LValue shl RValue;
      opShiftRight: iValue := LValue shr RValue;
      else Exit(nil);
    end;
    DT := SYSUnit.DataTypes[GetValueDataType(iValue)];
    Result := TIDIntConstant.CreateAnonymous(Left.Scope, DT, iValue);
  end;
  //////////////////////////////////////////////////////////////
  function CalcFloat(LValue, RValue: Double; Operation: TOperatorID): TIDConstant;
  var
    fValue: Double;
    bValue: Boolean;
    ValueDT: TIDType;
  begin
    ValueDT := SYSUnit._Float64;
    case Operation of
      opAdd: fValue := LValue + RValue;
      opSubtract: fValue := LValue - RValue;
      opMultiply: fValue := LValue * RValue;
      opDivide: begin
        if RValue = 0 then
          TNPUnit.ERROR_DIVISION_BY_ZERO(SYSUnit._EmptyStrExpression);
        fValue := LValue / RValue;
      end;
      opNegative: begin
        fValue := -RValue;
        ValueDT := Right.DataType;
      end;
      opEqual,
      opNotEqual,
      opGreater,
      opGreaterOrEqual,
      opLess,
      opLessOrEqual: begin
        case Operation of
          opEqual: bValue := LValue = RValue;
          opNotEqual: bValue := LValue <> RValue;
          opGreater: bValue := LValue > RValue;
          opGreaterOrEqual: bValue := LValue >= RValue;
          opLess: bValue := LValue < RValue;
          opLessOrEqual: bValue := LValue <= RValue;
        else
          bValue := False;
        end;
        Exit(TIDBooleanConstant.CreateAnonymous(Left.Scope, SYSUnit._Boolean, bValue));
      end;
    else
      Exit(nil);
    end;
    Result := TIDFloatConstant.CreateAnonymous(nil, ValueDT, fValue);
    Result.ExplicitDataType := ValueDT;
  end;
  //////////////////////////////////////////////////////////////
  function CalcBoolean(LValue, RValue: Boolean; Operation: TOperatorID): TIDConstant;
  var
    Value: Boolean;
  begin
    case Operation of
      opAnd: Value := LValue and RValue;
      opOr: Value := LValue or RValue;
      opXor: Value := LValue xor RValue;
      opNot: Value := not RValue;
      else Exit(nil);
    end;
    Result := TIDBooleanConstant.Create(Left.Scope, Identifier(BoolToStr(Value, True)), SYSUnit._Boolean, Value);
  end;
  //////////////////////////////////////////////////////////////
  function CalcString(const LValue, RValue: string): TIDConstant;
  var
    sValue: string;
    bValue: Boolean;
  begin
    case Operation of
      opAdd: begin
        sValue := LValue + RValue;
        Result := TIDStringConstant.CreateAnonymous(Left.Scope, SYSUnit._String, sValue);
      end;
      opEqual,
      opNotEqual: begin
        case Operation of
          opEqual: bValue := LValue = RValue;
          opNotEqual: bValue := LValue <> RValue;
          else bValue := False;
        end;
        Exit(TIDBooleanConstant.CreateAnonymous(Left.Scope, SYSUnit._Boolean, bValue));
      end;
      else Exit(nil);
    end;
  end;
  ///////////////////////////////////////////////////////////////
  function CalcIn(const Left: TIDConstant; const Right: TIDRangeConstant): TIDConstant;
  var
    LB, HB: TIDConstant;
    bValue: Boolean;
  begin
    LB := TIDConstant(Right.Value.LBExpression.Declaration);
    HB := TIDConstant(Right.Value.HBExpression.Declaration);
    bValue := (Left.CompareTo(LB) >= 0) and (Left.CompareTo(HB) <= 0);
    Result := TIDBooleanConstant.CreateAnonymous(Left.Scope, SYSUnit._Boolean, bValue);
  end;
var
  LeftType, RightType: TClass;
  Constant: TIDConstant;
begin
  LeftType := Left.ClassType;
  RightType := Right.ClassType;

  Constant := nil;
  if RightType = TIDRangeConstant then
  begin
    Constant := CalcIn(Left, TIDRangeConstant(Right));
  end else
  if LeftType = TIDIntConstant then
  begin
    if RightType = TIDIntConstant then
      Constant := CalcInteger(TIDIntConstant(Left).Value, TIDIntConstant(Right).Value, Operation)
    else
      Constant := CalcFloat(TIDIntConstant(Left).Value, TIDFloatConstant(Right).Value, Operation)
  end else
  if LeftType = TIDFloatConstant then
  begin
    if RightType = TIDIntConstant then
      Constant := CalcFloat(TIDFloatConstant(Left).Value, TIDIntConstant(Right).Value, Operation)
    else
      Constant := CalcFloat(TIDFloatConstant(Left).Value, TIDFloatConstant(Right).Value, Operation)
  end else
  if LeftType = TIDStringConstant then begin
    if RightType = TIDStringConstant then
      Constant := CalcString(TIDStringConstant(Left).Value, TIDStringConstant(Right).Value)
    else
      Constant := CalcString(TIDStringConstant(Left).Value, TIDCharConstant(Right).Value)
  end else
  if LeftType = TIDCharConstant then begin
    if RightType = TIDCharConstant then
      Constant := CalcString(TIDCharConstant(Left).Value, TIDCharConstant(Right).Value)
    else
      Constant := CalcString(TIDCharConstant(Left).Value, TIDStringConstant(Right).Value)
  end else
  if LeftType = TIDBooleanConstant then
    Constant := CalcBoolean(TIDBooleanConstant(Left).Value, TIDBooleanConstant(Right).Value, Operation)
  else
    AbortWorkInternal('Invalid parameters', Left.SourcePosition);

  if not Assigned(Constant) then
    AbortWork('Operation %s not supported for constants', [OperatorFullName(Operation)], Left.SourcePosition);

  Result := Constant;
end;

function ProcessConstOperation(Left, Right: TIDExpression; Operation: TOperatorID): TIDExpression;
  //////////////////////////////////////////////////////////////
  function CalcInteger(LValue, RValue: Int64; Operation: TOperatorID): TIDConstant;
  var
    iValue: Int64;
    fValue: Double;
    bValue: Boolean;
    DT: TIDType;
  begin
    case Operation of
      opAdd: iValue := LValue + RValue;
      opSubtract: iValue := LValue - RValue;
      opMultiply: iValue := LValue * RValue;
      opNegative: iValue := -RValue;
      opIntDiv, opDivide: begin
        if RValue = 0 then
          TNPUnit.ERROR_DIVISION_BY_ZERO(Right);
        if Operation = opIntDiv then
          iValue := LValue div RValue
        else begin
         fValue := LValue / RValue;
         Exit(TIDFloatConstant.CreateAnonymous(nil, SYSUnit._Float64, fValue));
        end;
      end;
      opEqual,
      opNotEqual,
      opGreater,
      opGreaterOrEqual,
      opLess,
      opLessOrEqual: begin
        case Operation of
          opEqual: bValue := (LValue = RValue);
          opNotEqual: bValue := (LValue <> RValue);
          opGreater: bValue := (LValue > RValue);
          opGreaterOrEqual: bValue := (LValue >= RValue);
          opLess: bValue := (LValue < RValue);
          opLessOrEqual: bValue := (LValue <= RValue);
          else bValue := False;
        end;
        Exit(TIDBooleanConstant.CreateAnonymous(nil, SYSUnit._Boolean, bValue));
      end;
      opAnd: iValue := LValue and RValue;
      opOr: iValue := LValue or RValue;
      opXor: iValue := LValue xor RValue;
      opNot: iValue := not RValue;
      opShiftLeft: iValue := LValue shl RValue;
      opShiftRight: iValue := LValue shr RValue;
      else Exit(nil);
    end;
    DT := SYSUnit.DataTypes[GetValueDataType(iValue)];
    Result := TIDIntConstant.CreateAnonymous(nil, DT, iValue);
  end;
  //////////////////////////////////////////////////////////////
  function CalcFloat(LValue, RValue: Double; Operation: TOperatorID): TIDConstant;
  var
    fValue: Double;
    bValue: Boolean;
    ValueDT: TIDType;
  begin
    ValueDT := SYSUnit._Float64;
    case Operation of
      opAdd: fValue := LValue + RValue;
      opSubtract: fValue := LValue - RValue;
      opMultiply: fValue := LValue * RValue;
      opDivide: begin
        if RValue = 0 then
          TNPUnit.ERROR_DIVISION_BY_ZERO(Right);
        fValue := LValue / RValue;
      end;
      opNegative: begin
        fValue := -RValue;
        ValueDT := Right.DataType;
      end;
      opEqual,
      opNotEqual,
      opGreater,
      opGreaterOrEqual,
      opLess,
      opLessOrEqual: begin
        case Operation of
          opEqual: bValue := LValue = RValue;
          opNotEqual: bValue := LValue <> RValue;
          opGreater: bValue := LValue > RValue;
          opGreaterOrEqual: bValue := LValue >= RValue;
          opLess: bValue := LValue < RValue;
          opLessOrEqual: bValue := LValue <= RValue;
        else
          bValue := False;
        end;
        Exit(TIDBooleanConstant.CreateAnonymous(nil, SYSUnit._Boolean, bValue));
      end;
    else
      Exit(nil);
    end;
    Result := TIDFloatConstant.CreateAnonymous(nil, ValueDT, fValue);
  end;
  //////////////////////////////////////////////////////////////
  function CalcBoolean(LValue, RValue: Boolean; Operation: TOperatorID): TIDConstant;
  var
    Value: Boolean;
  begin
    case Operation of
      opAnd: Value := LValue and RValue;
      opOr: Value := LValue or RValue;
      opXor: Value := LValue xor RValue;
      opNot: Value := not RValue;
      else Exit(nil);
    end;
    Result := TIDBooleanConstant.Create(nil, Identifier(BoolToStr(Value, True)), SYSUnit._Boolean, Value);
  end;
  //////////////////////////////////////////////////////////////
  function CalcString(const LValue, RValue: string): TIDConstant;
  var
    sValue: string;
    bValue: Boolean;
  begin
    case Operation of
      opAdd: begin
        sValue := LValue + RValue;
        Result := TIDStringConstant.CreateAnonymous(nil, SYSUnit._String, sValue);
      end;
      opEqual,
      opNotEqual: begin
        case Operation of
          opEqual: bValue := LValue = RValue;
          opNotEqual: bValue := LValue <> RValue;
          else bValue := False;
        end;
        Exit(TIDBooleanConstant.CreateAnonymous(nil, SYSUnit._Boolean, bValue));
      end;
      else Exit(nil);
    end;
  end;
  ///////////////////////////////////////////////////////////////
  function CalcIn(const Left: TIDConstant; const Right: TIDRangeConstant): TIDConstant;
  var
    LB, HB: TIDConstant;
    bValue: Boolean;
  begin
    LB := TIDConstant(Right.Value.LBExpression.Declaration);
    HB := TIDConstant(Right.Value.HBExpression.Declaration);
    bValue := (Left.CompareTo(LB) >= 0) and (Left.CompareTo(HB) <= 0);
    Result := TIDBooleanConstant.CreateAnonymous(nil, SYSUnit._Boolean, bValue);
  end;
var
  L, R: TIDConstant;
  LeftType, RightType: TClass;
  Constant: TIDConstant;
begin
  L := TIDConstant(Left.Declaration);
  R := TIDConstant(Right.Declaration);
  LeftType := L.ClassType;
  RightType := R.ClassType;

  Constant := nil;
  if RightType = TIDRangeConstant then
  begin
    Constant := CalcIn(L, TIDRangeConstant(R));
  end else
  if LeftType = TIDIntConstant then
  begin
    if RightType = TIDIntConstant then
      Constant := CalcInteger(TIDIntConstant(L).Value, TIDIntConstant(R).Value, Operation)
    else
      Constant := CalcFloat(TIDIntConstant(L).Value, TIDFloatConstant(R).Value, Operation)
  end else
  if LeftType = TIDFloatConstant then
  begin
    if RightType = TIDIntConstant then
      Constant := CalcFloat(TIDFloatConstant(L).Value, TIDIntConstant(R).Value, Operation)
    else
      Constant := CalcFloat(TIDFloatConstant(L).Value, TIDFloatConstant(R).Value, Operation)
  end else
  if LeftType = TIDStringConstant then begin
    if RightType = TIDStringConstant then
      Constant := CalcString(TIDStringConstant(L).Value, TIDStringConstant(R).Value)
    else
      Constant := CalcString(TIDStringConstant(L).Value, TIDCharConstant(R).Value)
  end else
  if LeftType = TIDCharConstant then begin
    if RightType = TIDCharConstant then
      Constant := CalcString(TIDCharConstant(L).Value, TIDCharConstant(R).Value)
    else
      Constant := CalcString(TIDCharConstant(L).Value, TIDStringConstant(R).Value)
  end else
  if LeftType = TIDBooleanConstant then
    Constant := CalcBoolean(TIDBooleanConstant(L).Value, TIDBooleanConstant(R).Value, Operation)
  else
    AbortWorkInternal('Invalid parameters', L.SourcePosition);

  if not Assigned(Constant) then
    AbortWork('Operation %s not supported for constants', [OperatorFullName(Operation)], L.SourcePosition);
  Result := TIDExpression.Create(Constant, Right.TextPosition);

end;

end.
