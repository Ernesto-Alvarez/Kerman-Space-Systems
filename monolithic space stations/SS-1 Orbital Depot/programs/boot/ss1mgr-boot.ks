LOCAL programName IS "ss1mgr".
LOCAL entryPoint IS "ssm.ks".
print "Checking if firmware is present".
IF NOT EXISTS("/" + programName + "/" + entryPoint)
	{
	COPYPATH("0:/firmware/" + programName,"/").
	}
CD(programName).
RUNPATH(entryPoint).
