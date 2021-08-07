@LazyGlobal off.

LOCAL softwareName IS "Orbital Depot (SS-1) Manager".
LOCAL softwareVersion IS "0.6.0".

LOCAL tickSeconds IS 0.5.

CLEARSCREEN.
print softwareName + " version " + softwareVersion.
print "Loading modules...".

RUNONCEPATH("functionregistry").
RUNONCEPATH("inthandler").
RUNONCEPATH("interface").
RUNONCEPATH("dockingports").
RUNONCEPATH("shipreplenish").
RUNONCEPATH("tugs").

print "Module loading complete".

LOCAL FUNCTION restartSystem
{
	reboot.
}


registerFunction(restartSystem@,"SSM","restartSystem","Reboot computer").

UNTIL False
{
	
	handle().
	WAIT tickSeconds.
}

