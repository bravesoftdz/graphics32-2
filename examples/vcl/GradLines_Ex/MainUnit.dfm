object Form1: TForm1
  Left = 220
  Top = 105
  BorderStyle = bsDialog
  Caption = 'Graphics32 Demo: (TPaintBox32 & DrawLineFSP)'
  ClientHeight = 316
  ClientWidth = 402
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 320
    Top = 88
    Width = 28
    Height = 13
    Caption = 'Total:'
  end
  object PaintBox: TPaintBox32
    Left = 8
    Top = 8
    Width = 300
    Height = 300
    TabOrder = 0
  end
  object Button1: TButton
    Left = 320
    Top = 8
    Width = 73
    Height = 21
    Caption = 'Add One'
    TabOrder = 1
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 320
    Top = 34
    Width = 73
    Height = 21
    Caption = 'Add Ten'
    TabOrder = 2
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 320
    Top = 60
    Width = 73
    Height = 21
    Caption = 'Clear'
    TabOrder = 3
    OnClick = Button3Click
  end
  object RadioGroup1: TRadioGroup
    Left = 320
    Top = 216
    Width = 73
    Height = 89
    Caption = 'Fade'
    Ctl3D = True
    ItemIndex = 1
    Items.Strings = (
      'None'
      'Slow'
      'Fast')
    ParentCtl3D = False
    TabOrder = 4
    OnClick = RadioGroup1Click
  end
  object RadioGroup2: TRadioGroup
    Left = 320
    Top = 128
    Width = 73
    Height = 81
    Caption = 'Draw'
    Ctl3D = True
    ItemIndex = 0
    Items.Strings = (
      'Slow'
      'Normal'
      'Fast')
    ParentCtl3D = False
    TabOrder = 5
    OnClick = RadioGroup2Click
  end
  object Panel1: TPanel
    Left = 320
    Top = 104
    Width = 73
    Height = 17
    BevelOuter = bvNone
    BorderStyle = bsSingle
    Caption = '0'
    Color = clWindow
    Ctl3D = False
    ParentCtl3D = False
    TabOrder = 6
  end
end
