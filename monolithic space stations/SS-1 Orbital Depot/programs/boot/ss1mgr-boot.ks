LOCAL programName IS "ss1mgr".
LOCAL entryPoint IS "ssm.ks".

print "Checking if firmware is present".

IF NOT EXISTS("/" + programName + "/" + entryPoint)
	{
	print "Firmware not present in local storage".
	print "Loading firmware from archive".
	COPYPATH("0:/firmware/" + programName,"/").
	}

print "Executing firmware".
CD(programName).
RUNPATH(entryPoint).
