{
       *****************************************
       *   b2fh v1.0 | github.com/arctic-sun   *
       *                                       *
       *****************************************
}
program b2fh;

{$APPTYPE CONSOLE}

uses
  b2fhUnt,
  JPL.CmdLineParser,  // src home: https://github.com/jackdp/JPLib/blob/master/Base/JPL.CmdLineParser.pas
  System.SysUtils,
  System.StrUtils,
  System.IOUtils,
  Winapi.Windows;

{$SetPEFlags IMAGE_FILE_RELOCS_STRIPPED}



const
   const_format_pascal = 0;
   const_format_cpp    = 1;
   const_format_php    = 2;


   constname_outextension     = 'outextension=';
   constname_arrayname        = 'arrayname=';
   constname_bytesinrow       = 'bytesinrow=';
   constname_outformat        = 'outformat=';
   constname_outfileinfo      = 'outfileinfo=';
   constname_silent           = 'silent=';
   constname_value_terminator = ';';

   const_def_bytesinrow       = 16;
   const_def_outfileinfo      = 2;
   const_def_cfgfileext       = '.cfg';
   const_def_arrayname        = 'BuffData';
   const_def_format           = -1;
   const_def_silent           = 0; // 0 - off, 1 - on

   const_defval_outextension  = '.inc';



var
   hStdOut                    : THandle;
   lpConsoleScreenBufferInfo  : TConsoleScreenBufferInfo ;
   CmdLineParser              : TJPCmdLineParser;

   v_fn_set_def_format : SmallInt;
   v_set_f_format      : SmallInt;
   v_set_out_file_ext  : string;
   v_set_in_file       : string;
   v_set_out_file      : string;
   v_set_arr_name      : string;
   v_set_bts_row       : Byte;
   v_set_h_file_info   : SmallInt;
   v_set_s_silent      : Byte;




