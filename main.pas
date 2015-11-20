unit main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, RegExpr, StdCtrls;


type
  TFunction = record
    name: ansistring;
    text: ansistring;
    cyclomaticComplexity: integer;
    MyersCyclomaticComplexity: integer;
  end;
  TArrFunction = array of TFunction;
  TFMain = class(TForm)
    BtnOpenFile: TButton;
    Start: TMemo;
    Result: TMemo;
    ChooseFile: TOpenDialog;
    LCode: TLabel;
    LResult: TLabel;
    BtnGetResult: TButton;
    procedure BtnOpenFileClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure BtnGetResultClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FMain: TFMain;
  input: ansistring;
  functions: TArrFunction;
  countFunctions: integer;
implementation

{$R *.dfm}

function isCorrect(var input: ansistring): boolean;
var
   counterBrakes, counterParenthesis,index: integer;
begin
   counterBrakes := 0;
   counterParenthesis := 0;

   for index := 1 to length(input) do
      case input[index] of
         '(': inc(counterParenthesis);
         ')': dec(counterParenthesis);
         '{': inc(counterBrakes);
         '}': dec(counterBrakes);
      end;

   if (counterParenthesis = 0) and (counterBrakes = 0) then
      result := true
   else
      result := false;
end;



procedure readFromFile(filename: ansistring; var input: ansistring);
var
   tempString : ansistring;
   inputFile: TextFile;
begin
   input := '';
   AssignFile(inputFile,filename);
   if FileExists (filename) then
      Reset(inputFile)
   else
   begin
      Rewrite (inputFile);
      closeFile (inputFile);
      Reset(inputFile);
   end;
   while not EoF(inputFile) do
   begin
      readln (inputFile,tempString);
      input:= input +#13#10+ tempString;
   end;
   closeFile (inputFile);
   FMain.Start.Text := input;
   FMain.Start.Visible := true;
end;



procedure deleteText(var input: ansistring);
var
   regularText: TRegExpr;
begin
   regularText := TRegExpr.Create;
   regularText.InputString := input;
   try
      regularText.Expression := '\''.*?\''|\".*?\"';
      input := regularText.Replace(input,'',false);
   finally
      regularText.Free;
   end;
   FMain.Result.Text := input;
end;



procedure deleteComments(var input: ansistring);
var
   regularComment: TRegExpr;
begin
   regularComment := TRegExpr.Create;
   regularComment.InputString := input;
   try
      regularComment.Expression := '\/\*.*?\*\/|\/{2,}.*?[\r][\n]';
      input := regularComment.Replace(input,'',false);
   finally
      regularComment.Free;
   end;
end;



function setCyclomaticComplexity(var input: ansistring): integer;
var
   cyclComplexity: integer;
   regularPredicates: TRegExpr;
begin
   cyclComplexity := 1;

   regularPredicates := TRegExpr.Create;
   regularPredicates.InputString := input;
   try
      regularPredicates.Expression := '([\s \} \)](if|case|foreach|while|for|elseif)[\s \{ \(])|\?';
      if (regularPredicates.Exec) then
         repeat
            inc(cyclComplexity);
         until not (regularPredicates.ExecNext);
   finally
      regularPredicates.Free;
   end;

   result := cyclComplexity;
end;



function findTextBetweenBrakes(var input: ansistring; var positionFirst: integer): ansistring;
var
   positionLast,countSeparator: integer;
   tempString: ansistring;
begin
   countSeparator := 0; //счетчик "незакрытых" открывающих фигурных скобок
   positionLast := positionFirst;
   while input[positionLast]<> '}' do
   begin
      if input[positionLast] ='{' then
         inc(countSeparator);
      if (input[positionLast+1] = '}') and (countSeparator <> 1) then
      begin
         inc(positionLast);
         Dec(countSeparator);
      end;
      inc(positionLast);
   end;
   tempString := copy(input,positionFirst,positionLast-positionFirst+1);
   result := tempString;
end;



procedure fillFunctions(var input: ansistring; var functions: TArrFunction;
                        var countFunctions: integer);
var
   positionFirst: integer;
   regularFunction: TRegExpr;
begin
   regularFunction := TRegExpr.Create;
   regularFunction.InputString := input;
   try
      regularFunction.Expression := '(int|char|void|float|double) \**?([a-zA-Z_]*) ?\([\w \*,\[\]]*\)\s*\{';
      if (regularFunction.Exec) then
      begin
         repeat
         begin
            inc(countFunctions);
            SetLength(functions, countFunctions);
            functions[countFunctions-1].name := regularFunction.Match[2] + ' ';
            positionFirst := Pos(regularFunction.Match[0],input)+length(regularFunction.Match[0])-1; //позиция открывающей фигурной скобки
            functions[countFunctions-1].text := findTextBetweenBrakes(input,positionFirst);
            input := StringReplace(input, functions[countFunctions-1].text, '', []);
         end;
         until not (regularFunction.ExecNext);
      end;
   finally
      regularFunction.Free;
   end;
end;



function findTextBetweenParenthesis(var input: ansistring; var positionFirst: integer): ansistring;
var
   positionLast,countSeparator,index,helpVariable: integer;
   tempString: ansistring;
