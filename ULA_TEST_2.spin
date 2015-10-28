CON

    _CLKMODE                = xtal2 + pll8x
    _XINFREQ                = 10_000_000 + 0000

DAT
    Screen  file "RoboCop.scr"
 

OBJ
    ULA: "ULA_TV"

PUB Start

    ULA.Start(@Screen, 1)
  
  ' Uncomment the following code to see a simulated loading screen :-)
  

    repeat
        repeat 2000
            ULA.SetBorderColor(2)
            waitcnt(45_000 + cnt)
            ULA.SetBorderColor(5)
            waitcnt(40_000 + cnt)
        repeat 15000
            ULA.SetBorderColor(9)
            waitcnt(20_000 + cnt)
            ULA.SetBorderColor(1)
            waitcnt(20_000 + cnt)
         