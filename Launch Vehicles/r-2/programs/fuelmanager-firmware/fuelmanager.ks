@LazyGlobal off.

LOCAL softwareName IS "Fuel Tanker Manager".
LOCAL softwareVersion IS "1.0.0".

LOCAL tickSeconds IS 0.5.

CLEARSCREEN.
print softwareName + " version " + softwareVersion.
print "Loading modules...".

RUNONCEPATH("functionregistry").
RUNONCEPATH("inthandler").
RUNONCEPATH("interface").
RUNONCEPATH("tankersystems").
RUNONCEPATH("fueling").

print "Module loading complete".

UNTIL False
{
	
	handle().
	WAIT tickSeconds.
}

