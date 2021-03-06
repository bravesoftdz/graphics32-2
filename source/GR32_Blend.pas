unit GR32_Blend;

(* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is Graphics32
 *
 * The Initial Developer of the Original Code is
 * Alex A. Denisov
 *
 * Portions created by the Initial Developer are Copyright (C) 2000-2004
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *  Mattias Andersson
 *      - 2004/07/07 - MMX Blendmodes
 *      - 2004/12/10 - _MergeReg, M_MergeReg
 *
 *  Michael Hansen <dyster_tid@hotmail.com>
 *      - 2004/07/07 - Pascal Blendmodes, function setup
 *
 *  Bob Voigt
 *      - 2004/08/25 - ColorDiv
 *
 * ***** END LICENSE BLOCK ***** *)

interface

{$I GR32.inc}

uses
  GR32_Color;

var
  MMX_ACTIVE: Boolean;

procedure EMMS;

{ TBitmap32 draw mode // jb moved from GR32 }
type
  TDrawMode = (dmOpaque, dmBlend, dmCustom);
  TCombineMode = (cmBlend, cmMerge);

type
{ Function Prototypes }
  TCombineReg  = function(X, Y, W: TColor32): TColor32;
  TCombineMem  = procedure(F: TColor32; var B: TColor32; W: TColor32);
  TBlendReg    = function(F, B: TColor32): TColor32;
  TBlendMem    = procedure(F: TColor32; var B: TColor32);
  TBlendRegEx  = function(F, B, M: TColor32): TColor32;
  TBlendMemEx  = procedure(F: TColor32; var B: TColor32; M: TColor32);
  TBlendLine   = procedure(Src, Dst: PColor32; Count: Integer);
  TBlendLineEx = procedure(Src, Dst: PColor32; Count: Integer; M: TColor32);

var
{ Function Variables }
  CombineReg: TCombineReg;
  CombineMem: TCombineMem;

  BlendReg: TBlendReg;
  BlendMem: TBlendMem;

  BlendRegEx: TBlendRegEx;
  BlendMemEx: TBlendMemEx;

  BlendLine: TBlendLine;
  BlendLineEx: TBlendLineEx;

  CombMergeReg: TCombineReg;
  CombMergeMem: TCombineMem;

  MergeReg: TBlendReg;
  MergeMem: TBlendMem;

  MergeRegEx: TBlendRegEx;
  MergeMemEx: TBlendMemEx;

  MergeLine: TBlendLine;
  MergeLineEx: TBlendLineEx;

{ Access to alpha composite functions corresponding to a combine mode }
  BLEND_REG: array[TCombineMode] of TBlendReg;
  BLEND_MEM: array[TCombineMode] of TBlendMem;
  COMBINE_REG: array[TCombineMode] of TCombineReg;
  COMBINE_MEM: array[TCombineMode] of TCombineMem;
  BLEND_REG_EX: array[TCombineMode] of TBlendRegEx;
  BLEND_MEM_EX: array[TCombineMode] of TBlendMemEx;
  BLEND_LINE: array[TCombineMode] of TBlendLine;
  BLEND_LINE_EX: array[TCombineMode] of TBlendLineEx;

{ Color algebra functions }
  ColorAdd: TBlendReg;
  ColorSub: TBlendReg;
  ColorDiv: TBlendReg;
  ColorModulate: TBlendReg;
  ColorMax: TBlendReg;
  ColorMin: TBlendReg;
  ColorDifference: TBlendReg;
  ColorExclusion: TBlendReg;

{ Special LUT pointers }
  AlphaTable: Pointer;
  bias_ptr: Pointer;
  alpha_ptr: Pointer;


{ Misc stuff }
function Lighten(C: TColor32; Amount: Integer): TColor32;

implementation

uses Math, GR32_System;

{ Non-MMX versions }

const bias = $00800080;

function _CombineReg(X, Y, W: TColor32): TColor32; {$IFDEF FPC} assembler; nostackframe; {$ENDIF}
asm
  // combine RGBA channels of colors X and Y with the weight of X given in W
  // Result Z = W * X + (1 - W) * Y (all channels are combined, including alpha)
{$IFDEF TARGET_x86}
  // EAX <- X
  // EDX <- Y
  // ECX <- W

  // W = 0 or $FF?
        JCXZ    @1              // CX = 0 ?  => Result := EDX
        CMP     ECX,$FF         // CX = $FF ?  => Result := EDX
        JE      @2

        PUSH    EBX

  // P = W * X
        MOV     EBX,EAX         // EBX  <-  Xa Xr Xg Xb
        AND     EAX,$00FF00FF   // EAX  <-  00 Xr 00 Xb
        AND     EBX,$FF00FF00   // EBX  <-  Xa 00 Xg 00
        IMUL    EAX,ECX         // EAX  <-  Pr ** Pb **
        SHR     EBX,8           // EBX  <-  00 Xa 00 Xg
        IMUL    EBX,ECX         // EBX  <-  Pa ** Pg **
        ADD     EAX,bias
        AND     EAX,$FF00FF00   // EAX  <-  Pa 00 Pg 00
        SHR     EAX,8           // EAX  <-  00 Pr 00 Pb
        ADD     EBX,bias
        AND     EBX,$FF00FF00   // EBX  <-  Pa 00 Pg 00
        OR      EAX,EBX         // EAX  <-  Pa Pr Pg Pb

  // W = 1 - W; Q = W * Y
        XOR     ECX,$000000FF   // ECX  <-  1 - ECX
        MOV     EBX,EDX         // EBX  <-  Ya Yr Yg Yb
        AND     EDX,$00FF00FF   // EDX  <-  00 Yr 00 Yb
        AND     EBX,$FF00FF00   // EBX  <-  Ya 00 Yg 00
        IMUL    EDX,ECX         // EDX  <-  Qr ** Qb **
        SHR     EBX,8           // EBX  <-  00 Ya 00 Yg
        IMUL    EBX,ECX         // EBX  <-  Qa ** Qg **
        ADD     EDX,bias
        AND     EDX,$FF00FF00   // EDX  <-  Qr 00 Qb 00
        SHR     EDX,8           // EDX  <-  00 Qr ** Qb
        ADD     EBX,bias
        AND     EBX,$FF00FF00   // EBX  <-  Qa 00 Qg 00
        OR      EBX,EDX         // EBX  <-  Qa Qr Qg Qb

  // Z = P + Q (assuming no overflow at each byte)
        ADD     EAX,EBX         // EAX  <-  Za Zr Zg Zb

        POP     EBX
        RET

@1:     MOV     EAX,EDX
@2:     RET
{$ENDIF}

{$IFDEF TARGET_x64}
  // ECX <- X
  // EDX <- Y
  // R8D <- W

  // W = 0 or $FF?
        TEST    R8D,R8D
        JZ      @1              // W = 0 ?  => Result := EDX
        MOV     EAX,ECX         // EAX  <-  Xa Xr Xg Xb
        CMP     R8B,$FF         // W = $FF ?  => Result := EDX
        JE      @2

  // P = W * X
        AND     EAX,$00FF00FF   // EAX  <-  00 Xr 00 Xb
        AND     ECX,$FF00FF00   // ECX  <-  Xa 00 Xg 00
        IMUL    EAX,R8D         // EAX  <-  Pr ** Pb **
        SHR     ECX,8           // ECX  <-  00 Xa 00 Xg
        IMUL    ECX,R8D         // ECX  <-  Pa ** Pg **
        ADD     EAX,bias
        AND     EAX,$FF00FF00   // EAX  <-  Pa 00 Pg 00
        SHR     EAX,8           // EAX  <-  00 Pr 00 Pb
        ADD     ECX,bias
        AND     ECX,$FF00FF00   // ECX  <-  Pa 00 Pg 00
        OR      EAX,ECX         // EAX  <-  Pa Pr Pg Pb

  // W = 1 - W; Q = W * Y
        XOR     R8D,$000000FF   // R8D  <-  1 - R8D
        MOV     ECX,EDX         // ECX  <-  Ya Yr Yg Yb
        AND     EDX,$00FF00FF   // EDX  <-  00 Yr 00 Yb
        AND     ECX,$FF00FF00   // ECX  <-  Ya 00 Yg 00
        IMUL    EDX,R8D         // EDX  <-  Qr ** Qb **
        SHR     ECX,8           // ECX  <-  00 Ya 00 Yg
        IMUL    ECX,R8D         // ECX  <-  Qa ** Qg **
        ADD     EDX,bias
        AND     EDX,$FF00FF00   // EDX  <-  Qr 00 Qb 00
        SHR     EDX,8           // EDX  <-  00 Qr ** Qb
        ADD     ECX,bias
        AND     ECX,$FF00FF00   // ECX  <-  Qa 00 Qg 00
        OR      ECX,EDX         // ECX  <-  Qa Qr Qg Qb

  // Z = P + Q (assuming no overflow at each byte)
        ADD     EAX,ECX         // EAX  <-  Za Zr Zg Zb

        RET

@1:     MOV     EAX,EDX
@2:
{$ENDIF}
end;

procedure _CombineMem(F: TColor32; var B: TColor32; W: TColor32); {$IFDEF FPC} assembler; nostackframe; {$ENDIF}
asm
{$IFDEF TARGET_x86}
  // EAX <- F
  // [EDX] <- B
  // ECX <- W

  // Check W
        JCXZ    @1              // W = 0 ?  => write nothing
        CMP     ECX,$FF         // W = 255? => write F
        JZ      @2

        PUSH    EBX
        PUSH    ESI

  // P = W * F
        MOV     EBX,EAX         // EBX  <-  ** Fr Fg Fb
        AND     EAX,$00FF00FF   // EAX  <-  00 Fr 00 Fb
        AND     EBX,$0000FF00   // EBX  <-  00 00 Fg 00
        IMUL    EAX,ECX         // EAX  <-  Pr ** Pb **
        SHR     EBX,8           // EBX  <-  00 00 00 Fg
        IMUL    EBX,ECX         // EBX  <-  00 00 Pg **
        ADD     EAX,bias
        AND     EAX,$FF00FF00   // EAX  <-  Pr 00 Pb 00
        SHR     EAX,8           // EAX  <-  00 Pr 00 Pb
        ADD     EBX,bias
        AND     EBX,$0000FF00   // EBX  <-  00 00 Pg 00
        OR      EAX,EBX         // EAX  <-  00 Pr Pg Pb

  // W = 1 - W; Q = W * B
        MOV     ESI,[EDX]
        XOR     ECX,$000000FF   // ECX  <-  1 - ECX
        MOV     EBX,ESI         // EBX  <-  00 Br Bg Bb
        AND     ESI,$00FF00FF   // ESI  <-  00 Br 00 Bb
        AND     EBX,$0000FF00   // EBX  <-  00 00 Bg 00
        IMUL    ESI,ECX         // ESI  <-  Qr ** Qb **
        SHR     EBX,8           // EBX  <-  00 00 00 Bg
        IMUL    EBX,ECX         // EBX  <-  00 00 Qg **
        ADD     ESI,bias
        AND     ESI,$FF00FF00   // ESI  <-  Qr 00 Qb 00
        SHR     ESI,8           // ESI  <-  00 Qr ** Qb
        ADD     EBX,bias
        AND     EBX,$0000FF00   // EBX  <-  00 00 Qg 00
        OR      EBX,ESI         // EBX  <-  00 Qr Qg Qb

  // Z = P + Q (assuming no overflow at each byte)
        ADD     EAX,EBX         // EAX  <-  00 Zr Zg Zb

        MOV     [EDX],EAX

        POP     ESI
        POP     EBX
@1:     RET

@2:     MOV     [EDX],EAX
        RET
{$ENDIF}

{$IFDEF TARGET_x64}
  // ECX <- F
  // [RDX] <- B
  // R8 <- W

  // Check W
        TEST    R8D,R8D         // Set flags for R8
        JZ      @2              // W = 0 ?  => Result := EDX
        MOV     EAX,ECX         // EAX  <-  ** Fr Fg Fb
        CMP     R8B,$FF         // W = 255? => write F
        JZ      @1

  // P = W * F
        AND     EAX,$00FF00FF   // EAX  <-  00 Fr 00 Fb
        AND     ECX,$FF00FF00   // ECX  <-  Fa 00 Fg 00
        IMUL    EAX,R8D         // EAX  <-  Pr ** Pb **
        SHR     ECX,8           // ECX  <-  00 Fa 00 Fg
        IMUL    ECX,R8D         // ECX  <-  00 00 Pg **
        ADD     EAX,bias
        AND     EAX,$FF00FF00   // EAX  <-  Pr 00 Pb 00
        SHR     EAX,8           // EAX  <-  00 Pr 00 Pb
        ADD     ECX,bias
        AND     ECX,$FF00FF00   // ECX  <-  Pa 00 Pg 00
        OR      EAX,ECX         // EAX  <-  00 Pr Pg Pb

  // W = 1 - W; Q = W * B
        MOV     R9D,[RDX]
        XOR     R8D,$000000FF   // R8D  <-  1 - R8D
        MOV     ECX,R9D         // ECX  <-  Ba Br Bg Bb
        AND     R9D,$00FF00FF   // R9D  <-  00 Br 00 Bb
        AND     ECX,$FF00FF00   // ECX  <-  Ba 00 Bg 00
        IMUL    R9D,R8D         // R9D  <-  Qr ** Qb **
        SHR     ECX,8           // ECX  <-  00 Ba 00 Bg
        IMUL    ECX,R8D         // ECX  <-  Qa 00 Qg **
        ADD     R9D,bias
        AND     R9D,$FF00FF00   // R9D  <-  Qr 00 Qb 00
        SHR     R9D,8           // R9D  <-  00 Qr ** Qb
        ADD     ECX,bias
        AND     ECX,$FF00FF00   // ECX  <-  Qa 00 Qg 00
        OR      ECX,R9D         // ECX  <-  00 Qr Qg Qb

  // Z = P + Q (assuming no overflow at each byte)
        ADD     EAX,ECX         // EAX  <-  00 Zr Zg Zb

@1:     MOV     [RDX],EAX
@2:

{$ENDIF}
end;

function _BlendReg(F, B: TColor32): TColor32; {$IFDEF FPC} assembler; nostackframe; {$ENDIF}
asm
  // blend foregrownd color (F) to a background color (B),
  // using alpha channel value of F
  // Result Z = Fa * Frgb + (1 - Fa) * Brgb
{$IFDEF TARGET_x86}
  // EAX <- F
  // EDX <- B

  // Test Fa = 255 ?
        CMP     EAX,$FF000000   // Fa = 255 ? => Result = EAX
        JNC     @2

  // Test Fa = 0 ?
        TEST    EAX,$FF000000   // Fa = 0 ?   => Result = EDX
        JZ      @1

  // Get weight W = Fa * M
        MOV     ECX,EAX         // ECX  <-  Fa Fr Fg Fb
        SHR     ECX,24          // ECX  <-  00 00 00 Fa

        PUSH    EBX

  // P = W * F
        MOV     EBX,EAX         // EBX  <-  Fa Fr Fg Fb
        AND     EAX,$00FF00FF   // EAX  <-  00 Fr 00 Fb
        AND     EBX,$FF00FF00   // EBX  <-  Fa 00 Fg 00
        IMUL    EAX,ECX         // EAX  <-  Pr ** Pb **
        SHR     EBX,8           // EBX  <-  00 Fa 00 Fg
        IMUL    EBX,ECX         // EBX  <-  Pa ** Pg **
        ADD     EAX,bias
        AND     EAX,$FF00FF00   // EAX  <-  Pr 00 Pb 00
        SHR     EAX,8           // EAX  <-  00 Pr ** Pb
        ADD     EBX,bias
        AND     EBX,$FF00FF00   // EBX  <-  Pa 00 Pg 00
        OR      EAX,EBX         // EAX  <-  Pa Pr Pg Pb

  // W = 1 - W; Q = W * B
        XOR     ECX,$000000FF   // ECX  <-  1 - ECX
        MOV     EBX,EDX         // EBX  <-  Ba Br Bg Bb
        AND     EDX,$00FF00FF   // EDX  <-  00 Br 00 Bb
        AND     EBX,$FF00FF00   // EBX  <-  Ba 00 Bg 00
        IMUL    EDX,ECX         // EDX  <-  Qr ** Qb **
        SHR     EBX,8           // EBX  <-  00 Ba 00 Bg
        IMUL    EBX,ECX         // EBX  <-  Qa ** Qg **
        ADD     EDX,bias
        AND     EDX,$FF00FF00   // EDX  <-  Qr 00 Qb 00
        SHR     EDX,8           // EDX  <-  00 Qr ** Qb
        ADD     EBX,bias
        AND     EBX,$FF00FF00   // EBX  <-  Qa 00 Qg 00
        OR      EBX,EDX         // EBX  <-  Qa Qr Qg Qb

  // Z = P + Q (assuming no overflow at each byte)
        ADD     EAX,EBX         // EAX  <-  Za Zr Zg Zb

        POP     EBX
        RET

@1:     MOV     EAX,EDX
@2:     RET
{$ENDIF}

  // EAX <- F
  // EDX <- B
{$IFDEF TARGET_x64}
        MOV     RAX, RCX

  // Test Fa = 255 ?
        CMP     EAX,$FF000000   // Fa = 255 ? => Result = EAX
        JNC     @2

  // Test Fa = 0 ?
        TEST    EAX,$FF000000   // Fa = 0 ?   => Result = EDX
        JZ      @1

  // Get weight W = Fa * M
        MOV     ECX,EAX         // ECX  <-  Fa Fr Fg Fb
        SHR     ECX,24          // ECX  <-  00 00 00 Fa

  // P = W * F
        MOV     R9D,EAX         // R9D  <-  Fa Fr Fg Fb
        AND     EAX,$00FF00FF   // EAX  <-  00 Fr 00 Fb
        AND     R9D,$FF00FF00   // R9D  <-  Fa 00 Fg 00
        IMUL    EAX,ECX         // EAX  <-  Pr ** Pb **
        SHR     R9D,8           // R9D  <-  00 Fa 00 Fg
        IMUL    R9D,ECX         // R9D  <-  Pa ** Pg **
        ADD     EAX,bias
        AND     EAX,$FF00FF00   // EAX  <-  Pr 00 Pb 00
        SHR     EAX,8           // EAX  <-  00 Pr ** Pb
        ADD     R9D,bias
        AND     R9D,$FF00FF00   // R9D  <-  Pa 00 Pg 00
        OR      EAX,R9D         // EAX  <-  Pa Pr Pg Pb

  // W = 1 - W; Q = W * B
        XOR     ECX,$000000FF   // ECX  <-  1 - ECX
        MOV     R9D,EDX         // R9D  <-  Ba Br Bg Bb
        AND     EDX,$00FF00FF   // EDX  <-  00 Br 00 Bb
        AND     R9D,$FF00FF00   // R9D  <-  Ba 00 Bg 00
        IMUL    EDX,ECX         // EDX  <-  Qr ** Qb **
        SHR     R9D,8           // R9D  <-  00 Ba 00 Bg
        IMUL    R9D,ECX         // R9D  <-  Qa ** Qg **
        ADD     EDX,bias
        AND     EDX,$FF00FF00   // EDX  <-  Qr 00 Qb 00
        SHR     EDX,8           // EDX  <-  00 Qr ** Qb
        ADD     R9D,bias
        AND     R9D,$FF00FF00   // R9D  <-  Qa 00 Qg 00
        OR      R9D,EDX         // R9D  <-  Qa Qr Qg Qb

  // Z = P + Q (assuming no overflow at each byte)
        ADD     EAX,R9D         // EAX  <-  Za Zr Zg Zb
        RET

@1:     MOV     EAX,EDX
@2:
{$ENDIF}
end;

procedure _BlendMem(F: TColor32; var B: TColor32); {$IFDEF FPC} assembler; nostackframe; {$ENDIF}
asm
{$IFDEF TARGET_x86}
  // EAX <- F
  // [EDX] <- B


  // Test Fa = 0 ?
        TEST    EAX,$FF000000   // Fa = 0 ?   => do not write
        JZ      @2

  // Get weight W = Fa * M
        MOV     ECX,EAX         // ECX  <-  Fa Fr Fg Fb
        SHR     ECX,24          // ECX  <-  00 00 00 Fa

  // Test Fa = 255 ?
        CMP     ECX,$FF
        JZ      @1

        PUSH EBX
        PUSH ESI

  // P = W * F
        MOV     EBX,EAX         // EBX  <-  Fa Fr Fg Fb
        AND     EAX,$00FF00FF   // EAX  <-  00 Fr 00 Fb
        AND     EBX,$FF00FF00   // EBX  <-  Fa 00 Fg 00
        IMUL    EAX,ECX         // EAX  <-  Pr ** Pb **
        SHR     EBX,8           // EBX  <-  00 Fa 00 Fg
        IMUL    EBX,ECX         // EBX  <-  Pa ** Pg **
        ADD     EAX,bias
        AND     EAX,$FF00FF00   // EAX  <-  Pr 00 Pb 00
        SHR     EAX,8           // EAX  <-  00 Pr ** Pb
        ADD     EBX,bias
        AND     EBX,$FF00FF00   // EBX  <-  Pa 00 Pg 00
        OR      EAX,EBX         // EAX  <-  Pa Pr Pg Pb

  // W = 1 - W; Q = W * B
        MOV     ESI,[EDX]
        XOR     ECX,$000000FF   // ECX  <-  1 - ECX
        MOV     EBX,ESI         // EBX  <-  Ba Br Bg Bb
        AND     ESI,$00FF00FF   // ESI  <-  00 Br 00 Bb
        AND     EBX,$FF00FF00   // EBX  <-  Ba 00 Bg 00
        IMUL    ESI,ECX         // ESI  <-  Qr ** Qb **
        SHR     EBX,8           // EBX  <-  00 Ba 00 Bg
        IMUL    EBX,ECX         // EBX  <-  Qa ** Qg **
        ADD     ESI,bias
        AND     ESI,$FF00FF00   // ESI  <-  Qr 00 Qb 00
        SHR     ESI,8           // ESI  <-  00 Qr ** Qb
        ADD     EBX,bias
        AND     EBX,$FF00FF00   // EBX  <-  Qa 00 Qg 00
        OR      EBX,ESI         // EBX  <-  Qa Qr Qg Qb

  // Z = P + Q (assuming no overflow at each byte)
        ADD     EAX,EBX         // EAX  <-  Za Zr Zg Zb
        MOV     [EDX],EAX

        POP     ESI
        POP     EBX
        RET

@1:     MOV     [EDX],EAX
@2:     RET
{$ENDIF}

{$IFDEF TARGET_x64}
  // ECX <- F
  // [RDX] <- B

  // Test Fa = 0 ?
        TEST    ECX,$FF000000   // Fa = 0 ?   => do not write
        JZ      @2

        MOV     EAX, ECX        // EAX  <-  Fa Fr Fg Fb

        // Get weight W = Fa * M
        SHR     ECX,24          // ECX  <-  00 00 00 Fa

        // Test Fa = 255 ?
        CMP     ECX,$FF
        JZ      @1

  // P = W * F
        MOV     R8D,EAX         // R8D  <-  Fa Fr Fg Fb
        AND     EAX,$00FF00FF   // EAX  <-  00 Fr 00 Fb
        AND     R8D,$FF00FF00   // R8D  <-  Fa 00 Fg 00
        IMUL    EAX,ECX         // EAX  <-  Pr ** Pb **
        SHR     R8D,8           // R8D  <-  00 Fa 00 Fg
        IMUL    R8D,ECX         // R8D  <-  Pa ** Pg **
        ADD     EAX,bias
        AND     EAX,$FF00FF00   // EAX  <-  Pr 00 Pb 00
        SHR     EAX,8           // EAX  <-  00 Pr ** Pb
        ADD     R8D,bias
        AND     R8D,$FF00FF00   // R8D  <-  Pa 00 Pg 00
        OR      EAX,R8D         // EAX  <-  Pa Pr Pg Pb

        MOV     R9D,[RDX]

  // W = 1 - W; Q = W * B
        XOR     ECX,$000000FF   // ECX  <-  1 - ECX
        MOV     R8D,R9D         // R8D  <-  Ba Br Bg Bb
        AND     R9D,$00FF00FF   // R9D  <-  00 Br 00 Bb
        AND     R8D,$FF00FF00   // R8D  <-  Ba 00 Bg 00
        IMUL    R9D,ECX         // R9D  <-  Qr ** Qb **
        SHR     R8D,8           // R8D  <-  00 Ba 00 Bg
        IMUL    R8D,ECX         // R8D  <-  Qa ** Qg **
        ADD     R9D,bias
        AND     R9D,$FF00FF00   // R9D  <-  Qr 00 Qb 00
        SHR     R9D,8           // R9D  <-  00 Qr ** Qb
        ADD     R8D,bias
        AND     R8D,$FF00FF00   // R8D  <-  Qa 00 Qg 00
        OR      R8D,R9D         // R8D  <-  Qa Qr Qg Qb

  // Z = P + Q (assuming no overflow at each byte)
        ADD     EAX,R8D         // EAX  <-  Za Zr Zg Zb

        MOV     [RDX],EAX
        RET

@1:     MOV     [RDX],EAX
@2:
{$ENDIF}
end;

function _BlendRegEx(F, B, M: TColor32): TColor32; {$IFDEF FPC} assembler; nostackframe; {$ENDIF}
asm
  // blend foregrownd color (F) to a background color (B),
  // using alpha channel value of F multiplied by master alpha (M)
  // no checking for M = $FF, if this is the case when Graphics32 uses BlendReg
  // Result Z = Fa * M * Frgb + (1 - Fa * M) * Brgb
  // EAX <- F
  // EDX <- B
  // ECX <- M

{$IFDEF TARGET_x86}

// Check Fa > 0 ?
        TEST    EAX,$FF000000   // Fa = 0? => Result := EDX
        JZ      @2

        PUSH    EBX

  // Get weight W = Fa * M
        MOV     EBX,EAX         // EBX  <-  Fa Fr Fg Fb
        INC     ECX             // 255:256 range bias
        SHR     EBX,24          // EBX  <-  00 00 00 Fa
        IMUL    ECX,EBX         // ECX  <-  00 00  W **
        SHR     ECX,8           // ECX  <-  00 00 00  W
        JZ      @1              // W = 0 ?  => Result := EDX

  // P = W * F
        MOV     EBX,EAX         // EBX  <-  ** Fr Fg Fb
        AND     EAX,$00FF00FF   // EAX  <-  00 Fr 00 Fb
        AND     EBX,$0000FF00   // EBX  <-  00 00 Fg 00
        IMUL    EAX,ECX         // EAX  <-  Pr ** Pb **
        SHR     EBX,8           // EBX  <-  00 00 00 Fg
        IMUL    EBX,ECX         // EBX  <-  00 00 Pg **
        ADD     EAX,bias
        AND     EAX,$FF00FF00   // EAX  <-  Pr 00 Pb 00
        SHR     EAX,8           // EAX  <-  00 Pr ** Pb
        ADD     EBX,bias
        AND     EBX,$0000FF00   // EBX  <-  00 00 Pg 00
        OR      EAX,EBX         // EAX  <-  00 Pr Pg Pb

  // W = 1 - W; Q = W * B
        XOR     ECX,$000000FF   // ECX  <-  1 - ECX
        MOV     EBX,EDX         // EBX  <-  00 Br Bg Bb
        AND     EDX,$00FF00FF   // EDX  <-  00 Br 00 Bb
        AND     EBX,$0000FF00   // EBX  <-  00 00 Bg 00
        IMUL    EDX,ECX         // EDX  <-  Qr ** Qb **
        SHR     EBX,8           // EBX  <-  00 00 00 Bg
        IMUL    EBX,ECX         // EBX  <-  00 00 Qg **
        ADD     EDX,bias
        AND     EDX,$FF00FF00   // EDX  <-  Qr 00 Qb 00
        SHR     EDX,8           // EDX  <-  00 Qr ** Qb
        ADD     EBX,bias
        AND     EBX,$0000FF00   // EBX  <-  00 00 Qg 00
        OR      EBX,EDX         // EBX  <-  00 Qr Qg Qb

  // Z = P + Q (assuming no overflow at each byte)
        ADD     EAX,EBX         // EAX  <-  00 Zr Zg Zb

        POP     EBX
        RET
        
@1:     POP     EBX
@2:     MOV     EAX,EDX
        RET
{$ENDIF}

{$IFDEF TARGET_x64}
        MOV     EAX,ECX         // EAX  <-  Fa Fr Fg Fb
        TEST    EAX,$FF000000   // Fa = 0? => Result := EDX
        JZ      @1

  // Get weight W = Fa * M
        INC     R8D             // 255:256 range bias
        SHR     ECX,24          // ECX  <-  00 00 00 Fa
        IMUL    R8D,ECX         // R8D  <-  00 00  W **
        SHR     R8D,8           // R8D  <-  00 00 00  W
        JZ      @1              // W = 0 ?  => Result := EDX

  // P = W * F
        MOV     ECX,EAX         // ECX  <-  ** Fr Fg Fb
        AND     EAX,$00FF00FF   // EAX  <-  00 Fr 00 Fb
        AND     ECX,$0000FF00   // ECX  <-  00 00 Fg 00
        IMUL    EAX,R8D         // EAX  <-  Pr ** Pb **
        SHR     ECX,8           // ECX  <-  00 00 00 Fg
        IMUL    ECX,R8D         // ECX  <-  00 00 Pg **
        ADD     EAX,bias
        AND     EAX,$FF00FF00   // EAX  <-  Pr 00 Pb 00
        SHR     EAX,8           // EAX  <-  00 Pr ** Pb
        ADD     ECX,bias
        AND     ECX,$0000FF00   // ECX  <-  00 00 Pg 00
        OR      EAX,ECX         // EAX  <-  00 Pr Pg Pb

  // W = 1 - W; Q = W * B
        XOR     R8D,$000000FF   // R8D  <-  1 - R8D
        MOV     ECX,EDX         // ECX  <-  00 Br Bg Bb
        AND     EDX,$00FF00FF   // EDX  <-  00 Br 00 Bb
        AND     ECX,$0000FF00   // ECX  <-  00 00 Bg 00
        IMUL    EDX,R8D         // EDX  <-  Qr ** Qb **
        SHR     ECX,8           // ECX  <-  00 00 00 Bg
        IMUL    ECX,R8D         // ECX  <-  00 00 Qg **
        ADD     EDX,bias
        AND     EDX,$FF00FF00   // EDX  <-  Qr 00 Qb 00
        SHR     EDX,8           // EDX  <-  00 Qr ** Qb
        ADD     ECX,bias
        AND     ECX,$0000FF00   // ECX  <-  00 00 Qg 00
        OR      ECX,EDX         // ECX  <-  00 Qr Qg Qb

  // Z = P + Q (assuming no overflow at each byte)
        ADD     EAX,ECX         // EAX  <-  00 Zr Zg Zb

        RET

@1:     MOV     EAX,EDX
{$ENDIF}
end;

procedure _BlendMemEx(F: TColor32; var B: TColor32; M: TColor32); {$IFDEF FPC} assembler; nostackframe; {$ENDIF}
asm
{$IFDEF TARGET_x86}
  // EAX <- F
  // [EDX] <- B
  // ECX <- M

  // Check Fa > 0 ?
        TEST    EAX,$FF000000   // Fa = 0? => write nothing
        JZ      @2

        PUSH    EBX

  // Get weight W = Fa * M
        MOV     EBX,EAX         // EBX  <-  Fa Fr Fg Fb
        INC     ECX             // 255:256 range bias
        SHR     EBX,24          // EBX  <-  00 00 00 Fa
        IMUL    ECX,EBX         // ECX  <-  00 00  W **
        SHR     ECX,8           // ECX  <-  00 00 00  W
        JZ      @1              // W = 0 ?  => write nothing

        PUSH    ESI

  // P = W * F
        MOV     EBX,EAX         // EBX  <-  ** Fr Fg Fb
        AND     EAX,$00FF00FF   // EAX  <-  00 Fr 00 Fb
        AND     EBX,$0000FF00   // EBX  <-  00 00 Fg 00
        IMUL    EAX,ECX         // EAX  <-  Pr ** Pb **
        SHR     EBX,8           // EBX  <-  00 00 00 Fg
        IMUL    EBX,ECX         // EBX  <-  00 00 Pg **
        ADD     EAX,bias
        AND     EAX,$FF00FF00   // EAX  <-  Pr 00 Pb 00
        SHR     EAX,8           // EAX  <-  00 Pr ** Pb
        ADD     EBX,bias
        AND     EBX,$0000FF00   // EBX  <-  00 00 Pg 00
        OR      EAX,EBX         // EAX  <-  00 Pr Pg Pb

  // W = 1 - W; Q = W * B
        MOV     ESI,[EDX]
        XOR     ECX,$000000FF   // ECX  <-  1 - ECX
        MOV     EBX,ESI         // EBX  <-  00 Br Bg Bb
        AND     ESI,$00FF00FF   // ESI  <-  00 Br 00 Bb
        AND     EBX,$0000FF00   // EBX  <-  00 00 Bg 00
        IMUL    ESI,ECX         // ESI  <-  Qr ** Qb **
        SHR     EBX,8           // EBX  <-  00 00 00 Bg
        IMUL    EBX,ECX         // EBX  <-  00 00 Qg **
        ADD     ESI,bias
        AND     ESI,$FF00FF00   // ESI  <-  Qr 00 Qb 00
        SHR     ESI,8           // ESI  <-  00 Qr ** Qb
        ADD     EBX,bias
        AND     EBX,$0000FF00   // EBX  <-  00 00 Qg 00
        OR      EBX,ESI         // EBX  <-  00 Qr Qg Qb

  // Z = P + Q (assuming no overflow at each byte)
        ADD     EAX,EBX         // EAX  <-  00 Zr Zg Zb

        MOV     [EDX],EAX
        POP     ESI

@1:     POP     EBX
@2:     RET
{$ENDIF}

{$IFDEF TARGET_x64}
  // ECX <- F
  // [RDX] <- B
  // R8 <- M

  // ECX <- F
  // [EDX] <- B
  // R8 <- M

  // Check Fa > 0 ?
        TEST    ECX,$FF000000   // Fa = 0? => write nothing
        JZ      @1

  // Get weight W = Fa * M
        MOV     EAX,ECX         // EAX  <-  Fa Fr Fg Fb
        INC     R8D             // 255:256 range bias
        SHR     EAX,24          // EAX  <-  00 00 00 Fa
        IMUL    R8D,EAX         // R8D <-  00 00  W **
        SHR     R8D,8           // R8D <-  00 00 00  W
        JZ      @1              // W = 0 ?  => write nothing

  // P = W * F
        MOV     EAX,ECX         // EAX  <-  ** Fr Fg Fb
        AND     ECX,$00FF00FF   // ECX  <-  00 Fr 00 Fb
        AND     EAX,$0000FF00   // EAX  <-  00 00 Fg 00
        IMUL    ECX,R8D         // ECX  <-  Pr ** Pb **
        SHR     EAX,8           // EAX  <-  00 00 00 Fg
        IMUL    EAX,R8D         // EAX  <-  00 00 Pg **
        ADD     ECX,bias
        AND     ECX,$FF00FF00   // ECX  <-  Pr 00 Pb 00
        SHR     ECX,8           // ECX  <-  00 Pr ** Pb
        ADD     EAX,bias
        AND     EAX,$0000FF00   // EAX  <-  00 00 Pg 00
        OR      ECX,EAX         // ECX  <-  00 Pr Pg Pb

  // W = 1 - W; Q = W * B
        MOV     R9D,[RDX]
        XOR     R8D,$000000FF   // R8D  <-  1 - R8
        MOV     EAX,R9D         // EAX  <-  00 Br Bg Bb
        AND     R9D,$00FF00FF   // R9D  <-  00 Br 00 Bb
        AND     EAX,$0000FF00   // EAX  <-  00 00 Bg 00
        IMUL    R9D,R8D         // R9D  <-  Qr ** Qb **
        SHR     EAX,8           // EAX  <-  00 00 00 Bg
        IMUL    EAX,R8D         // EAX  <-  00 00 Qg **
        ADD     R9D,bias
        AND     R9D,$FF00FF00   // R9D  <-  Qr 00 Qb 00
        SHR     R9D,8           // R9D  <-  00 Qr ** Qb
        ADD     EAX,bias
        AND     EAX,$0000FF00   // EAX  <-  00 00 Qg 00
        OR      EAX,R9D         // EAX  <-  00 Qr Qg Qb

  // Z = P + Q (assuming no overflow at each byte)
        ADD     ECX,EAX         // ECX  <-  00 Zr Zg Zb

        MOV     [RDX],ECX

@1:
{$ENDIF}
end;

procedure _BlendLine(Src, Dst: PColor32; Count: Integer); {$IFDEF FPC} assembler; nostackframe; {$ENDIF}
asm
{$IFDEF TARGET_x86}
  // EAX <- Src
  // EDX <- Dst
  // ECX <- Count

  // test the counter for zero or negativity
        TEST    ECX,ECX
        JS      @4

        PUSH    EBX
        PUSH    ESI
        PUSH    EDI

        MOV     ESI,EAX         // ESI <- Src
        MOV     EDI,EDX         // EDI <- Dst

  // loop start
@1:     MOV     EAX,[ESI]
        TEST    EAX,$FF000000
        JZ      @3              // complete transparency, proceed to next point

        PUSH    ECX             // store counter

  // Get weight W = Fa * M
        MOV     ECX,EAX         // ECX  <-  Fa Fr Fg Fb
        SHR     ECX,24          // ECX  <-  00 00 00 Fa

  // Test Fa = 255 ?
        CMP     ECX,$FF
        JZ      @2

  // P = W * F
        MOV     EBX,EAX         // EBX  <-  Fa Fr Fg Fb
        AND     EAX,$00FF00FF   // EAX  <-  00 Fr 00 Fb
        AND     EBX,$FF00FF00   // EBX  <-  Fa 00 Fg 00
        IMUL    EAX,ECX         // EAX  <-  Pr ** Pb **
        SHR     EBX,8           // EBX  <-  00 Fa 00 Fg
        IMUL    EBX,ECX         // EBX  <-  Pa ** Pg **
        ADD     EAX,bias
        AND     EAX,$FF00FF00   // EAX  <-  Pr 00 Pb 00
        SHR     EAX,8           // EAX  <-  00 Pr ** Pb
        ADD     EBX,bias
        AND     EBX,$FF00FF00   // EBX  <-  Pa 00 Pg 00
        OR      EAX,EBX         // EAX  <-  Pa Pr Pg Pb

  // W = 1 - W; Q = W * B
        MOV     EDX,[EDI]
        XOR     ECX,$000000FF   // ECX  <-  1 - ECX
        MOV     EBX,EDX         // EBX  <-  Ba Br Bg Bb
        AND     EDX,$00FF00FF   // ESI  <-  00 Br 00 Bb
        AND     EBX,$FF00FF00   // EBX  <-  Ba 00 Bg 00
        IMUL    EDX,ECX         // ESI  <-  Qr ** Qb **
        SHR     EBX,8           // EBX  <-  00 Ba 00 Bg
        IMUL    EBX,ECX         // EBX  <-  Qa ** Qg **
        ADD     EDX,bias
        AND     EDX,$FF00FF00   // ESI  <-  Qr 00 Qb 00
        SHR     EDX,8           // ESI  <-  00 Qr ** Qb
        ADD     EBX,bias
        AND     EBX,$FF00FF00   // EBX  <-  Qa 00 Qg 00
        OR      EBX,EDX         // EBX  <-  Qa Qr Qg Qb

  // Z = P + Q (assuming no overflow at each byte)
        ADD     EAX,EBX         // EAX  <-  Za Zr Zg Zb
@2:     MOV     [EDI],EAX

        POP     ECX             // restore counter

@3:     ADD     ESI,4
        ADD     EDI,4

  // loop end
        DEC     ECX
        JNZ     @1

        POP     EDI
        POP     ESI
        POP     EBX

@4:     RET
{$ENDIF}

{$IFDEF TARGET_x64}
  // RCX <- Src
  // RDX <- Dst
  // R8 <- Count

  // test the counter for zero or negativity
        TEST    R8D,R8D
        JS      @4

        MOV     R10,RCX         // R10 <- Src
        MOV     R11,RDX         // R11 <- Dst
        MOV     ECX,R8D         // RCX <- Count

  // loop start
@1:
        MOV     EAX,[R10]
        TEST    EAX,$FF000000
        JZ      @3              // complete transparency, proceed to next point

  // Get weight W = Fa * M
        MOV     R9D,EAX        // R9D  <-  Fa Fr Fg Fb
        SHR     R9D,24         // R9D  <-  00 00 00 Fa

  // Test Fa = 255 ?
        CMP     R9D,$FF
        JZ      @2

  // P = W * F
        MOV     R8D,EAX         // R8D  <-  Fa Fr Fg Fb
        AND     EAX,$00FF00FF   // EAX  <-  00 Fr 00 Fb
        AND     R8D,$FF00FF00   // R8D  <-  Fa 00 Fg 00
        IMUL    EAX,R9D         // EAX  <-  Pr ** Pb **
        SHR     R8D,8           // R8D  <-  00 Fa 00 Fg
        IMUL    R8D,R9D         // R8D  <-  Pa ** Pg **
        ADD     EAX,bias
        AND     EAX,$FF00FF00   // EAX  <-  Pr 00 Pb 00
        SHR     EAX,8           // EAX  <-  00 Pr ** Pb
        ADD     R8D,bias
        AND     R8D,$FF00FF00   // R8D  <-  Pa 00 Pg 00
        OR      EAX,R8D         // EAX  <-  Pa Pr Pg Pb

  // W = 1 - W; Q = W * B
        MOV     EDX,[R11]
        XOR     R9D,$000000FF   // R9D  <-  1 - R9D
        MOV     R8D,EDX         // R8D  <-  Ba Br Bg Bb
        AND     EDX,$00FF00FF   // ESI  <-  00 Br 00 Bb
        AND     R8D,$FF00FF00   // R8D  <-  Ba 00 Bg 00
        IMUL    EDX,R9D         // ESI  <-  Qr ** Qb **
        SHR     R8D,8           // R8D  <-  00 Ba 00 Bg
        IMUL    R8D,R9D         // R8D  <-  Qa ** Qg **
        ADD     EDX,bias
        AND     EDX,$FF00FF00   // ESI  <-  Qr 00 Qb 00
        SHR     EDX,8           // ESI  <-  00 Qr ** Qb
        ADD     R8D,bias
        AND     R8D,$FF00FF00   // R8D  <-  Qa 00 Qg 00
        OR      R8D,EDX         // R8D  <-  Qa Qr Qg Qb

  // Z = P + Q (assuming no overflow at each byte)
        ADD     EAX,R8D         // EAX  <-  Za Zr Zg Zb
@2:
        MOV     [R11],EAX

@3:
        ADD     R10,4
        ADD     R11,4

  // loop end
        DEC     ECX
        JNZ     @1

@4:
{$ENDIF}
end;

procedure _BlendLineEx(Src, Dst: PColor32; Count: Integer; M: TColor32);
begin
  while Count > 0 do
  begin
    _BlendMemEx(Src^, Dst^, M);
    Inc(Src);
    Inc(Dst);
    Dec(Count);
  end;
end;

{ MMX versions }


procedure GenAlphaTable;
var
  I: Integer;
  L: Longword;
  P: ^Longword;
begin
  GetMem(AlphaTable, 257 * 8);
  alpha_ptr := Pointer(Integer(AlphaTable) and $FFFFFFF8);
  if Integer(alpha_ptr) < Integer(AlphaTable) then
    alpha_ptr := Pointer(Integer(alpha_ptr) + 8);
  P := alpha_ptr;
  for I := 0 to 255 do
  begin
    L := I + I shl 16;
    P^ := L;
    Inc(P);
    P^ := L;
    Inc(P);
  end;
  bias_ptr := Pointer(Integer(alpha_ptr) + $80 * 8);
end;

procedure FreeAlphaTable;
begin
  FreeMem(AlphaTable);
end;

procedure EMMS;
{$IFNDEF TARGET_x64} // Needs better solution. Check more recent Graphics32.
begin
  if MMX_ACTIVE then
{$ENDIF}
  asm
    db $0F,$77               /// EMMS
  end;
{$IFNDEF TARGET_x64}
end;
{$ENDIF}

function M_CombineReg(X, Y, W: TColor32): TColor32; {$IFDEF FPC} assembler; nostackframe; {$ENDIF}
asm
{$IFDEF TARGET_x86}
  // EAX - Color X
  // EDX - Color Y
  // ECX - Weight of X [0..255]
  // Result := W * (X - Y) + Y

        db $0F,$6E,$C8           /// MOVD      MM1,EAX
        db $0F,$EF,$C0           /// PXOR      MM0,MM0
        SHL       ECX,3
        db $0F,$6E,$D2           /// MOVD      MM2,EDX
        db $0F,$60,$C8           /// PUNPCKLBW MM1,MM0
        db $0F,$60,$D0           /// PUNPCKLBW MM2,MM0
        ADD       ECX,alpha_ptr
        db $0F,$F9,$CA           /// PSUBW     MM1,MM2
        db $0F,$D5,$09           /// PMULLW    MM1,[ECX]
        db $0F,$71,$F2,$08       /// PSLLW     MM2,8
        MOV       ECX,bias_ptr
        db $0F,$FD,$11           /// PADDW     MM2,[ECX]
        db $0F,$FD,$CA           /// PADDW     MM1,MM2
        db $0F,$71,$D1,$08       /// PSRLW     MM1,8
        db $0F,$67,$C8           /// PACKUSWB  MM1,MM0
        db $0F,$7E,$C8           /// MOVD      EAX,MM1
{$ENDIF}

{$IFDEF TARGET_X64}
  // ECX - Color X
  // EDX - Color Y
  // R8 - Weight of X [0..255]
  // Result := W * (X - Y) + Y

        MOVD      MM1,ECX
        PXOR      MM0,MM0
        SHL       R8D,4

        MOVD      MM2,EDX
        PUNPCKLBW MM1,MM0
        PUNPCKLBW MM2,MM0

{$IFNDEF FPC}
        ADD       R8,alpha_ptr
{$ELSE}
        ADD       R8,[RIP+alpha_ptr]
{$ENDIF}

        PSUBW     MM1,MM2
        PMULLW    MM1,[R8]
        PSLLW     MM2,8

{$IFNDEF FPC}
        MOV       RAX,bias_ptr
{$ELSE}
        MOV       RAX,[RIP+bias_ptr] // XXX : Enabling PIC by relative offsetting for x64
{$ENDIF}

        PADDW     MM2,[RAX]
        PADDW     MM1,MM2
        PSRLW     MM1,8
        PACKUSWB  MM1,MM0
        MOVD      EAX,MM1
{$ENDIF}
end;

procedure M_CombineMem(F: TColor32; var B: TColor32; W: TColor32); {$IFDEF FPC} assembler; nostackframe; {$ENDIF}
asm
{$IFDEF TARGET_x86}
  // EAX - Color X
  // [EDX] - Color Y
  // ECX - Weight of X [0..255]
  // Result := W * (X - Y) + Y

        JCXZ      @1
        CMP       ECX,$FF
        JZ        @2

        db $0F,$6E,$C8           /// MOVD      MM1,EAX
        db $0F,$EF,$C0           /// PXOR      MM0,MM0
        SHL       ECX,3
        db $0F,$6E,$12           /// MOVD      MM2,[EDX]
        db $0F,$60,$C8           /// PUNPCKLBW MM1,MM0
        db $0F,$60,$D0           /// PUNPCKLBW MM2,MM0
        ADD       ECX,alpha_ptr
        db $0F,$F9,$CA           /// PSUBW     MM1,MM2
        db $0F,$D5,$09           /// PMULLW    MM1,[ECX]
        db $0F,$71,$F2,$08       /// PSLLW     MM2,8
        MOV       ECX,bias_ptr
        db $0F,$FD,$11           /// PADDW     MM2,[ECX]
        db $0F,$FD,$CA           /// PADDW     MM1,MM2
        db $0F,$71,$D1,$08       /// PSRLW     MM1,8
        db $0F,$67,$C8           /// PACKUSWB  MM1,MM0
        db $0F,$7E,$0A           /// MOVD      [EDX],MM1
@1:     RET

@2:     MOV       [EDX],EAX
{$ENDIF}

{$IFDEF TARGET_x64}
  // ECX - Color X
  // [RDX] - Color Y
  // R8 - Weight of X [0..255]
  // Result := W * (X - Y) + Y

        TEST      R8D,R8D            // Set flags for R8
        JZ        @1                 // W = 0 ?  => Result := EDX
        CMP       R8D,$FF
        JZ        @2

        MOVD      MM1,ECX
        PXOR      MM0,MM0

        SHL       R8D,4

        MOVD      MM2,[RDX]
        PUNPCKLBW MM1,MM0
        PUNPCKLBW MM2,MM0

{$IFNDEF FPC}
        ADD       R8,alpha_ptr
{$ELSE}
        ADD       R8,[RIP+alpha_ptr]
{$ENDIF}

        PSUBW     MM1,MM2
        PMULLW    MM1,[R8]
        PSLLW     MM2,8

{$IFNDEF FPC}
        MOV       RAX,bias_ptr
{$ELSE}
        MOV       RAX,[RIP+bias_ptr] // XXX : Enabling PIC by relative offsetting for x64
{$ENDIF}

        PADDW     MM2,[RAX]
        PADDW     MM1,MM2
        PSRLW     MM1,8
        PACKUSWB  MM1,MM0
        MOVD      [RDX],MM1

@1:     RET

@2:     MOV       [RDX],RCX
{$ENDIF}
end;

function M_BlendReg(F, B: TColor32): TColor32; {$IFDEF FPC} assembler; nostackframe; {$ENDIF}
asm
  // blend foregrownd color (F) to a background color (B),
  // using alpha channel value of F
  // EAX <- F
  // EDX <- B
  // Result := Fa * (Frgb - Brgb) + Brgb
{$IFDEF TARGET_x86}
  // EAX <- F
  // EDX <- B
  // Result := Fa * (Frgb - Brgb) + Brgb
        {$IFDEF FPC}
        MOVD      MM0,EAX
        PXOR      MM3,MM3
        MOVD      MM2,EDX
        PUNPCKLBW MM0,MM3
        MOV       ECX,bias_ptr
        PUNPCKLBW MM2,MM3
        MOVQ      MM1,MM0
        PUNPCKHWD MM1,MM1
        PSUBW     MM0,MM2
        PUNPCKHDQ MM1,MM1
        PSLLW     MM2,8
        PMULLW    MM0,MM1
        PADDW     MM2,[ECX]
        PADDW     MM2,MM0
        PSRLW     MM2,8
        PACKUSWB  MM2,MM3
        MOVD      EAX,MM2
        {$ELSE} // needs to work in D6 so use db
        db $0F,$6E,$C0           /// MOVD      MM0,EAX
        db $0F,$EF,$DB           /// PXOR      MM3,MM3
        db $0F,$6E,$D2           /// MOVD      MM2,EDX
        db $0F,$60,$C3           /// PUNPCKLBW MM0,MM3
        MOV     ECX,bias_ptr
        db $0F,$60,$D3           /// PUNPCKLBW MM2,MM3
        db $0F,$6F,$C8           /// MOVQ      MM1,MM0
        db $0F,$69,$C9           /// PUNPCKHWD MM1,MM1
        db $0F,$F9,$C2           /// PSUBW     MM0,MM2
        db $0F,$6A,$C9           /// PUNPCKHDQ MM1,MM1
        db $0F,$71,$F2,$08       /// PSLLW     MM2,8
        db $0F,$D5,$C1           /// PMULLW    MM0,MM1
        db $0F,$FD,$11           /// PADDW     MM2,[ECX]
        db $0F,$FD,$D0           /// PADDW     MM2,MM0
        db $0F,$71,$D2,$08       /// PSRLW     MM2,8
        db $0F,$67,$D3           /// PACKUSWB  MM2,MM3
        db $0F,$7E,$D0           /// MOVD      EAX,MM2
        {$ENDIF}
{$ENDIF}

{$IFDEF TARGET_x64}
  // ECX <- F
  // EDX <- B
  // Result := Fa * (Frgb - Brgb) + Brgb
        MOVD      MM0,ECX
        PXOR      MM3,MM3
        MOVD      MM2,EDX
        PUNPCKLBW MM0,MM3
{$IFNDEF FPC}
        MOV       RAX,bias_ptr
{$ELSE}
        MOV       RAX,[RIP+bias_ptr] // XXX : Enabling PIC by relative offsetting for x64
{$ENDIF}
        PUNPCKLBW MM2,MM3
        MOVQ      MM1,MM0
        PUNPCKHWD MM1,MM1
        PSUBW     MM0,MM2
        PUNPCKHDQ MM1,MM1
        PSLLW     MM2,8
        PMULLW    MM0,MM1
        PADDW     MM2,[RAX]
        PADDW     MM2,MM0
        PSRLW     MM2,8
        PACKUSWB  MM2,MM3
        MOVD      EAX,MM2
{$ENDIF}
end;

{$IFDEF TARGET_x86}

procedure M_BlendMem(F: TColor32; var B: TColor32); {$IFDEF FPC} assembler; nostackframe; {$ENDIF}
asm
  // EAX - Color X
  // [EDX] - Color Y
  // Result := W * (X - Y) + Y

        TEST      EAX,$FF000000
        JZ        @1
        CMP       EAX,$FF000000
        JNC       @2

        db $0F,$EF,$DB           /// PXOR      MM3,MM3
        db $0F,$6E,$C0           /// MOVD      MM0,EAX
        db $0F,$6E,$12           /// MOVD      MM2,[EDX]
        db $0F,$60,$C3           /// PUNPCKLBW MM0,MM3
        MOV       ECX,bias_ptr
        db $0F,$60,$D3           /// PUNPCKLBW MM2,MM3
        db $0F,$6F,$C8           /// MOVQ      MM1,MM0
        db $0F,$69,$C9           /// PUNPCKHWD MM1,MM1
        db $0F,$F9,$C2           /// PSUBW     MM0,MM2
        db $0F,$6A,$C9           /// PUNPCKHDQ MM1,MM1
        db $0F,$71,$F2,$08       /// PSLLW     MM2,8
        db $0F,$D5,$C1           /// PMULLW    MM0,MM1
        db $0F,$FD,$11           /// PADDW     MM2,[ECX]
        db $0F,$FD,$D0           /// PADDW     MM2,MM0
        db $0F,$71,$D2,$08       /// PSRLW     MM2,8
        db $0F,$67,$D3           /// PACKUSWB  MM2,MM3
        db $0F,$7E,$12           /// MOVD      [EDX],MM2
@1:     RET

@2:     MOV       [EDX],EAX
end;

function M_BlendRegEx(F, B, M: TColor32): TColor32; {$IFDEF FPC} assembler; nostackframe; {$ENDIF}
asm
  // blend foregrownd color (F) to a background color (B),
  // using alpha channel value of F
  // EAX <- F
  // EDX <- B
  // ECX <- M
  // Result := M * Fa * (Frgb - Brgb) + Brgb
        PUSH      EBX
        MOV       EBX,EAX
        SHR       EBX,24
        INC       ECX             // 255:256 range bias
        IMUL      ECX,EBX
        SHR       ECX,8
        JZ        @1

        db $0F,$EF,$C0           /// PXOR      MM0,MM0
        db $0F,$6E,$C8           /// MOVD      MM1,EAX
        SHL       ECX,3
        db $0F,$6E,$D2           /// MOVD      MM2,EDX
        db $0F,$60,$C8           /// PUNPCKLBW MM1,MM0
        db $0F,$60,$D0           /// PUNPCKLBW MM2,MM0
        ADD       ECX,alpha_ptr
        db $0F,$F9,$CA           /// PSUBW     MM1,MM2
        db $0F,$D5,$09           /// PMULLW    MM1,[ECX]
        db $0F,$71,$F2,$08       /// PSLLW     MM2,8
        MOV       ECX,bias_ptr
        db $0F,$FD,$11           /// PADDW     MM2,[ECX]
        db $0F,$FD,$CA           /// PADDW     MM1,MM2
        db $0F,$71,$D1,$08       /// PSRLW     MM1,8
        db $0F,$67,$C8           /// PACKUSWB  MM1,MM0
        db $0F,$7E,$C8           /// MOVD      EAX,MM1

        POP       EBX
        RET

@1:     MOV       EAX,EDX
        POP       EBX
end;

{$ENDIF}

procedure M_BlendMemEx(F: TColor32; var B:TColor32; M: TColor32); {$IFDEF FPC} assembler; nostackframe; {$ENDIF}
asm
{$IFDEF TARGET_x86}
  // blend foregrownd color (F) to a background color (B),
  // using alpha channel value of F
  // EAX <- F
  // [EDX] <- B
  // ECX <- M
  // Result := M * Fa * (Frgb - Brgb) + Brgb
        TEST      EAX,$FF000000
        JZ        @2

        PUSH      EBX
        MOV       EBX,EAX
        SHR       EBX,24
        INC       ECX             // 255:256 range bias
        IMUL      ECX,EBX
        SHR       ECX,8
        JZ        @1

        db $0F,$EF,$C0           /// PXOR      MM0,MM0
        db $0F,$6E,$C8           /// MOVD      MM1,EAX
        SHL       ECX,3
        db $0F,$6E,$12           /// MOVD      MM2,[EDX]
        db $0F,$60,$C8           /// PUNPCKLBW MM1,MM0
        db $0F,$60,$D0           /// PUNPCKLBW MM2,MM0
        ADD       ECX,alpha_ptr
        db $0F,$F9,$CA           /// PSUBW     MM1,MM2
        db $0F,$D5,$09           /// PMULLW    MM1,[ECX]
        db $0F,$71,$F2,$08       /// PSLLW     MM2,8
        MOV       ECX,bias_ptr
        db $0F,$FD,$11           /// PADDW     MM2,[ECX]
        db $0F,$FD,$CA           /// PADDW     MM1,MM2
        db $0F,$71,$D1,$08       /// PSRLW     MM1,8
        db $0F,$67,$C8           /// PACKUSWB  MM1,MM0
        db $0F,$7E,$0A           /// MOVD      [EDX],MM1
@1:     POP       EBX
@2:
{$ENDIF}

{$IFDEF TARGET_x64}
  // blend foreground color (F) to a background color (B),
  // using alpha channel value of F
  // ECX <- F
  // [EDX] <- B
  // R8 <- M
  // Result := M * Fa * (Frgb - Brgb) + Brgb
        TEST      ECX,$FF000000
        JZ        @1

        MOV       EAX,ECX
        SHR       EAX,24
        INC       R8D             // 255:256 range bias
        IMUL      R8D,EAX
        SHR       R8D,8
        JZ        @1

        PXOR      MM0,MM0
        MOVD      MM1,ECX
        SHL       R8D,4
        MOVD      MM2,[RDX]
        PUNPCKLBW MM1,MM0
        PUNPCKLBW MM2,MM0
{$IFNDEF FPC}
        ADD       R8,alpha_ptr
{$ELSE}
        ADD       R8,[RIP+alpha_ptr]
{$ENDIF}
        PSUBW     MM1,MM2
        PMULLW    MM1,[R8]
        PSLLW     MM2,8
{$IFNDEF FPC}
        MOV       RAX,bias_ptr
{$ELSE}
        MOV       RAX,[RIP+bias_ptr] // XXX : Enabling PIC by relative offsetting for x64
{$ENDIF}
        PADDW     MM2,[RAX]
        PADDW     MM1,MM2
        PSRLW     MM1,8
        PACKUSWB  MM1,MM0
        MOVD      [RDX],MM1

@1:
{$ENDIF}
end;

{$IFDEF TARGET_x86}

procedure M_BlendLine(Src, Dst: PColor32; Count: Integer); {$IFDEF FPC} assembler; nostackframe; {$ENDIF}
asm
  // EAX <- Src
  // EDX <- Dst
  // ECX <- Count

  // test the counter for zero or negativity
        TEST      ECX,ECX
        JS        @4

        PUSH      ESI
        PUSH      EDI

        MOV       ESI,EAX         // ESI <- Src
        MOV       EDI,EDX         // EDI <- Dst

  // loop start
@1:     MOV       EAX,[ESI]
        TEST      EAX,$FF000000
        JZ        @3              // complete transparency, proceed to next point
        CMP       EAX,$FF000000
        JNC       @2              // opaque pixel, copy without blending

  // blend
        db $0F,$6E,$C0           /// MOVD      MM0,EAX
        db $0F,$EF,$DB           /// PXOR      MM3,MM3
        db $0F,$6E,$17           /// MOVD      MM2,[EDI]
        db $0F,$60,$C3           /// PUNPCKLBW MM0,MM3
        MOV       EAX,bias_ptr
        db $0F,$60,$D3           /// PUNPCKLBW MM2,MM3
        db $0F,$6F,$C8           /// MOVQ      MM1,MM0
        db $0F,$69,$C9           /// PUNPCKHWD MM1,MM1
        db $0F,$F9,$C2           /// PSUBW     MM0,MM2
        db $0F,$6A,$C9           /// PUNPCKHDQ MM1,MM1
        db $0F,$71,$F2,$08       /// PSLLW     MM2,8
        db $0F,$D5,$C1           /// PMULLW    MM0,MM1
        db $0F,$FD,$10           /// PADDW     MM2,[EAX]
        db $0F,$FD,$D0           /// PADDW     MM2,MM0
        db $0F,$71,$D2,$08       /// PSRLW     MM2,8
        db $0F,$67,$D3           /// PACKUSWB  MM2,MM3
        db $0F,$7E,$D0           /// MOVD      EAX,MM2

@2:     MOV       [EDI],EAX

@3:     ADD       ESI,4
        ADD       EDI,4

  // loop end
        DEC       ECX
        JNZ       @1

        POP       EDI
        POP       ESI

@4:     RET
end;

procedure M_BlendLineEx(Src, Dst: PColor32; Count: Integer; M: TColor32);
asm
  // EAX <- Src
  // EDX <- Dst
  // ECX <- Count

  // test the counter for zero or negativity
        TEST      ECX,ECX
        JS        @4

        PUSH      ESI
        PUSH      EDI
        PUSH      EBX

        MOV       ESI,EAX         // ESI <- Src
        MOV       EDI,EDX         // EDI <- Dst
        MOV       EDX,M           // EDX <- Master Alpha

  // loop start
@1:     MOV       EAX,[ESI]
        TEST      EAX,$FF000000
        JZ        @3             // complete transparency, proceed to next point
        MOV       EBX,EAX
        SHR       EBX,24
        INC       EBX            // 255:256 range bias
        IMUL      EBX,EDX
        SHR       EBX,8
        JZ        @3              // complete transparency, proceed to next point

  // blend
        db $0F,$EF,$C0           /// PXOR      MM0,MM0
        db $0F,$6E,$C8           /// MOVD      MM1,EAX
        SHL       EBX,3
        db $0F,$6E,$17           /// MOVD      MM2,[EDI]
        db $0F,$60,$C8           /// PUNPCKLBW MM1,MM0
        db $0F,$60,$D0           /// PUNPCKLBW MM2,MM0
        ADD       EBX,alpha_ptr
        db $0F,$F9,$CA           /// PSUBW     MM1,MM2
        db $0F,$D5,$0B           /// PMULLW    MM1,[EBX]
        db $0F,$71,$F2,$08       /// PSLLW     MM2,8
        MOV       EBX,bias_ptr
        db $0F,$FD,$13           /// PADDW     MM2,[EBX]
        db $0F,$FD,$CA           /// PADDW     MM1,MM2
        db $0F,$71,$D1,$08       /// PSRLW     MM1,8
        db $0F,$67,$C8           /// PACKUSWB  MM1,MM0
        db $0F,$7E,$C8           /// MOVD      EAX,MM1

@2:     MOV       [EDI],EAX

@3:     ADD       ESI,4
        ADD       EDI,4

  // loop end
        DEC       ECX
        JNZ       @1

        POP       EBX
        POP       EDI
        POP       ESI
@4:
end;

{$ENDIF}

{ Merge }

function _MergeReg(F, B: TColor32): TColor32;
var
  Fa, Fr, Fg, Fb: Byte;
  Ba, Br, Bg, Bb: Byte;
  Ra, Rr, Rg, Rb: Byte;
  InvRa: Integer;
begin
  Fa := F shr 24;
  if Fa = $FF then
  begin
    Result := F;
    exit;
  end
  else if Fa = 0 then
  begin
    Result := B;
    Exit;
  end;

  Ba := B shr 24;
  if Ba = 0 then
  begin
    Result := F;
    exit;
  end;

  // Blended pixels
  Fr := F shr 16;  Fg := F shr 8;  Fb := F;
  Br := B shr 16;  Bg := B shr 8;  Bb := B;
  Ra := Fa + Ba - (Fa * Ba) div 255;
  InvRa := (256 * 256) div Ra;
  Br := Br * Ba shr 8;
  Rr := (Fa * (Fr - Br) shr 8 + Br) * InvRa shr 8;
  Bg := Bg * Ba shr 8;
  Rg := (Fa * (Fg - Bg) shr 8 + Bg) * InvRa shr 8;
  Bb := Bb * Ba shr 8;
  Rb := (Fa * (Fb - Bb) shr 8 + Bb) * InvRa shr 8;
  Result := Ra shl 24 + Rr shl 16 + Rg shl 8 + Rb;
end;

procedure _MergeMem(F: TColor32; var B:TColor32);
begin
  B := _MergeReg(F, B);
end;

function _MergeRegEx(F, B, M: TColor32): TColor32;
var
  Fa, Fr, Fg, Fb: Byte;
  Ba, Br, Bg, Bb: Byte;
  Ra, Rr, Rg, Rb: Byte;
  InvRa: Integer;
begin
  Fa := F shr 24;
  if Fa = 255 then
  begin
    if M = 255 then
    begin
      Result := F;
      Exit;
    end
    else if M = 0 then
    begin
      Result := B;
      Exit;
    end;
  end
  else if Fa = 0 then
  begin
    Result := B;
    Exit;
  end;

  Fa := (Fa * M) div 255;
  // Create F, but now with correct Alpha
  F := F and $00FFFFFF or Fa shl 24;
  if Fa = $FF then
  begin
    Result := F;
    Exit;
  end;
  Ba := B shr 24;
  if Ba = 0 then
  begin
    Result := F;
    Exit;
  end;

  // Blended pixels
  Fr := F shr 16;  Fg := F shr 8;  Fb := F;
  Br := B shr 16;  Bg := B shr 8;  Bb := B;
  Ra := Fa + Ba - (Fa * Ba) div 255;
  InvRa := (256 * 256) div Ra;
  Br := Br * Ba shr 8;
  Rr := (Fa * (Fr - Br) shr 8 + Br) * InvRa shr 8;
  Bg := Bg * Ba shr 8;
  Rg := (Fa * (Fg - Bg) shr 8 + Bg) * InvRa shr 8;
  Bb := Bb * Ba shr 8;
  Rb := (Fa * (Fb - Bb) shr 8 + Bb) * InvRa shr 8;
  Result := Ra shl 24 + Rr shl 16 + Rg shl 8 + Rb;
end;

procedure _MergeMemEx(F: TColor32; var B:TColor32; M: TColor32);
begin
  B := _MergeRegEx(F, B, M);
end;

procedure _MergeLine(Src, Dst: PColor32; Count: Integer);
begin
  while Count > 0 do
  begin
    Dst^ := _MergeReg(Src^, Dst^);
    Inc(Src);
    Inc(Dst);
    Dec(Count);
  end;
end;

procedure _MergeLineEx(Src, Dst: PColor32; Count: Integer; M: TColor32);
begin
  while Count > 0 do
  begin
    Dst^ := _MergeRegEx(Src^, Dst^, M);
    Inc(Src);
    Inc(Dst);
    Dec(Count);
  end;
end;

function _CombMergeReg(X, Y, W: TColor32): TColor32;
begin
  Result := _MergeReg(X and $00FFFFFF or W shl 24, Y);
end;

procedure _CombMergeMem(X: TColor32; var Y: TColor32; W: TColor32);
begin
  Y := _MergeReg(X and $00FFFFFF or W shl 24, Y);
end;

{ MMX Merge }
{$IFDEF TARGET_x86}

function M_MergeReg(F, B: TColor32): TColor32;
asm
  { This is an implementation of the merge formula, as described
    in a paper by Bruce Wallace in 1981. Merging is associative,
    that is, A over (B over C) = (A over B) over C. The formula is,

      Ra = Fa + Ba - Fa * Ba
      Rc = (Fa (Fc - Bc * Ba) + Bc * Ba) / Ra

    where

      Rc is the resultant color,  Ra is the resultant alpha,
      Fc is the foreground color, Fa is the foreground alpha,
      Bc is the background color, Ba is the background alpha.
  }

        TEST      EAX,$FF000000  // foreground completely transparent =>
        JZ        @1             // result = background
        TEST      EDX,$FF000000  // background completely transparent =>
        JZ        @2             // result = foreground
        CMP       EAX,$FF000000  // foreground completely opaque =>
        JNC       @2             // result = foreground

        db $0F,$EF,$DB           /// PXOR      MM3,MM3
        PUSH      ESI
        db $0F,$6E,$C0           /// MOVD      MM0,EAX        // MM0  <-  Fa Fr Fg Fb
        db $0F,$60,$C3           /// PUNPCKLBW MM0,MM3        // MM0  <-  00 Fa 00 Fr 00 Fg 00 Fb
        db $0F,$6E,$CA           /// MOVD      MM1,EDX        // MM1  <-  Ba Br Bg Bb
        db $0F,$60,$CB           /// PUNPCKLBW MM1,MM3        // MM1  <-  00 Ba 00 Br 00 Bg 00 Bb
        SHR       EAX,24         // EAX  <-  00 00 00 Fa
        db $0F,$6F,$E0           /// MOVQ      MM4,MM0        // MM4  <-  00 Fa 00 Fr 00 Fg 00 Fb
        SHR       EDX,24         // EDX  <-  00 00 00 Ba
        db $0F,$6F,$E9           /// MOVQ      MM5,MM1        // MM5  <-  00 Ba 00 Br 00 Bg 00 Bb
        MOV       ECX,EAX        // ECX  <-  00 00 00 Fa
        db $0F,$69,$E4           /// PUNPCKHWD MM4,MM4        // MM4  <-  00 Fa 00 Fa 00 Fg 00 Fg
        ADD       ECX,EDX        // ECX  <-  00 00 Sa Sa
        db $0F,$6A,$E4           /// PUNPCKHDQ MM4,MM4        // MM4  <-  00 Fa 00 Fa 00 Fa 00 Fa
        MUL       EDX            // EAX  <-  00 00 Pa **
        db $0F,$69,$ED           /// PUNPCKHWD MM5,MM5        // MM5  <-  00 Ba 00 Ba 00 Bg 00 Bg
        MOV       ESI,$FF        // ESI  <-  00 00 00 00 FF
        db $0F,$6A,$ED           /// PUNPCKHDQ MM5,MM5        // MM5  <-  00 Ba 00 Ba 00 Ba 00 Ba
        DIV       ESI
        SUB       ECX,EAX        // ECX  <-  00 00 00 Ra
        MOV       EAX,$ffff
        CDQ
        db $0F,$D5,$CD           /// PMULLW    MM1,MM5        // MM1  <-  B * Ba
        db $0F,$71,$D1,$08       /// PSRLW     MM1,8
        DIV       ECX
        db $0F,$D5,$C4           /// PMULLW    MM0,MM4        // MM0  <-  F * Fa
        db $0F,$71,$D0,$08       /// PSRLW     MM0,8
        db $0F,$D5,$E1           /// PMULLW    MM4,MM1        // MM4  <-  B * Ba * Fa
        db $0F,$71,$D4,$08       /// PSRLW     MM4,8
        SHL       ECX,24
        db $0F,$DD,$C8           /// PADDUSW   MM1,MM0        // MM1  <-  B * Ba + F * Fa
        db $0F,$D9,$CC           /// PSUBUSW   MM1,MM4        // MM1  <-  B * Ba + F * Fa - B * Ba * Fa
        db $0F,$6E,$D0           /// MOVD      MM2,EAX        // MM2  <-  Qa = 1 / Ra
        db $0F,$61,$D2           /// PUNPCKLWD MM2,MM2        // MM2  <-  00 00 00 00 00 Qa 00 Qa
        db $0F,$61,$D2           /// PUNPCKLWD MM2,MM2        // MM2  <-  00 Qa 00 Qa 00 Qa 00 Qa
        db $0F,$D5,$CA           /// PMULLW    MM1,MM2
        db $0F,$71,$D1,$08       /// PSRLW     MM1,8
        db $0F,$67,$CB           /// PACKUSWB  MM1,MM3        // MM1  <-  00 00 00 00 xx Rr Rg Rb
        db $0F,$7E,$C8           /// MOVD      EAX,MM1        // EAX  <-  xx Rr Rg Rb
        AND       EAX,$00FFFFFF  // EAX  <-  00 Rr Rg Rb
        OR        EAX,ECX        // EAX  <-  Ra Rr Rg Rb
        POP ESI
        RET
@1:     MOV       EAX,EDX
@2:
end;

procedure M_MergeMem(F: TColor32; var B:TColor32);
begin
  B := M_MergeReg(F, B);
end;

function M_MergeRegEx(F, B, M: TColor32): TColor32;
begin
  Result := M_MergeReg(F and $00FFFFFF or ((F shr 24) * M) div 255 shl 24, B);
end;

procedure M_MergeMemEx(F: TColor32; var B:TColor32; M: TColor32);
begin
  B := M_MergeReg(F and $00FFFFFF or ((F shr 24) * M) div 255 shl 24, B);
end;

procedure M_MergeLine(Src, Dst: PColor32; Count: Integer);
begin
  while Count > 0 do
  begin
    Dst^ := M_MergeReg(Src^, Dst^);
    Inc(Src);
    Inc(Dst);
    Dec(Count);
  end;
end;

procedure M_MergeLineEx(Src, Dst: PColor32; Count: Integer; M: TColor32);
begin
  while Count > 0 do
  begin
    Dst^ := M_MergeReg(Src^ and $00FFFFFF or ((Src^ shr 24) * M) div 255 shl 24, Dst^);
    Inc(Src);
    Inc(Dst);
    Dec(Count);
  end;
end;

function M_CombMergeReg(X, Y, W: TColor32): TColor32;
begin
  Result := M_MergeReg(X and $00FFFFFF or W shl 24, Y);
end;

procedure M_CombMergeMem(X: TColor32; var Y: TColor32; W: TColor32);
begin
  Y := M_MergeReg(X and $00FFFFFF or W shl 24, Y);
end;
{$ENDIF}

{ Non-MMX Color algebra versions }

function _ColorAdd(C1, C2: TColor32): TColor32;
var
  r1, g1, b1, a1: Integer;
  r2, g2, b2, a2: Integer;
begin
  a1 := C1 shr 24;
  r1 := C1 and $00FF0000;
  g1 := C1 and $0000FF00;
  b1 := C1 and $000000FF;

  a2 := C2 shr 24;
  r2 := C2 and $00FF0000;
  g2 := C2 and $0000FF00;
  b2 := C2 and $000000FF;

  a1 := a1 + a2;
  r1 := r1 + r2;
  g1 := g1 + g2;
  b1 := b1 + b2;

  if a1 > $FF then a1 := $FF;
  if r1 > $FF0000 then r1 := $FF0000;
  if g1 > $FF00 then g1 := $FF00;
  if b1 > $FF then b1 := $FF;

  Result := a1 shl 24 + r1 + g1 + b1;
end;

function _ColorSub(C1, C2: TColor32): TColor32;
var
  r1, g1, b1, a1: Integer;
  r2, g2, b2, a2: Integer;
begin
  a1 := C1 shr 24;
  r1 := C1 and $00FF0000;
  g1 := C1 and $0000FF00;
  b1 := C1 and $000000FF;

  r1 := r1 shr 16;
  g1 := g1 shr 8;

  a2 := C2 shr 24;
  r2 := C2 and $00FF0000;
  g2 := C2 and $0000FF00;
  b2 := C2 and $000000FF;

  r2 := r2 shr 16;
  g2 := g2 shr 8;

  a1 := a1 - a2;
  r1 := r1 - r2;
  g1 := g1 - g2;
  b1 := b1 - b2;

  if a1 < 0 then a1 := 0;
  if r1 < 0 then r1 := 0;
  if g1 < 0 then g1 := 0;
  if b1 < 0 then b1 := 0;

  Result := a1 shl 24 + r1 shl 16 + g1 shl 8 + b1;
end;

function _ColorDiv(C1, C2: TColor32): TColor32;
var
  r1, g1, b1, a1: Integer;
  r2, g2, b2, a2: Integer;
begin
  a1 := C1 shr 24;
  r1 := (C1 and $00FF0000) shr 16;
  g1 := (C1 and $0000FF00) shr 8;
  b1 := C1 and $000000FF;

  a2 := C2 shr 24;
  r2 := (C2 and $00FF0000) shr 16;
  g2 := (C2 and $0000FF00) shr 8;
  b2 := C2 and $000000FF;

  if a1 = 0 then a1:=$FF
  else a1 := (a2 shl 8) div a1;
  if r1 = 0 then r1:=$FF
  else r1 := (r2 shl 8) div r1;
  if g1 = 0 then g1:=$FF
  else g1 := (g2 shl 8) div g1;
  if b1 = 0 then b1:=$FF
  else b1 := (b2 shl 8) div b1;

  if a1 > $FF then a1 := $FF;
  if r1 > $FF then r1 := $FF;
  if g1 > $FF then g1 := $FF;
  if b1 > $FF then b1 := $FF;

  Result := a1 shl 24 + r1 shl 16 + g1 shl 8 + b1;
end;

function _ColorModulate(C1, C2: TColor32): TColor32;
var
  r1, g1, b1, a1: Integer;
  r2, g2, b2, a2: Integer;
begin
  a1 := C1 shr 24;
  r1 := C1 and $00FF0000;
  g1 := C1 and $0000FF00;
  b1 := C1 and $000000FF;

  r1 := r1 shr 16;
  g1 := g1 shr 8;

  a2 := C2 shr 24;
  r2 := C2 and $00FF0000;
  g2 := C2 and $0000FF00;
  b2 := C2 and $000000FF;

  r2 := r2 shr 16;
  g2 := g2 shr 8;

  a1 := a1 * a2 shr 8;
  r1 := r1 * r2 shr 8;
  g1 := g1 * g2 shr 8;
  b1 := b1 * b2 shr 8;

  if a1 > 255 then a1 := 255;
  if r1 > 255 then r1 := 255;
  if g1 > 255 then g1 := 255;
  if b1 > 255 then b1 := 255;

  Result := a1 shl 24 + r1 shl 16 + g1 shl 8 + b1;
end;

function _ColorMax(C1, C2: TColor32): TColor32;
var
  r1, g1, b1, a1: TColor32;
  r2, g2, b2, a2: TColor32;
begin
  a1 := C1 shr 24;
  r1 := C1 and $00FF0000;
  g1 := C1 and $0000FF00;
  b1 := C1 and $000000FF;

  a2 := C2 shr 24;
  r2 := C2 and $00FF0000;
  g2 := C2 and $0000FF00;
  b2 := C2 and $000000FF;

  if a2 > a1 then a1 := a2;
  if r2 > r1 then r1 := r2;
  if g2 > g1 then g1 := g2;
  if b2 > b1 then b1 := b2;

  Result := a1 shl 24 + r1 + g1 + b1;
end;

function _ColorMin(C1, C2: TColor32): TColor32;
var
  r1, g1, b1, a1: TColor32;
  r2, g2, b2, a2: TColor32;
begin
  a1 := C1 shr 24;
  r1 := C1 and $00FF0000;
  g1 := C1 and $0000FF00;
  b1 := C1 and $000000FF;

  a2 := C2 shr 24;
  r2 := C2 and $00FF0000;
  g2 := C2 and $0000FF00;
  b2 := C2 and $000000FF;

  if a2 < a1 then a1 := a2;
  if r2 < r1 then r1 := r2;
  if g2 < g1 then g1 := g2;
  if b2 < b1 then b1 := b2;

  Result := a1 shl 24 + r1 + g1 + b1;
end;

function _ColorDifference(C1, C2: TColor32): TColor32;
var
  r1, g1, b1, a1: TColor32;
  r2, g2, b2, a2: TColor32;
begin
  a1 := C1 shr 24;
  r1 := C1 and $00FF0000;
  g1 := C1 and $0000FF00;
  b1 := C1 and $000000FF;

  r1 := r1 shr 16;
  g1 := g1 shr 8;

  a2 := C2 shr 24;
  r2 := C2 and $00FF0000;
  g2 := C2 and $0000FF00;
  b2 := C2 and $000000FF;

  r2 := r2 shr 16;
  g2 := g2 shr 8;

  a1 := abs(a2 - a1);
  r1 := abs(r2 - r1);
  g1 := abs(g2 - g1);
  b1 := abs(b2 - b1);

  Result := a1 shl 24 + r1 shl 16 + g1 shl 8 + b1;
end;

function _ColorExclusion(C1, C2: TColor32): TColor32;
var
  r1, g1, b1, a1: TColor32;
  r2, g2, b2, a2: TColor32;
begin
  a1 := C1 shr 24;
  r1 := C1 and $00FF0000;
  g1 := C1 and $0000FF00;
  b1 := C1 and $000000FF;

  r1 := r1 shr 16;
  g1 := g1 shr 8;

  a2 := C2 shr 24;
  r2 := C2 and $00FF0000;
  g2 := C2 and $0000FF00;
  b2 := C2 and $000000FF;

  r2 := r2 shr 16;
  g2 := g2 shr 8;

  a1 := a1 + a2 - (a1 * a2 shr 7);
  r1 := r1 + r2 - (r1 * r2 shr 7);
  g1 := g1 + g2 - (g1 * g2 shr 7);
  b1 := b1 + b2 - (b1 * b2 shr 7);

  Result := a1 shl 24 + r1 shl 16 + g1 shl 8 + b1;
end;

{ MMX Color algebra versions }

function M_ColorAdd(C1, C2: TColor32): TColor32;
asm
        db $0F,$6E,$C0           /// MOVD      MM0,EAX
        db $0F,$6E,$CA           /// MOVD      MM1,EDX
        db $0F,$DC,$C1           /// PADDUSB   MM0,MM1
        db $0F,$7E,$C0           /// MOVD      EAX,MM0
end;

function M_ColorSub(C1, C2: TColor32): TColor32;
asm
        db $0F,$6E,$C0           /// MOVD      MM0,EAX
        db $0F,$6E,$CA           /// MOVD      MM1,EDX
        db $0F,$D8,$C1           /// PSUBUSB   MM0,MM1
        db $0F,$7E,$C0           /// MOVD      EAX,MM0
end;

function M_ColorModulate(C1, C2: TColor32): TColor32;
asm
        db $0F,$EF,$D2           /// PXOR      MM2,MM2
        db $0F,$6E,$C0           /// MOVD      MM0,EAX
        db $0F,$60,$C2           /// PUNPCKLBW MM0,MM2
        db $0F,$6E,$CA           /// MOVD      MM1,EDX
        db $0F,$60,$CA           /// PUNPCKLBW MM1,MM2
        db $0F,$D5,$C1           /// PMULLW    MM0,MM1
        db $0F,$71,$D0,$08       /// PSRLW     MM0,8
        db $0F,$67,$C2           /// PACKUSWB  MM0,MM2
        db $0F,$7E,$C0           /// MOVD      EAX,MM0
end;

function M_ColorMax(C1, C2: TColor32): TColor32;
asm
        db $0F,$6E,$C0           /// MOVD      MM0,EAX
        db $0F,$6E,$CA           /// MOVD      MM1,EDX
        db $0F,$DE,$C1           /// PMAXUB    MM0,MM1
        db $0F,$7E,$C0           /// MOVD      EAX,MM0
end;

function M_ColorMin(C1, C2: TColor32): TColor32;
asm
        db $0F,$6E,$C0           /// MOVD      MM0,EAX
        db $0F,$6E,$CA           /// MOVD      MM1,EDX
        db $0F,$DA,$C1           /// PMINUB    MM0,MM1
        db $0F,$7E,$C0           /// MOVD      EAX,MM0
end;


function M_ColorDifference(C1, C2: TColor32): TColor32;
asm
        db $0F,$6E,$C0           /// MOVD      MM0,EAX
        db $0F,$6E,$CA           /// MOVD      MM1,EDX
        db $0F,$6F,$D0           /// MOVQ      MM2,MM0
        db $0F,$D8,$C1           /// PSUBUSB   MM0,MM1
        db $0F,$D8,$CA           /// PSUBUSB   MM1,MM2
        db $0F,$EB,$C1           /// POR       MM0,MM1
        db $0F,$7E,$C0           /// MOVD      EAX,MM0
end;

function M_ColorExclusion(C1, C2: TColor32): TColor32;
asm
        db $0F,$EF,$D2           /// PXOR      MM2,MM2
        db $0F,$6E,$C0           /// MOVD      MM0,EAX
        db $0F,$60,$C2           /// PUNPCKLBW MM0,MM2
        db $0F,$6E,$CA           /// MOVD      MM1,EDX
        db $0F,$60,$CA           /// PUNPCKLBW MM1,MM2
        db $0F,$6F,$D8           /// MOVQ      MM3,MM0
        db $0F,$FD,$C1           /// PADDW     MM0,MM1
        db $0F,$D5,$CB           /// PMULLW    MM1,MM3
        db $0F,$71,$D1,$07       /// PSRLW     MM1,7
        db $0F,$D9,$C1           /// PSUBUSW   MM0,MM1
        db $0F,$67,$C2           /// PACKUSWB  MM0,MM2
        db $0F,$7E,$C0           /// MOVD      EAX,MM0
end;

{ Misc stuff }

function Lighten(C: TColor32; Amount: Integer): TColor32;
var
  r, g, b, a: Integer;
begin
  a := C shr 24;
  r := C and $00FF0000;
  g := C and $0000FF00;
  b := C and $000000FF;

  r := r shr 16;
  g := g shr 8;

  Inc(r, Amount);
  Inc(g, Amount);
  Inc(b, Amount);

  if r > 255 then r := 255 else if r < 0 then r := 0;
  if g > 255 then g := 255 else if g < 0 then g := 0;
  if b > 255 then b := 255 else if b < 0 then b := 0;

  Result := a shl 24 + r shl 16 + g shl 8 + b;
end;

{ MMX Detection and linking }

procedure SetupFunctions;
begin
  MMX_ACTIVE := HasMMX;
  if MMX_ACTIVE then
  begin
    // link MMX functions
    CombineReg := M_CombineReg;
    CombineMem := M_CombineMem;
    BlendReg := M_BlendReg;
    {$IFDEF TARGET_x86}
    BlendMem := M_BlendMem;
    BlendRegEx := M_BlendRegEx;
    BlendMemEx := M_BlendMemEx;
    BlendLine := M_BlendLine;
    BlendLineEx := M_BlendLineEx;

    CombMergeReg := M_CombMergeReg;
    CombMergeMem := M_CombMergeMem;
    MergeReg := M_MergeReg;
    MergeMem := M_MergeMem;
    MergeRegEx := M_MergeRegEx;
    MergeMemEx := M_MergeMemEx;
    MergeLine := M_MergeLine;
    MergeLineEx := M_MergeLineEx;

    BLEND_MEM[cmBlend] := M_BlendMem;
    BLEND_MEM[cmMerge] := M_MergeMem;
    BLEND_REG[cmBlend] := M_BlendReg;
    BLEND_REG[cmMerge] := M_MergeReg;
    COMBINE_MEM[cmBlend] := M_CombineMem;
    COMBINE_MEM[cmMerge] := M_CombMergeMem;
    COMBINE_REG[cmBlend] := M_CombineReg;
    COMBINE_REG[cmMerge] := M_CombMergeReg;
    BLEND_MEM_EX[cmBlend] := M_BlendMemEx;
    BLEND_MEM_EX[cmMerge] := M_MergeMemEx;
    BLEND_REG_EX[cmBlend] := M_BlendRegEx;
    BLEND_REG_EX[cmMerge] := M_MergeRegEx;
    BLEND_LINE[cmBlend] := M_BlendLine;
    BLEND_LINE[cmMerge] := M_MergeLine;
    BLEND_LINE_EX[cmBlend] := M_BlendLineEx;
    BLEND_LINE_EX[cmMerge] := M_MergeLineEx;
    {$ENDIF}

    {$IFDEF TARGET_x64}
    BlendMem := _BlendMem;
    BlendRegEx := _BlendRegEx;
    BlendMemEx := _BlendMemEx;
    BlendLine := _BlendLine;
    BlendLineEx := _BlendLineEx;

    CombMergeReg := _CombMergeReg;
    CombMergeMem := _CombMergeMem;
    MergeReg := _MergeReg;
    MergeMem := _MergeMem;
    MergeRegEx := _MergeRegEx;
    MergeMemEx := _MergeMemEx;
    MergeLine := _MergeLine;
    MergeLineEx := _MergeLineEx;

    BLEND_MEM[cmBlend] := _BlendMem;
    BLEND_MEM[cmMerge] := _MergeMem;
    BLEND_REG[cmBlend] := _BlendReg;
    BLEND_REG[cmMerge] := _MergeReg;
    COMBINE_MEM[cmBlend] := _CombineMem;
    COMBINE_MEM[cmMerge] := _CombMergeMem;
    COMBINE_REG[cmBlend] := _CombineReg;
    COMBINE_REG[cmMerge] := _CombMergeReg;
    BLEND_MEM_EX[cmBlend] := _BlendMemEx;
    BLEND_MEM_EX[cmMerge] := _MergeMemEx;
    BLEND_REG_EX[cmBlend] := _BlendRegEx;
    BLEND_REG_EX[cmMerge] := _MergeRegEx;
    BLEND_LINE[cmBlend] := _BlendLine;
    BLEND_LINE[cmMerge] := _MergeLine;
    BLEND_LINE_EX[cmBlend] := _BlendLineEx;
    BLEND_LINE_EX[cmMerge] := _MergeLineEx;
    {$ENDIF}

    ColorAdd := M_ColorAdd;
    ColorSub := M_ColorSub;
    ColorDiv := _ColorDiv;
    ColorModulate := M_ColorModulate;
    ColorMax := M_ColorMax;
    ColorMin := M_ColorMin;
    ColorDifference := M_ColorDifference;
    ColorExclusion := M_ColorExclusion;
  end
  else
  begin
    // link non-MMX functions
    CombineReg := _CombineReg;
    CombineMem := _CombineMem;
    BlendReg := _BlendReg;
    BlendMem := _BlendMem;
    BlendRegEx := _BlendRegEx;
    BlendMemEx := _BlendMemEx;
    BlendLine := _BlendLine;
    BlendLineEx := _BlendLineEx;

    CombMergeReg := _CombMergeReg;
    CombMergeMem := _CombMergeMem;
    MergeReg := _MergeReg;
    MergeMem := _MergeMem;
    MergeRegEx := _MergeRegEx;
    MergeMemEx := _MergeMemEx;
    MergeLine := _MergeLine;
    MergeLineEx := _MergeLineEx;

    BLEND_MEM[cmBlend] := _BlendMem;
    BLEND_MEM[cmMerge] := _MergeMem;
    BLEND_REG[cmBlend] := _BlendReg;
    BLEND_REG[cmMerge] := _MergeReg;
    COMBINE_MEM[cmBlend] := _CombineMem;
    COMBINE_MEM[cmMerge] := _CombMergeMem;
    COMBINE_REG[cmBlend] := _CombineReg;
    COMBINE_REG[cmMerge] := _CombMergeReg;
    BLEND_MEM_EX[cmBlend] := _BlendMemEx;
    BLEND_MEM_EX[cmMerge] := _MergeMemEx;
    BLEND_REG_EX[cmBlend] := _BlendRegEx;
    BLEND_REG_EX[cmMerge] := _MergeRegEx;
    BLEND_LINE[cmBlend] := _BlendLine;
    BLEND_LINE[cmMerge] := _MergeLine;
    BLEND_LINE_EX[cmBlend] := _BlendLineEx;
    BLEND_LINE_EX[cmMerge] := _MergeLineEx;

    ColorAdd := _ColorAdd;
    ColorSub := _ColorSub;
    ColorDiv := _ColorDiv;
    ColorModulate := _ColorModulate;
    ColorMax := _ColorMax;
    ColorMin := _ColorMin;
    ColorDifference := _ColorDifference;
    ColorExclusion := _ColorExclusion;
  end;
end;

initialization
  SetupFunctions;
  if MMX_ACTIVE then GenAlphaTable;

finalization
  if MMX_ACTIVE then FreeAlphaTable;

end.



