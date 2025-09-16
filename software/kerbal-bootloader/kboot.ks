// Bootloaders are stored in a single file. You can't load more than one, so you need the application name and data inline.
// Fill the program data in the variables below.

//VARIABLES
LOCAL programName IS "FILL PROGRAM NAME HERE".
LOCAL entryPoint IS "entrypoint".

print("Kerbal bootloader version 0.2.0").

//INITIAL STATE
print "Setting initial computer state".
SWITCH TO 1.
CD("/").

//DOWNLOAD FIRMWARE
print "Checking if firmware is present".
IF NOT EXISTS("/" + programName + "/" + entryPoint)
	{
	print "Firmware not present in local storage".
	print "Attempting to contact archive".
	WAIT UNTIL HOMECONNECTION:ISCONNECTED.
	print "Connection to archive established".
	print "Loading firmware from archive".
	COPYPATH("0:/firmware/" + programName,"/").
	IF NOT EXISTS("/" + programName + "/" + entryPoint)
		{
		print "Unable to load firmware from archive".	
		}
	}

//EXECUTE
print "Executing firmware".
CD(programName).
RUNPATH(entryPoint).