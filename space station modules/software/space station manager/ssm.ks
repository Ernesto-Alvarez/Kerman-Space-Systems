@LazyGlobal off.

LOCAL softwareVersion IS "0.3.0".

LOCAL tickSeconds IS 0.5.

CLEARSCREEN.
print "Space Station Manager version " + softwareVersion.
print "Loading modules...".

//RUNONCEPATH("functionregistry").
RUNONCEPATH("inthandler").
//RUNONCEPATH("cron").
RUNONCEPATH("beacon").
RUNONCEPATH("interface").
RUNONCEPATH("crewmanifest").
RUNONCEPATH("indoorlighting").
RUNONCEPATH("basefacilities").
RUNONCEPATH("ports").
RUNONCEPATH("resources").


print "Module loading complete".

UNTIL False
{
	
	handle().
	WAIT tickSeconds.
}

