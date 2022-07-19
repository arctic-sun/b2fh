{
       *****************************************
       *   b2fh v1.0 | github.com/arctic-sun   *
       *                                       *
       *****************************************
}
unit b2fhUnt;

interface

uses
  System.IOUtils, //StrUtils,
  System.SysUtils,
  System.Classes,
  System.Hash;


const
  MAX_BUFF_SZ = 1024 * 4;
  htype: array[1..10] of string =
    ('FNV1a32','BobJenkins','SHA1','MD5','SHA224','SHA256','SHA384','SHA512','SHA512_224','SHA512_256');

type
  THexDataOutFormat = (hfPascal, hfCpp, hfPHP);

  procedure b2fhConvert(const FileIn, FileOut: string;
                  const DataOutFormat: THexDataOutFormat = hfPascal;
                  const ConstArrayName: string = 'BuffData';
                  const BytesInRow: Integer = 16;
                  const FileInfo: Integer = 0);

implementation



function FNV1a32_GetHashString(const AStream: TStream): string;
const
  BUFFERSIZE = 4 * 1024;
var
  HX: THashFNV1a32;
  LBuffer: TBytes;
  LBytesRead: Longint;
begin
  HX := THashFNV1a32.Create;
  SetLength(LBuffer, BUFFERSIZE);
  while True do
  begin
    LBytesRead := AStream.ReadData(LBuffer, BUFFERSIZE);
    if LBytesRead = 0 then
      Break;
    HX.Update(LBuffer, LBytesRead);
  end;
  Result := HX.HashAsString;
end;

function BobJenkins_GetHashString(const AStream: TStream): string;
const
  BUFFERSIZE = 4 * 1024;
var
  HX: THashBobJenkins;
  LBuffer: TBytes;
  LBytesRead: Longint;
begin
  HX := THashBobJenkins.Create;
  SetLength(LBuffer, BUFFERSIZE);
  while True do
  begin
    LBytesRead := AStream.ReadData(LBuffer, BUFFERSIZE);
    if LBytesRead = 0 then
      Break;
    HX.Update(LBuffer, LBytesRead);
  end;
  Result := HX.HashAsString;
end;

procedure b2fhConvert(const FileIn, FileOut: string;
                      const DataOutFormat: THexDataOutFormat = hfPascal;
                      const ConstArrayName: string = 'BuffData';
                      const BytesInRow: Integer = 16;
                      const FileInfo: Integer = 0);

