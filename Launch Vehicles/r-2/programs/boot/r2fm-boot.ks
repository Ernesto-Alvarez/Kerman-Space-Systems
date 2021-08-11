LOCAL programName IS "r2fm".
LOCAL entryPoint IS "entrypoint.ks".

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
