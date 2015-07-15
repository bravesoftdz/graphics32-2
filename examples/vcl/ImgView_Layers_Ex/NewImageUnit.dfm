object NewImageForm: TNewImageForm
  Left = 282
  Top = 194
  BorderStyle = bsDialog
  Caption = 'New Image'
  ClientHeight = 194
  ClientWidth = 250
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Position = poScreenCenter
  PixelsPerInch = 96
  object Label1: TLabel
    Left = 24
    Top = 27
    Width = 32
    Height = 13
    Caption = 'Width:'
    FocusControl = ImageWidth
  end
  object Label2: TLabel
    Left = 24
    Top = 67
    Width = 35
    Height = 13
    Caption = 'Height:'
    FocusControl = ImageHeight
  end
  object Label3: TLabel
    Left = 200
    Top = 27
    Width = 27
    Height = 13
    Caption = 'pixels'
  end
  object Label4: TLabel
    Left = 200
    Top = 67
    Width = 27
    Height = 13
    Caption = 'pixels'
  end
  object Label5: TLabel
    Left = 24
    Top = 116
    Width = 88
    Height = 13
    Caption = 'Background Color:'
  end
  object ImageWidth: TEdit
    Left = 72
    Top = 24
    Width = 97
    Height = 21
    TabOrder = 0
    Text = '640'
  end
  object UpDown1: TUpDown
    Left = 169
    Top = 24
    Width = 18
    Height = 21
    Associate = ImageWidth
    Min = 1
    Max = 2000
    Position = 640
    TabOrder = 1
    Wrap = False
  end
  object ImageHeight: TEdit
    Left = 72
    Top = 64
    Width = 97
    Height = 21
    TabOrder = 2
    Text = '480'
  end
  object UpDown2: TUpDown
    Left = 169
    Top = 64
    Width = 18
    Height = 21
    Associate = ImageHeight
    Min = 1
    Max = 2000
    Position = 480
    TabOrder = 3
    Wrap = False
  end
  object Panel1: TPanel
    Left = 120
    Top = 112
    Width = 67
    Height = 21
    BevelOuter = bvNone
    BorderStyle = bsSingle
    Color = clWhite
    TabOrder = 4
  end
  object Button1: TButton
    Left = 192
    Top = 112
    Width = 35
    Height = 20
    Caption = 'Select'
    TabOrder = 5
    TabStop = False
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 104
    Top = 164
    Width = 65
    Height = 22
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 6
  end
  object Button3: TButton
    Left = 176
    Top = 164
    Width = 65
    Height = 22
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 7
  end
  object ColorDialog1: TColorDialog
    Color = clWhite
    Left = 196
    Top = 132
  end
end
