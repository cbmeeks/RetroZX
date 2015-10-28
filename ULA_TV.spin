{==============================================================================}
{                NTSC Spectrum-like TV Video Driver                            }
{==============================================================================}
{
  Version story:
  
      2007-12-05  1.0  First version                       (José Luis Cebrián)
      2015-10-15  Fork from original for enhancments                   cbmeeks
}   
{------------------------------------------------------------------------------}
{
  This code is in the public domain. Feel free to use it in any way you like.

  This driver simulates the screen layout of a Sinclair ZX Spectrum: 
  256x192 pixels with 15 different colors, all in less than 7K of RAM memory.
  It also has the famous 'attribute clash' effect, because each group of 8x8
  pixels can only show two different colors.  
      TODO  I hope to add additional modes that will enable fewer clashes ~cbm

  Known bugs:
    • NTSC frames are not well implemented: on my LCD I get a "jumping up-down"
      problem that seems to be related to V-Sync timings. This can be solved by
      removing the NTSC half-line, but then the color gets all messed up.

  Potential enhancements:
    • PAL version
    • Create a graphics driver to draw text or graphics primitives to screen
    • Enhanced mode with full-color sprites or other features
    • 160x192 color mode (16x4 colors from propeller)
    • Scrolling and/or page flipping
    • Dedicated memory area in propeller to be used for fast blits, chars, etc.
      The CPU could send data to an address to "load" values for later.  This
      would be slow during the loading, but the propeller could then blast 
      this data to the screen super fast without any CPU intervention.  Useful
      for things like graphics in the borders, giant sprites that never move, etc.
    • Enhanced mode that is similar to basic mode but with fewer attribute 
      clashes.  Something like 8x4 area.  Need a way to optimize this so that
      attribute data doesn't get large.
    • Ideas for various new modes (and tweaks to existing):

        Mode 0: Normal, default mode.  Interleaved graphics and all.  :-)
                However, these enhancements are available:
                • Left border width is user definable (right side auto-adjusts)
                  up to a limit.
                    TODO: 
                      • Confirm timing issues with legacy software)
                      • Determine practical limits
                • User definable flash delay

        Mode 1: Same as Mode 0 with a few exceptions.
                • Memory is linear not interleaved.
                • Palette is user definable (same number of colors)

        Mode 2: Same as Mode 1 with these additional features:
                • Attribute clash is now 8x4

        Mode 3: Same as Mode 1 with these additional features:
                • Screen resolution is still 256x192 but page resolution is
                  512x192 with the X offset any pixel between 0 and 255 allowing
                  smooth horizontal scrolling
                • Uses 16x4 color mode internally to handle attribute clashes
                    TODO:
                      • Confirm memory requirements
                      • Check on artifact clashing

        Mode 4: Same as Mode 3 with these changes:
                • Page resolution is now 256x384 (vertical) with the Y offset any
                  pixel between 0 and 191 allowing smooth vertical scrolling

        Mode 5: Same as Mode 1 with these changes:
                • Screen resolution is now 160x192
                • Full bitmap, any pixel, any color (requires much more RAM)
}
{------------------------------------------------------------------------------}
{
  Screen layout description
  
  The screen space is divided in two section: first, there is a 256x192 two-color
  bitmap with the entire contents of the screen (requiring 6144 bytes). Immediately
  after it, you'll find 768 bytes of 'attributes'. Each attribute contains the color
  palette of one character cell, where each character is 8x8 in size.
  
  Each attribute byte has the following contents:
  
       7  6  5 4 3  2 1 0
      ┌─┐┌─┐┌─┬─┬─┐┌─┬─┬─┐           F:  Flash flag
      └─┘└─┘└─┴─┴─┘└─┴─┴─┘           B:  Bright flag                        
       F  B  Paper  Ink
  
  The ink (in bits 0-2) is the color for all pixels that are set to 1 in the
  screen bitmap, and the paper value is the color for pixels set to 0.
  The eight available colors come from a fixed palette:
  
              0               Black
              1               Blue
              2               Red
              3               Magenta
              4               Green
              5               Cyan
              6               Yellow
              7               White
  
  Each color has two bright levels available. If the bright flag of a character cell
  is set to 1, both ink & paper will be slighty brighter. Note that there is no way
  to mix two colors of different bright levels in the same character cell.
  
  Finally, any character with the flag bit set in its attributes will be displayed
  alternating the ink and paper colors periodically (about two times per second).
  
  The original Spectrum complicated this layout using a very strange line ordering:
  instead of storing each line one just after another in memory, the bitmap was instead
  divided in three 256*64 sub-bitmaps (or 'banks') of 2048 bytes each. Each bank 
  used a complicated line ordering where the first line of the first character row
  was followed by the first line of the *second* character row, and only after all
  the first lines of all eight rows in the bank then you'll find the second line
  of the first row of characters.
  
  This driver can simulate this ridiculous line ordering, but it also supports
  a sequential layout where each 32 bytes line in RAM is followed by the next line
  to be displayed. Activating the Spectrum screen layout allows you to load any
  .SCR file from the World of Spectrum archive (www.worldofspectrum.org) and display it,
  but if you're pretending to write your own applications I'll recommend to switch it off.
} 
 
