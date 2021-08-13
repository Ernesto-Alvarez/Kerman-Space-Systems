@LazyGlobal off.

LOCAL softwareName IS "Orbital Depot (SS-1) Manager".
LOCAL softwareVersion IS "1.0.0".

LOCAL tickSeconds IS 0.5.

CLEARSCREEN.
print softwareName + " version " + softwareVersion.
print "Loading modules...".

RUNONCEPATH("menu").
GLOBAL mainMenu IS createMenu("WARNING: autonomous functions are disabled when in attention mode!").
RUNONCEPATH("systems").
RUNONCEPATH("shipreplenish").
RUNONCEPATH("visitorsystems").

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