function CanAccessFile(const FileName: TFileName): Integer;
const
  FA_READONLY_UNACCESSIBLE    =4; // File exists, read-only attribute, can not be changed
  FA_READONLY_NOT_IN_USE      =3; // File exists, read-only attribute, can be writen
  FA_READONLY_IN_USE          =5; // File exists, read-only attribute, can not be writen
  FA_NOT_IN_USE               =1; // File exists, can be written
  FA_IN_USE                   =6; // File exists, can not be writen
  FA_DIRECTORY_ACCESSIBLE     =2; // File not exists, can be created
  FA_DIRECTORY_UNACCESSIBLE   =7; // File not exists, and can not be created

    function IsFileInUse(const FName: string): Boolean;
    var
      HFileRes: HFILE;
    begin
      Result := False;
      if not FileExists(FName) then
        Exit;
      HFileRes := CreateFile(PChar(FName), GENERIC_READ or GENERIC_WRITE, 0,
        nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
      Result := (HFileRes = INVALID_HANDLE_VALUE);
      if not Result then
        CloseHandle(HFileRes);
    end;

var
  H: THandle; Attrs, Attrs2 : TFileAttributes;
begin
  result := -1;

  if FileExists(FileName) then
  begin
      Attrs := TFile.GetAttributes( FileName );
      if TFileAttribute.faReadOnly in Attrs then
      begin
        TFile.SetAttributes(FileName, [TFileAttribute.faNormal] );

        Attrs2 := TFile.GetAttributes( FileName );
        if TFileAttribute.faReadOnly in Attrs2 then Exit(FA_READONLY_UNACCESSIBLE);

        if not IsFileInUse(FileName)
        then result := FA_READONLY_NOT_IN_USE
        else result := FA_READONLY_IN_USE ;

        TFile.SetAttributes(FileName, Attrs);
      end
      else
        if not IsFileInUse(FileName)
        then result := FA_NOT_IN_USE
        else result := FA_IN_USE ;
  end
  else
  begin
     H := CreateFile(PChar(FileName), GENERIC_READ or GENERIC_WRITE, 0, nil,
                    CREATE_NEW, FILE_ATTRIBUTE_TEMPORARY or FILE_FLAG_DELETE_ON_CLOSE, 0);
                    if H <> INVALID_HANDLE_VALUE then
                    begin
                      CloseHandle(H);
                      result := FA_DIRECTORY_ACCESSIBLE;
                    end
                    else result := FA_DIRECTORY_UNACCESSIBLE;
  end;
end;

procedure RegisterOptions;
begin

  CmdLineParser.UsageFormat := cufWget;

  // in
  CmdLineParser.RegisterOption('i', 'i', cvtRequired, False, False, 'Input file (value required).', '', '');

  // out
  CmdLineParser.RegisterOption('o', 'o', cvtOptional, False, False, 'Output file (value optional).', '', '');

  //format:  pascal  cpp  php
  CmdLineParser.RegisterOption('f', 'f', cvtOptional, False, False, 'Format (value optional).', '', '');

  // array name
  CmdLineParser.RegisterOption('a', 'a', cvtOptional, False, False, 'Array name (value optional).', '', '');

  // bytes in row
  CmdLineParser.RegisterOption('r', 'r', cvtOptional, False, False, 'Bytes in row (value optional).', '', '');

  // file info
  CmdLineParser.RegisterOption('h', 'h', cvtOptional, False, False, 'Hash File info (value optional).', '', '');

end;

function ProcessOptions: Boolean;
begin
   result := True;

   if CmdLineParser.IsOptionExists('i') then
    v_set_in_file := CmdLineParser.GetOptionValue('i') else result:= False;

   if CmdLineParser.IsOptionExists('o') then
    v_set_out_file := CmdLineParser.GetOptionValue('o');


   if CmdLineParser.IsOptionExists('f') then
   begin
      var tmp_f_str: string;
      tmp_f_str := LowerCase( Trim(CmdLineParser.GetOptionValue('f')) );

       case IndexText(  tmp_f_str, ['pascal','0', 'cpp','1', 'php','2']) of
               0,1: v_set_f_format :=  const_format_pascal ;
               2,3: v_set_f_format :=  const_format_cpp ;
               4,5: v_set_f_format :=  const_format_php ;
       else
          v_set_f_format := -1;
       end;
   end;

   if CmdLineParser.IsOptionExists('a') then
    v_set_arr_name := CmdLineParser.GetOptionValue('a');

   if CmdLineParser.IsOptionExists('r') then
    v_set_bts_row := StrToIntDef( CmdLineParser.GetOptionValue('r'), const_def_bytesinrow );

   // if param not exists then v_set_h_file_info := -1
   if CmdLineParser.IsOptionExists('h') then
   begin
     v_set_h_file_info := StrToIntDef( CmdLineParser.GetOptionValue('h'), const_def_outfileinfo);

     if (v_set_h_file_info > 10) then
             v_set_h_file_info := const_def_outfileinfo;

     if (v_set_h_file_info < 0)  then
             v_set_h_file_info := const_def_outfileinfo;
   end;

end;

procedure ReadCfgFile;

      function ExtractBetween(const Value, A, B: string): string;
      var aPos, bPos: Integer;
      begin
        result := '';
        aPos := Pos(A, Value);
        if not aPos > 0 then Exit;
          aPos := aPos + Length(A);
          bPos := Pos(B, Value, aPos);
          if bPos > 0 then
            result := Copy(Value, aPos, bPos - aPos);
      end;

var
    cfgFile, tmpStr, tmpStr2: string;
    StringDynArray: TArray<string>;
    I: Integer;
begin
   cfgFile := ChangeFileExt( ParamStr(0), const_def_cfgfileext);

   if not FileExists(cfgFile) then Exit;
   StringDynArray := System.IOUtils.TFile.ReadAllLines( cfgFile );

   for I := 0 to High(StringDynArray) do
   if Pos(';', StringDynArray[i]) > 1 then
   begin
     tmpStr :=  Trim(StringDynArray[i]);
     tmpStr2 := Copy(tmpStr, 1, Pos('=', tmpStr) );

     Case IndexText(tmpStr2, [constname_outextension, constname_arrayname, constname_bytesinrow, constname_outformat, constname_outfileinfo, constname_silent]) of

      0: v_set_out_file_ext := ExtractBetween(tmpStr, constname_outextension, constname_value_terminator);
      1: v_set_arr_name := ExtractBetween(tmpStr, constname_arrayname, constname_value_terminator);
      2: v_set_bts_row := StrToIntDef( ExtractBetween(tmpStr, constname_bytesinrow, constname_value_terminator), const_def_bytesinrow);
      3: case IndexText(  ExtractBetween(tmpStr, constname_outformat, constname_value_terminator), ['pascal','0', 'cpp', '1', 'php','2']) of
           0, 1 : v_set_f_format := const_format_pascal ;
           2, 3 : v_set_f_format := const_format_cpp ;
           4, 5 : v_set_f_format := const_format_php ;
         end;
      4: v_set_h_file_info := StrToIntDef( ExtractBetween(tmpStr, constname_outfileinfo, constname_value_terminator), const_def_outfileinfo);
      5: v_set_s_silent := StrToIntDef(ExtractBetween(tmpStr, constname_silent, constname_value_terminator), const_def_silent);
     end;
   end;

end;

function ProcessDropedFiles: Boolean;
var CustomCmdArray: TArray<String>;
    DataOutFormat: THexDataOutFormat;
    i, caf, errCnt: Integer;
begin
    Result := False;
    for i := 1 to ParamCount do
      if FileExists(ParamStr(i)) then
        CustomCmdArray := CustomCmdArray + [ParamStr(i)] ;

   ReadCFGFile;

   // Define the format
   if v_set_f_format = -1 then  // if cfg file does not have a format setting, we use the format setting from file_name
      case v_fn_set_def_format of
        0:  DataOutFormat := hfPascal;
        1:  DataOutFormat := hfCpp;
        2:  DataOutFormat := hfPHP;
      end
   else  // else, if the cmd has a formatting setting
      case v_set_f_format of
        0:  DataOutFormat := hfPascal;
        1:  DataOutFormat := hfCpp;
        2:  DataOutFormat := hfPHP;
      end;

   errCnt := 0;
   for I := 0 to High(CustomCmdArray) do
   begin
      v_set_in_file := CustomCmdArray[i] ;
      v_set_out_file := v_set_in_file + v_set_out_file_ext;

       if not FileExists(v_set_in_file) then
       begin
         Writeln(' Error: file: "' + v_set_out_file + '" not found.' );
         inc(errCnt);
         continue
       end;

       caf := CanAccessFile(v_set_out_file);
       case caf of
          4, 5, 6 : Writeln(' Error: file: "' + v_set_out_file + '" in use.' );
          7       : Writeln(' Error: Destination directory not available. "' );
       end;

       if (caf in [4..7]) then
       begin
         inc(errCnt);
       end
       else
       begin
          write('', ' processing: ' + v_set_in_file,'', #13);
          b2fhConvert(v_set_in_file, v_set_out_file, DataOutFormat, v_set_arr_name, v_set_bts_row, v_set_h_file_info);
          write('', ' Done:       ' + v_set_in_file,'', #13);
          Writeln('');

         //  Write(' processing: ' + v_set_in_file );
         //  b2fhConvert(v_set_in_file, v_set_out_file, DataOutFormat, v_set_arr_name, v_set_bts_row, v_set_file_info);
         // WriteLN(#9 +'-'+#9 + 'done!');
       end;

   end;
   Writeln('');
   Writeln(#9 +'Finished');
   Writeln('');
   Writeln(#9 +'Processed successfully: ' + (Length(CustomCmdArray) - errCnt).ToString + ' of ' + Length(CustomCmdArray).ToString );
   //Writeln('');

   if v_set_s_silent = 0 then
   begin
     Writeln(#13#10 + ' Press ENTER to terminate ...');
     ReadLn;
   end;

   Result := True;

end;

function ProcessConvertion : Boolean;
begin
   RegisterOptions;
   CmdLineParser.Parse;

   if not ProcessOptions then
   begin
     Result := ProcessDropedFiles;
     exit;
   end;

    // Checkin source file
    if v_set_in_file.Length > 0 then
    if not FileExists(v_set_in_file) then
    begin
      WriteLn('Error: file "' + v_set_in_file + '" not found!' );
      Result := False;
      Exit;
    end;

    // Adjust v_set_arr_name
    if v_set_arr_name.Length>0 then
    if Pos(' ', v_set_arr_name) > 0 then
    begin
      v_set_arr_name := Trim(v_set_arr_name);
      v_set_arr_name := StringReplace(v_set_arr_name,' ', '', [rfReplaceAll] );
    end;

    // if destination file not set, then we use same file name with default file extension for destination file
    if v_set_out_file.Length = 0 then
        v_set_out_file := v_set_in_file + v_set_out_file_ext;

   // Define the format
   var DataOutFormat: THexDataOutFormat;
   if v_set_f_format = -1 then // if cmd does not have a format setting, we use the format setting from file_name
      case v_fn_set_def_format of
        0:  DataOutFormat := hfPascal;
        1:  DataOutFormat := hfCpp;
        2:  DataOutFormat := hfPHP;
      end
   else  // else, if the cmd has a formatting setting
      case v_set_f_format of
        0:  DataOutFormat := hfPascal;
        1:  DataOutFormat := hfCpp;
        2:  DataOutFormat := hfPHP;
      end;

   // Adjust v_set_bts_row
   if v_set_bts_row < 1 then v_set_bts_row := 16;

   // Adjust v_set_out_file and create destination directory if needed
   if Pos('\' , v_set_out_file) > 0  then
   begin
      v_set_out_file := System.IOUtils.TPath.GetFullPath( v_set_out_file  );
      if (not DirectoryExists( ExtractFilePath(v_set_out_file) ) ) then
         ForceDirectories( ExtractFilePath(v_set_out_file) );
   end;


   // Checking access to create a target file
   var caf: integer;
   caf := CanAccessFile(v_set_out_file);
   case caf of
      4, 5, 6 : Writeln(#9 + 'Error: Destination file in use.' );
      7       : Writeln(#9 + 'Error: Destination directory not available.' );
   end;

   if caf in [4..7] then
   begin
      Result :=  False;
      Exit;
   end;

   Writeln('');
   write('', ' processing: ' + v_set_in_file,'', #13);
   b2fhConvert(v_set_in_file, v_set_out_file, DataOutFormat, v_set_arr_name, v_set_bts_row, v_set_h_file_info);
   write('', ' Done:       ' + v_set_in_file,'', #13);
   Writeln('');

  { if v_set_s_silent = 0 then
   begin
     Writeln(#9 +'Finished');
     Writeln(#13#10 + ' Press ENTER to terminate ...');
     ReadLn;
   end;   }



   //Writeln(#9 + 'Done!' );
   Result := True;
end;

procedure ShowHelp;
begin

     hStdOut := GetStdHandle(STD_OUTPUT_HANDLE);
     GetConsoleScreenBufferInfo(hStdOut, lpConsoleScreenBufferInfo);

       Writeln('B2FH v1.0 - Binary to Formated Hex convertor');
       Writeln('Source - github.com/arctic-sun');
       Writeln('');
       SetConsoleTextAttribute(hStdOut,  11);
       Writeln(' Usage: ');
       SetConsoleTextAttribute(hStdOut,  15);
       Writeln('  [-i] [-o] [-f] [-a] [-r] [-h]');
       Writeln('');

       SetConsoleTextAttribute(hStdOut,  11);
       Writeln(' Params: ');
       SetConsoleTextAttribute(hStdOut,  15);

       Writeln('  -i (*required) [input file] : source file that should be converted');
       Writeln('  -o (^optional) [out file]   : destination file, if not set then it will be same as source with *.inc extension');
       Writeln('  -f (^optional) [out format] : out format. allowed values: [pascal, cpp, php] or [0, 1, 2]. Default is "0" ');
       Writeln('  -a (^optional) [array name] : name for constant array, default is "BuffData"');
       Writeln('  -r (^optional) [row bytes]  : [1..255] number of bytes in row, default is "16"');
       Writeln('  -h (^optional) [header]     : header info [0..10]. Meaning of values: "0"-no hashing, "1"-FNV1a32,');
       Writeln('                                "2"-BobJenkins, "3"-SHA1, "4"-MD5, "5"-SHA224, "6"-SHA256, ');
       Writeln('                                "7"-SHA384, "8"-SHA512, "9"-SHA512_224, "10"-SHA512_256');

       Writeln('');
       SetConsoleTextAttribute(hStdOut,  11);
       Writeln(' Samples: ');
       SetConsoleTextAttribute(hStdOut,  6);

       Writeln('  1) b2fh.exe -i d:\test.jpg -o d:\out\test.inc -p');
       Writeln('  2) b2fh.exe -i d:\test.jpg -o d:\out\test.inc -f pascal -a PasHexBuff -r 8 -h 3');
       Writeln('  3) b2fh.exe d:\test.jpg');
       Writeln('');

       SetConsoleTextAttribute(hStdOut,  11);
       Writeln(' Note:');
       SetConsoleTextAttribute(hStdOut,  2);
       Writeln('  You can also drag and drop your file(s) onto the icon of this console application in your file manager,');
       Writeln('  and you will get the result in the same folder with *.inc extension.');
       Writeln('  By default, the conversion will be in pascal format.');
       Writeln('  If you want change settings for drag and drop operations, use <AppName>.cfg (b2fh.cfg) file.');
       Writeln('  Check more info in ReadMe.txt');
      // Writeln('  If you want change default conversion to c++ foramt then rename this app by adding to it''s end _cpp');
      // Writeln('  like this: b2fh_cpp.exe');
       SetConsoleTextAttribute(hStdOut,  lpConsoleScreenBufferInfo.wAttributes);

       Write(#13#10 + ' Press ENTER to terminate ...');
       ReadLn;


end;

{##########################################################}

begin

  try
     Winapi.Windows.SetConsoleTitle('b2fh');
     //b2fh.exe
     if (Pos('_cpp.exe', lowercase(ParamStr(0)), 1) > 0) then v_fn_set_def_format := const_format_cpp
     else
       if (Pos('_php.exe', lowercase(ParamStr(0)), 1) > 0) then v_fn_set_def_format := const_format_php
       else
          v_fn_set_def_format := const_format_pascal;


     v_set_out_file_ext := const_defval_outextension;
     v_set_bts_row      := const_def_bytesinrow;
     v_set_h_file_info  := -1;
     v_set_f_format     := -1;
     v_set_arr_name     := const_def_arrayname;
     v_set_s_silent     := const_def_silent; // off

     if ParamCount = 0 then
        ShowHelp
     else
     try
        CmdLineParser := TJPCmdLineParser.Create;
        ProcessConvertion;
     finally
        CmdLineParser.Free;
     end;

  except
    on E: Exception do
      Writeln('Exception: ', E.ClassName, ': ', E.Message);
  end;

end.