CON
      ' Border size (192 + both borders should equal 244)
        BorderTop               = 30
        BorderBottom            = 22

        ' Border offset, to center the image (positive values move the screen to the right)
        BorderOffset            = 9

        ' Video generator configuration for NTSC
        '   • VMode          - Video mode
        '   • CMode          - Two (0) colour mode
        '   • Chroma1        - 1 to enable chroma on broadcast signal
        '   • Chroma0        - 1 to enable chroma on baseband signal
        '   • AuralSub       - Used for audio generation (not used)
        '   • VGroup         - Select pin group
        '   • Pins           - Select pin mask

                                       '  ┌─────────────────────────────────────────  VMode              
                                       '  │  ┌──────────────────────────────────────  CMode              
                                       '  │  │ ┌────────────────────────────────────  Chroma1            
                                       '  │  │ │ ┌──────────────────────────────────  Chroma0            
                                       '  │  │ │ │ ┌────────────────────────────────  AuralSub           
                                       '  │  │ │ │ │               ┌────────────────  VGroup             
                                       '  │  │ │ │ │               │     ┌──────────  Pins               
        VCFG_NTSC               =      %0_11_0_1_1_000_00000000000_001_0_01110000
         
        ' Port mask -- the pins we're outputting on
        '                                                      C    8    4    0
        PortMask                =      %0000_0000_0000_0000_0111_0000_0000_0001

        ' Counter Module Configuration
        '   • CTRMode        - Operating mode (0001 for Video Mode)
        '   • PLLDiv         - Divisor for the VCO frequency (111: use VCO value as-is)
         
                                       '┌───────────  CTRMode
                                       '│     ┌─────  PLLDiv  
        CTRA_NTSC               =      %00001_111
         
        ' NTSC Color frequency in Hz
        ' This is the 'base' clock rate for all our NTSC timings. At start, the
        ' driver will program the FRQA register to output at this rate. Our base
        ' clock value is 1/16 of the NTSC clock rate, or approximately 0.01746 µs  
        ' (0.0174603196775009) * 57,272,720 = ~1µs  (0.0174603196775009 * 57.27272000000004)
        NTSC_ClockFreq          =      3_579_545        
         
        ' NTSC Timings table
        '                                               Time        Clocks      Output                    
        '               Total horizontal timing:        63.5 µs       3637      
        '                 Horizontal blanking period:   10.9 µs        624      
        '                   Front porch:                 1.5 µs         86 *    Black ($02)
        '                   Synchronizing pulse:         4.7 µs        269 *    Blank ($00)
        '                   Back porch:                  4.7 µs        269      
        '                     Breeze away:               0.6 µs         34 *    Black ($02)
        '                     Colour burst:              2.5 µs        143 *    Y Hue ($8A)
        '                     Wait to data:              1.6 µs         92 *    Black ($02)
        '                 Visible line                  52.6 µs       3008
        '                   Left border                  3.8 µs        224 *    Black ($00)
        '                   Pixel data                  44.7 µs       2560      
        '                     Character (x32)            1.4 µs         80 *    Data         (GOOD)
        '                   Right border                 4.1 µs        224 *    Black ($00)
        '                 Half visible line ¹           20.8 µs       1192
        '
        ' Lines marked with * are the actual parts of a visible line as sent to the TV.
        '
        ' ¹ Note that NTSC requires 242.5 lines per frame. The remaining line (the "half line")
        '   should have a length of 3637/2 = 1818 clocks.  That is, a 624-clocks HSync followed
        '   by about 1194 clocks of visible data. The values used here have been fine-tuned a bit.
        VSCL_FrontPorch                         =       86
        VSCL_SynchronizingPulse                 =       269
        VSCL_BackPorch                          =       269
        VSCL_BreezeAway                         =       34
        VSCL_ColourBurst                        =       143
        VSCL_WaitToData                         =       92
        VSCL_VisibleLine                        =       3008
        VSCL_HalfLine                           =       1192                  ' NTSC Half line
        VSCL_PixelData                          =       2560        
        VSCL_LeftBorder                         =       224 + BorderOffset
        VSCL_RightBorder                        =       224 - BorderOffset
        VSCL_Character                          =       (10 << 12) + 80       ' Eight pixels
         