var  FDataStream: TMemoryStream;
     hashStr, fFileOut, fDataOutBuff, fConstArrayName: string;
     fDataOutFormat: THexDataOutFormat;
      fileSz: Integer;

      function IfThen(AValue: Boolean; const ATrue: string; AFalse: string = ''): string;
      begin
        if AValue then
          Result := ATrue
        else
          Result := AFalse;
      end;


     function DataToHexStr: string;

                  function DblSize(Value: Integer): Integer;
                  begin
                    Result := Value + Value;
                  end;

        const
          THexPair : packed array[0..255] of array[1..2] of AnsiChar =
          ('00','01','02','03','04','05','06','07','08','09','0A','0B','0C','0D','0E','0F',
           '10','11','12','13','14','15','16','17','18','19','1A','1B','1C','1D','1E','1F',
           '20','21','22','23','24','25','26','27','28','29','2A','2B','2C','2D','2E','2F',
           '30','31','32','33','34','35','36','37','38','39','3A','3B','3C','3D','3E','3F',
           '40','41','42','43','44','45','46','47','48','49','4A','4B','4C','4D','4E','4F',
           '50','51','52','53','54','55','56','57','58','59','5A','5B','5C','5D','5E','5F',
           '60','61','62','63','64','65','66','67','68','69','6A','6B','6C','6D','6E','6F',
           '70','71','72','73','74','75','76','77','78','79','7A','7B','7C','7D','7E','7F',
           '80','81','82','83','84','85','86','87','88','89','8A','8B','8C','8D','8E','8F',
           '90','91','92','93','94','95','96','97','98','99','9A','9B','9C','9D','9E','9F',
           'A0','A1','A2','A3','A4','A5','A6','A7','A8','A9','AA','AB','AC','AD','AE','AF',
           'B0','B1','B2','B3','B4','B5','B6','B7','B8','B9','BA','BB','BC','BD','BE','BF',
           'C0','C1','C2','C3','C4','C5','C6','C7','C8','C9','CA','CB','CC','CD','CE','CF',
           'D0','D1','D2','D3','D4','D5','D6','D7','D8','D9','DA','DB','DC','DD','DE','DF',
           'E0','E1','E2','E3','E4','E5','E6','E7','E8','E9','EA','EB','EC','ED','EE','EF',
           'F0','F1','F2','F3','F4','F5','F6','F7','F8','F9','FA','FB','FC','FD','FE','FF');
        var
          BufferSz, LinesCount, Poz, I: Integer;
          Data: array of Byte;
          AnsiResult: AnsiString;
        begin
          if fileSz < MAX_BUFF_SZ
          then BufferSz := fileSz
          else BufferSz := MAX_BUFF_SZ;


          SetLength(Data, BufferSz);
          SetLength(AnsiResult, DblSize(Length(Data)));
          LinesCount := (fileSz div BufferSz)+1;
          Poz := 0;
          repeat
            FDataStream.Position := Poz ;
            FDataStream.ReadBuffer(Data[0], Length(Data));
            for I := 0 to BufferSz - 1 do
            begin
              AnsiResult[I shl 1 + 1] := THexPair[Data[I]][1];
              AnsiResult[I shl 1 + 2] := THexPair[Data[I]][2];
            end;
            Result := Result + string(AnsiResult);

            dec(LinesCount);
            inc(Poz, BufferSz);

             if LinesCount <= 1 then
               if fileSz - Poz < BufferSz then
               begin
                 BufferSz := fileSz - Poz;
                 SetLength(Data, BufferSz);
                 SetLength(AnsiResult, DblSize(Length(Data)));
               end;

          until Poz >= fileSz ;
        end;

     procedure ConvertBinToFormatedHexStr;
     var
        LineData: string;
        I, A: Integer;
     begin
          fDataOutBuff := DataToHexStr  ;
          if Trim(fDataOutBuff) = '' then    Exit;

          if fDataOutFormat = hfPascal then
          begin
            LineData := fDataOutBuff;
            fDataOutBuff := 'const' + sLineBreak + '  ' + fConstArrayName + ': array[0..' +
              IntToStr((Length(LineData) shr 1) - 1) + '] of Byte = (' + sLineBreak + '    ';
            I := 1;
            A := 0;
            repeat
              fDataOutBuff := fDataOutBuff + '$' + LineData[I] + LineData[I + 1];
              Inc(I, 2);
              if I <= Length(LineData) - 1 then
                fDataOutBuff := fDataOutBuff + ', ';
              Inc(A);
              if A = BytesInRow  then
              begin
                A := 0;
                fDataOutBuff := fDataOutBuff + sLineBreak + '    ';
              end;
            until I > Length(LineData) - 1;
            fDataOutBuff := fDataOutBuff + ');';
          end;

          if fDataOutFormat = hfCpp then
          begin
            LineData := fDataOutBuff;
            fDataOutBuff := 'int '+ fConstArrayName +'[' +
              IntToStr((Length(LineData) shr 1)) + '] = {' + sLineBreak + '    ';
            I := 1;
            A := 0;
            repeat
              fDataOutBuff := fDataOutBuff + '0x' + LineData[I] + LineData[I + 1];
              Inc(I, 2);
              if I <= Length(LineData) - 1 then
                fDataOutBuff := fDataOutBuff + ', ';
              Inc(A);
              if A = BytesInRow then
              begin
                A := 0;
                fDataOutBuff := fDataOutBuff + sLineBreak + '    ';
              end;
            until I > Length(LineData) - 1;
            fDataOutBuff := fDataOutBuff + '};';
          end;

          if fDataOutFormat = hfPHP then
          begin
            LineData := fDataOutBuff;
            fDataOutBuff :=  fConstArrayName +' = array(' + sLineBreak + '    ';
            //  IntToStr((Length(LineData) shr 1)) + '] = {' + sLineBreak + '    ';
            I := 1;
            A := 0;
            repeat
              fDataOutBuff := fDataOutBuff + '"0x' + LineData[I] + LineData[I + 1] + '"';
              Inc(I, 2);
              if I <= Length(LineData) - 1 then
                fDataOutBuff := fDataOutBuff + ', ';
              Inc(A);
              if A = BytesInRow then
              begin
                A := 0;
                fDataOutBuff := fDataOutBuff + sLineBreak + '    ';
              end;
            until I > Length(LineData) - 1;
            fDataOutBuff := fDataOutBuff + ');';
          end;
     end;

begin
  fConstArrayName := ConstArrayName;
  fDataOutFormat  := DataOutFormat;
  fFileOut        := FileOut;




  FDataStream := TMemoryStream.Create;
  try
    FDataStream.LoadFromFile( FileIn );
    fileSz := FDataStream.Size;
    FDataStream.Position := 0;

    if FileInfo > 0 then
    case FileInfo of
      0  : hashStr := '';
      1  : hashStr := FNV1a32_GetHashString(FDataStream);
      2  : hashStr := BobJenkins_GetHashString(FDataStream);
      3  : hashStr := THashSHA1.GetHashString(FDataStream);
      4  : hashStr := THashMD5.GetHashString(FDataStream);
      5  : hashStr := THashSHA2.GetHashString(FDataStream, SHA224);
      6  : hashStr := THashSHA2.GetHashString(FDataStream, SHA256);
      7  : hashStr := THashSHA2.GetHashString(FDataStream, SHA384);
      8  : hashStr := THashSHA2.GetHashString(FDataStream, SHA512);
      9  : hashStr := THashSHA2.GetHashString(FDataStream, SHA512_224);
      10 : hashStr := THashSHA2.GetHashString(FDataStream, SHA512_256);
    end;

    FDataStream.Position := 0;
    fDataOutBuff := '';
    ConvertBinToFormatedHexStr;
  finally
     FDataStream.Free;
  end;



  if FileInfo > -1 then
  begin
      fDataOutBuff :=
      '//' + #13#10 +
      '// *****************************************' + #13#10 +
      '//  b2fh v1.0 | github.com/arctic-sun       ' + #13#10 +
      '// *****************************************' + #13#10 +
      '// FileName: ' + ExtractFileName(FileIn)      + #13#10 +
      '// Size: '     + fileSz.ToString + ' bytes'   + #13#10 +

      IfThen( hashStr.Length>0,
              '// ' + htype[ FileInfo] + ': ' + hashStr + #13#10,
              ''
               ) +

      '//' + #13#10#13#10
      + fDataOutBuff;
  end;

  System.IOUtils.TFile.WriteAllText( fFileOut,  fDataOutBuff, TEncoding.ANSI );
  fDataOutBuff := '';


end;




end.
