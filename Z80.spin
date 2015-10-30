

CON

	{Connections to Z80}
	{D0:D7 on Z80 are connected to P0:P7 on Prop}
	CPU_IOREQ_PIN	= 8
	CPU_RESET_PIN	= 9
	CPU_CLK_PIN   	= 10
	CPU_RD_PIN    	= 11
	CPU_WT_PIN    	= 12
	CPU_EN_PIN    	= 13
	CPU_ADRQ_PIN  	= 14
	CPU_ADRCLK_PIN  = 15

	{Z80 Pin Masks}
	c_CpuIoReqMsk    = 1 << CPU_IOREQ_PIN   ' Mask to read Z80 IO request line (/IOREQ)
	c_CpuResetMsk    = 1 << CPU_RESET_PIN   ' Mask to set Z80 reset line (/RESET)
	c_CpuClkMsk      = 1 << CPU_CLK_PIN     ' Mask to set Z80 clock line (CLK)
	c_CpuRdMsk       = 1 << CPU_RD_PIN      ' Mask to read/set Z80 data read line (/RD)
	c_CpuWtMsk       = 1 << CPU_WT_PIN      ' Mask to read/set Z80 data write line (/WT)
	c_CpuAdrDataMsk  = 1 << CPU_ADRQ_PIN    ' Mask to read port address value from parallel to serial IC
	c_CpuAdrClkMsk   = 1 << CPU_ADRCLK_PIN  ' Mask to set port address clock on parallel to serial IC
{
	c_CpuRdWtReqMsk  = (c_CpuRdMsk | c_CpuWtMsk)
	c_BaseDirRegMsk  = (c_CpuResetMsk | c_CpuClkMsk | c_CpuEnMsk | c_CpuAdrClkMsk)
}


PUB Start

    clkset(%01101000, 12_000_000)   ' Set internal oscillator to RCFast and set PLL to start
    waitcnt(cnt + 120_000)          ' wait approx 10ms at 12mhz for PLL to 'warm up'
    clkset(%01101111, 80_000_000)   ' 80MHz (5MHz PLLx16)  


    coginit(0, @ASM_ENTRY_POINT, 0)
    

DAT

        org 0


ASM_ENTRY_POINT
        mov       dira, #1            'set pin as output
        mov       FRQA, FREQ          'set up the desired frequency
        mov       CTRA, CTRA_MODE     'begin output of the HF signal
        
        waitpeq   $, #0               'sleep forever



FREQ          long      $1000_0000                                  ' BOTH of these give
CTRA_MODE     long      %0_00010_010_00000000_000000_000_000000     ' 2.500MHz


              FIT             
{
FRQA = 

}