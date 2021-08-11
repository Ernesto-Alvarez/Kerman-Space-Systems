@LazyGlobal off.

LOCAL softwareName IS "Fuel Tanker Manager".
LOCAL softwareVersion IS "1.1.1".

LOCAL tickSeconds IS 0.5.

CLEARSCREEN.
print softwareName + " version " + softwareVersion.
print "Loading modules...".

RUNONCEPATH("menu").
GLOBAL mainMenu IS createMenu("Select function to execute").

RUNONCEPATH("tankersystems").
RUNONCEPATH("refueling").
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