begin
   tempString := '';
   //helpVariable := positionFirst;
   countSeparator := 0; //счетчик "незакрытых" открывающих  скобок
   //positionFirst := pos('(',input);
   positionLast := positionFirst;
   while input[positionLast]<> ')' do
   begin
      if input[positionLast] ='(' then
         inc(countSeparator);
      if (input[positionLast+1] = ')') and (countSeparator <> 1) then
      begin
         inc(positionLast);
         Dec(countSeparator);
      end;
      inc(positionLast);
   end;
   tempString := copy(input,positionFirst,positionLast-positionFirst+1);
   //delete(input,positionFirst,positionLast-positionFirst+1);
  // for index := helpVariable  to positionLast-helpVariable+1 do
    //  input[index] := 'a';
   result := tempString;
end;



function setMyersCCForOneCase(var input: ansistring): integer;
var
   MyersCC: integer;
   regPredicate: TRegExpr;
begin
   MyersCC := 1;
   regPredicate := TRegExpr.Create;
   regPredicate.InputString := input;
   try
      regPredicate.Expression := '[\s|\)](&&|\|\|)[\s\(]';
      if (regPredicate.Exec) then
         repeat
            inc(MyersCC)
         until not (regPredicate.ExecNext)
   finally
      regPredicate.Free;
   end;

   result := MyersCC;
end;



function setMyersCC(var input: ansistring): integer;
var
   MyersCComplexity, positionFirst: integer;
   tempString: ansistring;
   regularIfWhileFor, regularCaseQuestion: TRegExpr;
begin
   MyersCComplexity := 1;

   regularCaseQuestion := TRegExpr.Create;
   regularCaseQuestion.InputString := input;
   try
      regularCaseQuestion.Expression := '(case[\s \{ \(]|\?)';
      if (regularCaseQuestion.Exec) then
         repeat
            inc(MyersCComplexity);
         until not (regularCaseQuestion.ExecNext);
   finally
      regularCaseQuestion.Free;
   end;

   regularIfWhileFor := TRegExpr.Create;
   regularIfWhileFor.InputString := input;
   try
      regularIfWhileFor.Expression := '(elseif|foreach|while|for|if)[\s\{\(]';
      if regularIfWhileFor.Exec then
         repeat

         begin
            positionFirst := regularIfWhileFor.MatchPos[0];
            tempString := findTextBetweenParenthesis(input,positionFirst);
            inc(MyersCComplexity,setMyersCCForOneCase(tempString));
         end;
         until not (regularIfWhileFor.ExecNext);
   finally
      regularIfWhileFor.Free;
   end;

   result := MyersCComplexity;
end;



procedure getResult(var input: ansistring);
var
   cyclComplexity, index, MyersCyclComplexity: integer;
begin
   deleteText(input);
   deleteComments(input);
   fillFunctions(input,functions,countFunctions);

   cyclComplexity := 1;
   cyclComplexity := setCyclomaticComplexity(input);
   FMain.Result.Text := 'Цикломатическое число Маккейба: ' + inttostr(cyclComplexity);
   MyersCyclComplexity := setMyersCC(input);
   FMain.Result.Lines.Add('Цикломатическое число Майерса: (' + inttostr(cyclComplexity) +
                           ','+intToStr(MyersCyclComplexity)+')') ;

   for index := 0 to countFunctions-1 do
   begin
      FMain.Result.Lines.Add(functions[index].name + ':');
      functions[index].cyclomaticComplexity := setCyclomaticComplexity(functions[index].text);
      FMain.Result.Lines.Add('     Маккейб: ' + intToStr(functions[index].cyclomaticComplexity)) ;
      functions[index].MyersCyclomaticComplexity := setMyersCC(functions[index].text);
      FMain.Result.Lines.Add('     Майерс: (' + inttostr(functions[index].cyclomaticComplexity) +
                           ','+intToStr(functions[index].MyersCyclomaticComplexity)+')') ;
   end;
end;



procedure TFMain.BtnOpenFileClick(Sender: TObject);
begin
   Fmain.Start.Visible := false;
   Fmain.result.Visible := false;
   FMain.LCode.Visible := false;
   FMain.LResult.Visible := false;
   FMain.Start.Clear;
   FMain.result.Clear;

   if ChooseFile.Execute then
   begin
      readFromFile(ChooseFile.FileName,input);
      FMain.BtnGetResult.Enabled := true;
   end;

   Fmain.Start.Visible := true;
   FMain.LCode.Visible := true;
end;



procedure TFMain.FormCreate(Sender: TObject);
begin
   Fmain.Start.Visible := false;
   Fmain.Result.Visible := false;
end;

procedure TFMain.BtnGetResultClick(Sender: TObject);
var
   index: integer;
begin
   input := FMain.Start.Text;

   FMain.Result.Clear;
   for index := 0 to countFunctions-1 do
   begin
      functions[index].name := '';
      functions[index].text := '';
      functions[index].cyclomaticComplexity := 0;
      functions[index].MyersCyclomaticComplexity := 0;
   end;
   countfunctions := 0;

   if (input = '')  then
      FMain.Result.Text := 'Исходный файл пуст!'
   else
   begin
      deleteText(input);
      deleteComments(input);
      if not(isCorrect(input)) then
         FMain.Result.Text := 'Исходный файл содержит неравное количество открывающих '+ #13#10+'и закрывающих скобок!'
      else
         getResult(input);
   end;
   FMain.LResult.Visible := true;
   FMain.Result.Visible := true;
end;

end.
