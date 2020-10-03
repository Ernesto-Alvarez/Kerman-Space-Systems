@LazyGlobal off.

RUNONCEPATH("functionregistry").
RUNONCEPATH("blocks").
RUNONCEPATH("basefacilities").
RUNONCEPATH("cron").

//Crew manifest
//Lists and locates crew

LOCAL crewManifest IS list().
LOCAL crewNames IS list().
LOCAL crewLocation IS list().
LOCAL crewLocationBlock IS list().
LOCAL updating IS False.

GLOBAL FUNCTION crewedPart
{
	PARAMETER checkedPart.
	IF crewLocation:CONTAINS(checkedPart)
		return True.
	ELSE
		return False.
}

GLOBAL FUNCTION enumerateCrew
{
//	print "Locating and registering crew members".
	SET updating to True.
	SET crewManifest TO list().
	SET crewNames TO list().
	SET crewLocation TO list().
	SET crewLocationBlock TO list().
	FOR i in Core:Vessel:Crew()
	{
//		print i:NAME.
		crewManifest:ADD(i).
		crewNames:ADD(i:NAME).
		crewLocation:ADD(i:PART).
		LOCAL blockRoot IS blockRootPart(i:part).
		crewLocationBlock:ADD(getBlockNameFromRoot(blockRoot)).
	}
	SET updating to FALSE.
//	print "Crew enumeration complete".
}

LOCAL FUNCTION locateCrew
{
	PARAMETER crewId.
	LOCAL crewMember IS crewManifest[crewId].

	print "Name: " + crewNames[crewId].
	print "Location: " + crewLocationBlock[crewId] + " (in purple)".
	highlightBLock(crewLocation[crewId]).
	highlight(crewManifest[crewId]:PART,purple).
	WAIT 1.
	highlightBLock(crewLocation[crewId],false).
}

GLOBAL FUNCTION locateCrewInteractive
{
	IF updating = True.
	{
		print "Manifest if being updated, try again later".
		return.
	}
	LOCAL sysMessage IS list("Select crewmember to locate").
	LOCAL crewId IS pager(sysMessage,crewNames).
	IF crewId >= 0
		locateCrew(crewId).
}

//Init
print "Loading crew manifest services".
enumerateCrew().

//Register function
LOCAL check IS registerFunction(enumerateCrew@,"Crew","enumerateCrew","Manually enumerate crew").
registerFunction(locateCrewInteractive@,"Crew","locateCrewInteractive","Locate crew member").

//Register cron
addCrontab(check,1).

print "Crew manifest loaded".