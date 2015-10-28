
CON

    _CLKMODE                = xtal2 + pll8x
    _XINFREQ                = 10_000_000 + 0000

VAR
    BYTE Screen[6912]
  
OBJ
    ULA : "ULA_TV"


PUB Start

    ULA.Start(@Screen, 0)
    WritePattern

PUB WritePattern | x, y

    repeat y from 3 to 20
        repeat x from 0 to 31
            ' Write a letter 'A' to the (x, y) character cell
            Screen[32*(8*y+0) + x] := $00
            Screen[32*(8*y+1) + x] := $3C
            Screen[32*(8*y+2) + x] := $42
            Screen[32*(8*y+3) + x] := $42
            Screen[32*(8*y+4) + x] := $7E
            Screen[32*(8*y+5) + x] := $42
            Screen[32*(8*y+6) + x] := $42 
            Screen[32*(8*y+7) + x] := $00

    ' Write a color pattern to the attribute area
    repeat y from 0 to 15
        repeat x from 0 to 31
            Screen[6144 + 32*(y+4) + x] := (y & $07) | ((y << 4) & $80)

    repeat y from 0 to 2
        repeat x from 0 to 31
            Screen[6144 + 32*y + x] := %00111000

    repeat y from 21 to 23
        repeat x from 0 to 31
            Screen[6144 + 32*y + x] := %00111000       