@LazyGlobal off.

LOCAL softwareName IS "KSS Shell Test".
LOCAL softwareVersion IS "0.1.0".

LOCAL tickSeconds IS 0.5.

CLEARSCREEN.
print softwareName + " version " + softwareVersion.
print "Loading modules...".

RUNONCEPATH("menu").
GLOBAL mainMenu IS createMenu("WARNING: autonomous functions are disabled when in attention mode!").
RUNONCEPATH("testmodule").
RUNONCEPATH("interface").

print "Module loading complete".

LOCAL FUNCTION restartSystem
{
	reboot.
}


registerFunction(mainMenu,restartSystem@,"Reboot computer").

UNTIL False
{
	
	//handle().
	WAIT tickSeconds.
}