VAR

  long gScreenPTR
  long gSpectrumLayout
  long gBorderColor



PUB Start(pScreen, pSpectrumLayout)
  ' Starts the Spectrum TV driver and begins the output of NTSC video.
  ' Uses a Cog.
  ' 
  ' Parameters:
  '    pScreen         → Address of the 6912-bytes screen                        
  '    pSpectrumLayout → 1 to simulate the actual Spectrum's screen organization
  '                        (useful to load a .SCR file, for example)
  '                      0 to interpret the screen as a simple 2-color 192x256 bitmap
  '                        with 768 bytes of color attributes to follow                                               
  gScreenPtr        := pScreen
  gSpectrumLayout   := pSpectrumLayout
  gBorderColor      := 0

  ' TODO  Check to see if this is required if I'm using external cogs to boot
  clkset(%01101000, 12_000_000)   ' Set internal oscillator to RCFast and set PLL to start
  waitcnt(cnt + 120_000)          ' wait approx 10ms at 12mhz for PLL to 'warm up'
  clkset(%01101111, 80_000_000)   ' 80MHz (5MHz PLLx16)  

  cognew(@Entry, @gScreenPTR)


PUB SetBorderColor(pColor)
  ' Changes the border color. 
  ' Unlike the original Spectrum, bright colors are supported.
  ' 
  ' Parameters:
  '    pColor → 0 to 7  to choose a plain color
  '             8 to 15 to choose a bright color
    gBorderColor := pColor

  
DAT

              org       $000
              
Entry         jmp       #StartDriver

              ' Flags and local variables

              FlashCounter                      long 0
              FlashActive                       long 0

              ' The following increments are used to jump from the end of one line
              ' to the next one, when the Spectrum line layout is active
                            
              NextLine                          long 256  - 32
              NextRow                           long 1760 + 32
              
              ' Colors used in waitvid
              
              COLOR_SYNC                        long $00
              COLOR_BLACK                       long $02
              COLOR_YHUE                        long $8A   
              COLOR_BORDER                      long $02         ' Border color

              ' The following constants are too big to use in-place, so we need to
              ' reserve some registers to put them here

              _ScreenSize                       long 6144        ' 192 lines x 32 characters
              _VCFG_NTSC                        long VCFG_NTSC
              _PortMask                         long PortMask
              _NTSC_ClockFreq                   long NTSC_ClockFreq
              _VSCL_Character                   long VSCL_Character
              _VSCL_VisibleLine                 long VSCL_VisibleLine
              _VSCL_PixelData                   long VSCL_PixelData
              _VSCL_HalfLine                    long VSCL_HalfLine
                     
              ' 16 color palette tables
              '
              ' Those two tables are used to construct a two-colour value for the Video Generator.
              ' The first 8 longs are the colors themselves, in the appropiate position for the
              ' color (Paper at byte 0, Ink at byte 1). The next 8 entries contain the bright
              ' versions of the colors. Please note that the paper table has also set the MSB bit
              ' of those colors: this is not used by the Video Generator, but will allow the
              ' rendering loop to easily get the BRIGHT flag into the C flag in a single MOV instruction.
              ' Finally, the paper table also has two more sets of colors because the rendering loop
              ' uses a 5 bit paper (including FLASH) to spare an AND instruction.

      PALETTE_INK       long $00000200, $00000B00, $00005B00, $00003B00, $0000AB00, $0000DC00, $00008C00, $00000400
                        long $00000200, $00000C00, $00005C00, $00003C00, $0000AD00, $0000DD00, $00008D00, $00000500
      PALETTE_PAPER     long $00000002, $0000000B, $0000005B, $0000003B, $000000AB, $000000DC, $0000008C, $00000004
                        long $80000002, $8000000C, $8000005C, $8000003C, $800000AD, $800000DD, $8000008D, $80000005
                        long $00000002, $0000000B, $0000005B, $0000003B, $000000AB, $000000DC, $0000008C, $00000004
                        long $80000002, $8000000C, $8000005C, $8000003C, $800000AD, $800000DD, $8000008D, $80000005

