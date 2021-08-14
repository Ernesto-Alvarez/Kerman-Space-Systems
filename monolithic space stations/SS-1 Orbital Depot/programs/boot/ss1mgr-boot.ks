IF NOT EXISTS("/ss1mgr/ssm.ks")
	COPYPATH("0:/firmware/ss1mgr","/").
CD("ss1mgr").
RUNPATH("ssm").
