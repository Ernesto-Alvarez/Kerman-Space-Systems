@LazyGlobal off.

RUNONCEPATH("menu").
GLOBAL mainMenu IS createMenu("Select function").
RUNONCEPATH("systems").
RUNONCEPATH("shipreplenish").
RUNONCEPATH("visitorsystems").
RUNONCEPATH("interface").
print "Module loading complete".

UNTIL False
{
	WAIT 1.
}