{==============================================================================}
' Code section
{==============================================================================}
StartDriver    

        ' Configure the Cog generators
        
              mov       VCFG, _VCFG_NTSC           ' Configure the Video Generator
              mov       DIRA, _PortMask            ' Setup the port mask for DAC access
              movi      CTRA, #CTRA_NTSC           ' Setup the Counter Module Generator A

              mov       R1, _NTSC_ClockFreq        ' R1 := NTSC Clock Frequency in Hz
              rdlong    R2, #0                     ' R2 := Current CPU Clock Frequency in Hz
              call      #Divide                    ' R3 := R1 ÷ R2 (fractional part)
              mov       FRQA, R3                   ' Setup the Counter Module Generator frequency

        ' Prepare the INVBITS table
        '
        ' This table has 256 longs used to get the bit-wise 'inverse' of a number. For example,
        ' the inverse of %10110000 is %00001101. This table is needed because the VSCL expects
        ' the bits in reverse order (the less significant bit is the first one to output) 

              mov       R0, #255
:I0           mov       R1, #0
              mov       R2, #$80
              mov       R3, #$01
:I1           test      R0, R2 wz
        if_nz or        R1, R3
              shl       R3, #1
              shr       R2, #1 wz
        if_nz jmp       #:I1
:I2           mov       INVBITS + 255, R1
              shl       R3, #1             ' R3 := %100000000
              sub       :I2, R3            ' This will decrement the D field of the :I2 instruction        
              djnz      R0, #:I0
              mov       INVBITS, #0        ' Loop would leave this value untouched


{------------------------------------------------------------------------------}
' FRAME LOOP
{------------------------------------------------------------------------------}
:Frame
              mov       LineCounter, #244  ' LineCounter := Number of vertical lines
              mov       YCoord, #0         ' YCoord := Row number in graphics memory, if visible                        
              mov       CharacterRows, #8

        '     Copy the parameter block to local variables in Cog memory
        
              mov       R0, PAR                         
              rdlong    BitmapPtr, R0
              mov       AttribPtr, BitmapPtr
              add       R0, #4
              rdlong    UseSpectrumLayout, R0
              add       AttribPtr, _ScreenSize

        '     Twice per second, toggle the flash attribute processing
        
              add       FlashCounter, #1
              cmp       FlashCounter, #30 wz
        if_nz jmp       #:ScanLine
              mov       FlashCounter, #0      ' Each 30 frames, toggle the flash flag
              xor       FlashActive, #1 wz    ' and copy the Flash0 or Flash1 instruction
        if_z  mov       :Flash, Flash1        ' to the :Flash line (inside the rendering loop)
        if_nz mov       :Flash, Flash0                 

        '     First field: start with a half-line
        '     Second field: draw one line less
{              
              test      Field, #1 wc
        if_nc call      #HSync
        if_nc mov       VSCL, _VSCL_HalfLine
        if_nc waitvid   COLOR_BORDER, #0
}

