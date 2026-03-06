// Bootloaders are stored in a single file. You can't load more than one, so you need the application name and data inline.
// Fill the program data in the variables below.

//VARIABLES
LOCAL programName IS "aoc3-test".
LOCAL entryPoint IS "entrypoint".

print "Kerbal bootloader version 0.3.1".

//INITIAL STATE
print "Setting initial computer state".
SWITCH TO 1.
CD("/").

//FORCE RELOAD PROMPT
LOCAL reload IS false.
TERMINAL:INPUT:CLEAR().
print "Press BACKSPACE to force firmware reload from archive".
WAIT 1.
IF TERMINAL:INPUT:HASCHAR AND TERMINAL:INPUT:BACKSPACE SET reload TO true.
TERMINAL:INPUT:CLEAR().

//DOWNLOAD FIRMWARE
IF reload print "Firmware reload forced".
ELSE print "Checking if firmware is present".
IF NOT EXISTS("/" + programName + "/" + entryPoint) OR reload
	{
	IF NOT reload print "Firmware is not present".
	print "Loading firmware from archive".
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