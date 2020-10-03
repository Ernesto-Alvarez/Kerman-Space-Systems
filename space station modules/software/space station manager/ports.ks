@LazyGlobal off.

//Port manager
//Enumerates docking ports and controls all aspects of them, including vessel registration and port lighting.
//We're considering clampotron jr as socking ports. Clampotron standard docks station modules together.

RUNONCEPATH("basefacilities").
RUNONCEPATH("blocks").
RUNONCEPATH("functionregistry").
RUNONCEPATH("cron").

LOCAL portList IS list().
LOCAL portSpots IS lexicon().
LOCAL portStrobes IS lexicon().
LOCAL shipNames IS lexicon().
LOCAL shipTypes IS lexicon().
LOCAL updating IS False.

GLOBAL FUNCTION enumeratePorts
{	
	SET updating TO True.
	//Wipe port database
	SET portList to list().
	SET shipNames TO lexicon().
	SET shipTypes TO lexicon().

	//Locate docking ports
	LOCAL roots IS blockRoots().

	FOR i IN blockRoots()
		FOR j IN blockPartList(i,list("dockingPort3"))
			portList:add(j).

	//Identify parts associated with docking ports
	FOR i in portList
	{
		//Get part list
		LOCAL partList IS blockTaggedParts(i,list(i:TAG)).

		LOCAL classifier IS lexicon().

		FOR j IN partList
		{
			if not classifier:KEYS:CONTAINS(j:NAME)
				SET classifier[j:NAME] TO list().
			classifier[j:NAME]:ADD(j).
		}
		
		IF classifier:KEYS:CONTAINS("W485.SurfaceLight")
			SET portSpots[i] TO classifier["W485.SurfaceLight"].
		ELSE
			SET portSpots[i] TO list().
		
		IF classifier:KEYS:CONTAINS("lightstrobe.white")
			SET portStrobes[i] TO classifier["lightstrobe.white"].
		ELSE
			SET portStrobes[i] TO list().
	}

}

GLOBAL FUNCTION strobesOn
{
	PARAMETER port.

	FOR i in portStrobes[port]
	{
		i:getModule("ModuleNavLight"):DoAction("activate double flash",True).
	}
}

GLOBAL FUNCTION strobesOff
{
	PARAMETER port.

	FOR i in portStrobes[port]
	{
		i:getModule("ModuleNavLight"):DoAction("turn light off",True).
	}
}

GLOBAL FUNCTION SpotsOn
{
	PARAMETER port.

	FOR i in portSpots[port]
	{
		i:getModule("ModuleColoredLensLight"):DoAction("turn light on",True).	
	}
}

GLOBAL FUNCTION SpotsOff
{
	PARAMETER port.

	FOR i in portSpots[port]
	{
		i:getModule("ModuleColoredLensLight"):DoAction("turn light off",True).	
	}
}


//Docking light management
GLOBAL FUNCTION dockingSpotCheck
{
	FOR i in portList
	{
		IF i:HASPARTNER
		{
			spotsOn(i).
		}
		ELSE
		{
			spotsOff(i).
		}
	}
}

//Visitor registry
GLOBAL FUNCTION enumerateVessels
{
	LOCAL vessels IS list().
	FOR i IN portList
	{
		IF i:HASPARTNER
		{
			vessels:ADD(i:PARTNER).
		}
	}
	return vessels.
}

GLOBAL FUNCTION enumerateVesselsUI
{
	LOCAL vessels IS enumerateVessels().
	LOCAL vesselTypes IS list().
	FROM { LOCAL i IS 0. } UNTIL i = vessels:LENGTH STEP { SET i TO i+1. } DO
	{
		vesselTypes:ADD(identifyBlock(vessels[i])).
	}
	LOCAL sysMessage IS list("Visiting ship registry","Select ship to identify").
	LOCAL infoVessel IS pager(sysMessage,vesselTypes).
	print "Docking ID " + infoVessel.
	print "Part       " + vessels[infoVessel].
	print "Type       " + vesselTypes[infoVessel].
	highlightBlock(vessels[infoVessel]).
	WAIT 1.
	highlightBlock(vessels[infoVessel],False).
}

//Docking strobe management
//Stupid lame brained KSP, we can just light up unoccupied ports if someone's in range.

GLOBAL FUNCTION dockingStrobeCheck
{
	//List all vessels in universe, then filter by proximity
	LOCAL targetList IS list().
	LIST TARGETS in targetList.
	LOCAL closeTargets IS list().
	FOR i in targetList
	{
		IF i:position:mag < 150 AND ( i:TYPE <> "EVA" OR i:type <> "Debris" )		//Ship is nearby, and is not a Kerbonaut or debris
		{
			closeTargets:add(i).
		}
	}

	IF closeTargets:LENGTH > 0		//Offer ports
	{
		FOR i in portList
		{
			IF i:HASPARTNER
			{
				strobesOff(i).		//We should not light up used ports
			}
			ELSE
			{
				strobesOn(i).		//Light'em up, baby!!
			}
		}
	}
	ELSE					//Shut off strobes
	{
		FOR i in portList
			strobesOff(i).	
	}
}

//Init
enumeratePorts().

//LOCAL vessels IS enumerateVessels().
//for i in vessels
//{
//	highlightblock(i).
//	WAIT 1.
//	highlightblock(i,false).
//}

//Register functions
registerFunction(enumeratePorts@,"Ports","enumeratePorts","Manually re-enumerate ports").
LOCAL sCheck IS registerFunction(dockingSpotCheck@,"Ports","dockingSpotCheck","Manually recheck port spotlight status").
LOCAL rCheck IS registerFunction(dockingStrobeCheck@,"Ports","dockingStrobeCheck","Manually recheck port stobe status").
registerFunction(enumerateVesselsUI@,"Ports","enumerateVesselsUI","Docked Ship Registry").

//Register crontab
addCrontab(sCheck,15).
addCrontab(rCheck,2).


