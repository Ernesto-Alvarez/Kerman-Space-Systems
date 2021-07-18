LOCAL programName IS "fuelmanager".
LOCAL entryPoint IS "fuelmanager.ks".

print "Checking if firmware is present".

IF NOT EXISTS("1:/" + programName + "/" + entryPoint)
	{
	print "Firmware not present in local storage".
	print "Loading firmware from archive".
	COPYPATH("0:/firmware/" + programName,"1:/").
	}

print "Executing firmware".
CD(programName).
RUNPATH(entryPoint).