{------------------------------------------------------------------------------}
' VISIBLE LINE LOOP
{------------------------------------------------------------------------------}
:ScanLine
              call      #HSync

              ' Load the border color
              ' We do this each line in order to allow the user to change it at any moment
              ' and simulate the "loading screen" colors of the original Spectrum         
              mov       R0, PAR
              add       R0, #8                ' THIRD parameter   TODO confirm this
              rdlong    R1, R0                ' R1 := Border color
              and       R1, #$0F              ' Border color is limited from 0 to 15
              add       R1, #PALETTE_PAPER
              movs      :C0, R1
              nop
:C0           mov       COLOR_BORDER, 0       ' Load the border color from the paper palette

               
              ' Check if the current line is in the top or bottom border
              cmp       LineCounter, #BorderBottom    wc
        if_c  jmp       #:EmptyLine
              cmp       LineCounter, #244 - BorderTop wc
        if_nc jmp       #:EmptyLine


              { LEFT BORDER }
              mov       VSCL, #VSCL_LeftBorder
              waitvid   COLOR_BORDER, #0


              { CHARACTER RENDERING LOOP }
              mov       VSCL, _VSCL_Character
              mov       R0, #32               ' R0 := Character counter
              mov       R1, AttribPtr         ' R1 := Pointer to attribute area
:Character    rdbyte    R2, R1                ' R2 := %FBPPPIII (Flash, Bright, Paper, Ink)
              add       R1, #1                ' Advance the attribute pointer for the next character
              mov       R4, R2                ' R4 := %FBPPPIII (Flash, Bright, Paper, Ink)
              rdbyte    R3, BitmapPtr         ' R3 := Current pixel data
              add       BitmapPtr, #1         ' Advance the pixel data pointer for the next character   
              test      R2, #$80 wz           ' Now Z carries FLASH
:Flash  if_nz xor       R3, #$FF              ' Invert the pixels if FLASH is active
              add       R3, #INVBITS          ' R3 := #INVBITS + current pixel (for the bit inversion)          
              movs      :LoadPixels, R3       ' Change the LoadPixels source to read the final pixels from INVBITS
              shr       R4, #3                ' R4 := %FBPPP (Flash, Bright, Paper)
              and       R2, #$07              ' R2 := %00III (Ink)
              add       R4, #PALETTE_PAPER    ' R4 is now the address for the paper color
              movs      :LoadPaper, R4        ' Change the LoadPaper line to read from the papers palette
              add       R2, #PALETTE_INK      ' R2 now points to the ink color
:LoadPaper    mov       COLORS, 0 wc          ' Now C carries BRIGHT (check PALETTE_PAPER for the details)
        if_c  add       R2, #8                ' If BRIGHT, use the second line of palette inks
              movs      :LoadInk, R2          ' Change the LoadInk line to read from the inks palette
:LoadPixels   mov       PIXELS, 0             ' Load the final pixels
:LoadInk      or        COLORS, 0             ' Add the final ink to the colors
              waitvid   COLORS, PIXELS
              djnz      R0, #:Character


              { RIGHT BORDER }
              mov       VSCL, #VSCL_RightBorder
              waitvid   COLOR_BORDER, #0


              ' Calculate the address of the next bitmap line        
              add       YCoord, #1                      ' Increase the Y counter
              tjz       UseSpectrumLayout, #:AddrOK     ' If we are simulating the Spectrum screen layout,
              test      YCoord, #$3F wz                 ' we must apply different increments to the bitmap
        if_z  jmp       #:AddrOK                        ' pointers depending on the current Y coordinate.
              test      YCoord, #$07 wz
        if_nz add       BitmapPtr, NextLine
        if_z  sub       BitmapPtr, NextRow
:AddrOK          

              ' Calculate the address of the next attribute line              
              sub       CharacterRows, #1 wz
        if_z  mov       CharacterRows, #8           ' Advance to the next line of attributes if the sub-character
        if_z  add       AttribPtr, #32              ' counter reaches the end of character, and reset it to 8
              djnz      LineCounter, #:ScanLine     ' Next line (note that here LineCounter is always > 0)


              { EMPTY - BORDER ONLY LINE }
