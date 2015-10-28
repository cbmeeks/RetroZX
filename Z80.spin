

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

	c_CpuRdWtReqMsk  = (c_CpuRdMsk | c_CpuWtMsk)
	c_BaseDirRegMsk  = (c_CpuResetMsk | c_CpuClkMsk | c_CpuEnMsk | c_CpuAdrClkMsk)



PUB Start


	