:EmptyLine    mov       VSCL, _VSCL_VisibleLine     ' Output an entire visible line of BORDER color
              waitvid   COLOR_BORDER, #0
              djnz      LineCounter, #:ScanLine     ' Next line: note that this may be the last one


              { EMPTY - HALF LINE }
              ' Output an extra empty half line to correctly output 262.5 lines
              call      #HSync
              mov       VSCL, _VSCL_HalfLine
              waitvid   COLOR_BORDER, #0
              

              { VSYNC }
              call      #VSyncHigh      ' VSync procedure:    6 lines of HSync-only values
              call      #VSyncLow       '                     6 lines inverted from the previous ones
              call      #VSyncHigh      '                     6 lines more of HSync-only values
              
              jmp       #:Frame         ' Next frame       


{------------------------------------------------------------------------------}
' Synchronization subroutines
{------------------------------------------------------------------------------}
HSync
              mov       VSCL, #VSCL_FrontPorch
              waitvid   COLOR_BLACK, #0
              mov       VSCL, #VSCL_SynchronizingPulse
              waitvid   COLOR_SYNC, #0
              mov       VSCL, #VSCL_BreezeAway
              waitvid   COLOR_BLACK, #0
              mov       VSCL, #VSCL_ColourBurst
              waitvid   COLOR_YHUE, #0
              mov       VSCL, #VSCL_WaitToData
              waitvid   COLOR_BLACK, #0
HSync_Ret     ret

VSyncHigh     mov       R0, #6
:Loop         mov       VSCL, #VSCL_FrontPorch
              waitvid   COLOR_BLACK, #0
              mov       VSCL, #VSCL_SynchronizingPulse
              waitvid   COLOR_SYNC, #0
              mov       VSCL, #VSCL_BackPorch           ' BackPorch = BreezeAway + ColourBurst + WaitToData
              waitvid   COLOR_BLACK, #0
              mov       VSCL, _VSCL_VisibleLine
              waitvid   COLOR_BLACK, #0
              djnz      R0, #:Loop
VSyncHigh_Ret ret

VSyncLow      mov       R0, #6
:Loop         mov       VSCL, #VSCL_FrontPorch
              waitvid   COLOR_SYNC, #0
              mov       VSCL, #VSCL_SynchronizingPulse
              waitvid   COLOR_BLACK, #0
              mov       VSCL, #VSCL_BackPorch           ' BackPorch = BreezeAway + ColourBurst + WaitToData
              waitvid   COLOR_SYNC, #0
              mov       VSCL, _VSCL_VisibleLine
              waitvid   COLOR_SYNC, #0
              djnz      R0, #:Loop              
VSyncLow_Ret  ret

{------------------------------------------------------------------------------}
' Utility subroutines
{------------------------------------------------------------------------------}
  ' Divide R1 by R2 and return the result in R3 with 32 bits of decimal precision
  ' Input:  R1 → Dividend
  '         R2 → Divisor (it is required that R1 < R2)
  ' Output: R3 → (R1/R2) << 32
Divide        mov       R0, #33
:Loop         cmpsub    R1, R2 wc
              rcl       R3, #1
              shl       R1, #1
              djnz      R0, #:Loop
Divide_Ret    ret


  ' The following instructions are copied to the :Flash line to enable or
  ' disable the flash bit processing.

Flash1  if_nz xor       R3, #$FF
Flash0  if_nz mov       R3, R3


{==============================================================================}
' Uninitialized data
{==============================================================================}        
  R0                                res  1
  R1                                res  1
  R2                                res  1
  R3                                res  1
  R4                                res  1
  YCoord                            res  1
                                   
  COLORS                            res  1    ' Used in the inner loop
  PIXELS                            res  1
                                   
  LineCounter                       res  1
  CharacterRows                     res  1
  BitmapPtr                         res  1
  AttribPtr                         res  1
  ScreenPtr                         res  1
  UseSpectrumLayout                 res  1

  INVBITS                           res  256 