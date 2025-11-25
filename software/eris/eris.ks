@LazyGlobal off.
RUNONCEPATH("resourcexfer").

//ERIS, the emergency resource isolation system
//This module enumerates all tanks in a spaceship and periodically tests them for leaks
//When a leak is detected, it isolates the tank to prevent the leak from draining other tanks
//and transfers the resources out of the damaged tanks to conserve the resource
//
//ERIS can also mean Emergency Resouce ISolation, so calling it the ERIC system is OK
//
//This module requires the scheduler to periodically launch the checker functions for the different isolation routines


//Constructor: for now, enumerate the tanks present and assign them to categories depending on whether they are isolated or not
//In the future, we'll restore the configuration from file, if possible

GLOBAL FUNCTION ERIS
{

	LOCAL newIsolator IS lexicon("tanks",lexicon(),"parts",lexicon()).

	//TO DO:Check for and restore configuration from file

	//Enumerate tanks 

	//Limit which resources to manage

	LOCAL resourceBlacklist IS list().
	resourceBlacklist:ADD("ElectricCharge").	//Shorted batteries go to 0 and do not leak
	resourceBlacklist:ADD("Ablator").		//Transferring ablator makes no sense (even if kOS lets you) and does not leak
	resourceBlacklist:ADD("Food").			//Food does not leak
	resourceBlacklist:ADD("SpareParts").		//Does not leak
	resourceBlacklist:ADD("CarbonDioxide").		//We do not care if it leaks
	resourceBlacklist:ADD("Waste").			//We do not care if it leaks
	resourceBlacklist:ADD("WasteWater").		//We do not care if it leaks

//Limit to monoprop for test

	resourceBlacklist:ADD("Water").
	resourceBlacklist:ADD("Oxygen").


	SET newIsolator["resources"] TO list().

	FOR resource in SHIP:RESOURCES
		IF resourceBlacklist:CONTAINS(resource:NAME) = FALSE
			newIsolator["resources"]:ADD(resource:NAME).

	//Prepare hierarchy of tanks

	FOR resource in newIsolator["resources"]
	{
		SET newIsolator["tanks"][resource] TO lexicon().
		SET newIsolator["tanks"][resource]["activeTanks"] TO list().
		SET newIsolator["tanks"][resource]["isolatedTanks"] TO list().
		SET newIsolator["tanks"][resource]["badTanks"] TO list().
		SET newIsolator["tanks"][resource]["emptyTanks"] TO list().
	}

	FOR part IN SHIP:PARTS
		FOR tank in part:RESOURCES
			IF newIsolator["resources"]:CONTAINS(tank:NAME)
			{
				//Assign tanks to proper section in hierarchy
				IF tank:ENABLED newIsolator["tanks"][tank:NAME]["activeTanks"]:ADD(tank).
					ELSE newIsolator["tanks"][tank:NAME]["isolatedTanks"]:ADD(tank).

				//Create dictionary that goes from specific tank to its part
				newIsolator["parts"]:ADD(tank,part).
			}

	RETURN newIsolator.
}

GLOBAL FUNCTION ERISCheck
{
	PARAMETER self.

	tankTest(self).
	reclassifyTanks(self).
	classConstraints(self).
}

LOCAL FUNCTION reclassifyTanks
{
	PARAMETER self.

	FOR resource in self["resources"]
	{
		//Active to Empty (an active tank is drained of resources)
		LOCAL toReclassify IS list().
		FOR tank in self["tanks"][resource]["activeTanks"]
		{
			IF tank:AMOUNT = 0
				toReclassify:ADD(tank).
		}

		FOR tank in toReclassify
		{
			LOCAL idx IS self["tanks"][resource]["activeTanks"]:FIND(tank).
			self["tanks"][resource]["emptyTanks"]:ADD(tank).
			self["tanks"][resource]["activeTanks"]:REMOVE(idx).
			SET tank:ENABLED TO FALSE.
		}

		//Isolated to Empty (an isolated tank is drained of resources, e.g. by transfer)
		LOCAL toReclassify IS list().
		FOR tank in self["tanks"][resource]["isolatedTanks"]
		{
			IF tank:AMOUNT = 0
				toReclassify:ADD(tank).
		}

		FOR tank in toReclassify
		{
			LOCAL idx IS self["tanks"][resource]["isolatedTanks"]:FIND(tank).
			self["tanks"][resource]["emptyTanks"]:ADD(tank).
			self["tanks"][resource]["isolatedTanks"]:REMOVE(idx).
		}


		//Isolated to Active (someone opened the valves on an isolated tank)
		LOCAL toReclassify IS list().
		FOR tank in self["tanks"][resource]["isolatedTanks"]
		{
			IF tank:ENABLED
				toReclassify:ADD(tank).
		}

		FOR tank in toReclassify
		{
			LOCAL idx IS self["tanks"][resource]["isolatedTanks"]:FIND(tank).
			self["tanks"][resource]["activeTanks"]:ADD(tank).
			self["tanks"][resource]["isolatedTanks"]:REMOVE(idx).
		}

		//Active to isolated (someone shut the valves on an active tank)
		LOCAL toReclassify IS list().
		FOR tank in self["tanks"][resource]["activeTanks"]
		{
			IF tank:ENABLED = FALSE
				toReclassify:ADD(tank).
		}

		FOR tank in toReclassify
		{
			LOCAL idx IS self["tanks"][resource]["activeTanks"]:FIND(tank).
			self["tanks"][resource]["isolatedTanks"]:ADD(tank).
			self["tanks"][resource]["activeTanks"]:REMOVE(idx).
		}

		//Empty to isolated (someone put some resource in an empty tank)
		LOCAL toReclassify IS list().
		FOR tank in self["tanks"][resource]["emptyTanks"]
		{
			IF tank:AMOUNT > 0
				toReclassify:ADD(tank).
		}

		FOR tank in toReclassify
		{
			LOCAL idx IS self["tanks"][resource]["emptyTanks"]:FIND(tank).
			self["tanks"][resource]["isolatedTanks"]:ADD(tank).
			self["tanks"][resource]["emptyTanks"]:REMOVE(idx).
		}
		
	}	

}

LOCAL FUNCTION classConstraints
{
	PARAMETER self.

	FOR resource in self["resources"]
	{

	//Empty tanks MUST be kept isolated (to prevent resource loss if they fail)

		FOR tank in self["tanks"][resource]["emptyTanks"]
			SET tank:ENABLED TO FALSE.


	//Bad tanks MUST be kept isolated (else they will drain other tanks) AND empty (to save the resources in tank)

		FOR tank in self["tanks"][resource]["badTanks"]
		{
			SET tank:ENABLED TO FALSE.
			IF tank:AMOUNT > 0		//Bad tank contains resource, transfer it out!
			{
				LOCAL quantity IS tank:AMOUNT.
				LOCAL resrc IS tank:NAME.
				LOCAL src IS self["parts"][tank].
				LOCAL dst IS list().

				FOR dtank IN self["tanks"][resrc]["activeTanks"]
					dst:ADD(self["parts"][dtank]).

				FOR dtank IN self["tanks"][resrc]["isolatedTanks"]
					dst:ADD(self["parts"][dtank]).

				FOR dtank IN self["tanks"][resrc]["emptyTanks"]
					dst:ADD(self["parts"][dtank]).

				syncTransfer(src,dst,9999999,resource).


			}

		}
	}
}

LOCAL FUNCTION findLeaks
{
	PARAMETER tankList.

	LOCAL enabled IS lexicon().
	LOCAL before IS lexicon().
	LOCAL after IS lexicon().
	LOCAL badTanks is list().

	//Isolate tanks to be tested and measure contents
	FOR tank in tankList
	{
		SET enabled[tank] TO tank:ENABLED.
		SET tank:ENABLED TO FALSE.
		SET before[tank] TO tank:AMOUNT.
	}

	//Measure again after small wait
	WAIT 0.1.
	FOR tank in tankList
		SET after[tank] TO tank:AMOUNT.

	//Have the tank contents changed?
	FOR tank in tankList
		IF before[tank] > after[tank]		//This can be a problem if a transfer is ongoing at this time
			badTanks:ADD(tank).

	//Restore tank valves to initial value
	FOR tank in tankList
		SET tank:ENABLED TO enabled[tank].

	return badTanks.
}

LOCAL FUNCTION tankTest
{
	PARAMETER self.

	//Test all tanks for leaks. Interrupts service while test is taking place

	LOCAL allTanks IS list().

	FOR resource in self["resources"]
	{
		FOR tank in self["tanks"][resource]["activeTanks"]
			alltanks:ADD(tank).

		FOR tank in self["tanks"][resource]["isolatedTanks"]
			alltanks:ADD(tank).
	}

	LOCAL failedTanks IS findLeaks(allTanks).

	FOR tank IN failedTanks
	{
		IF tank:ENABLED		//Active tank
		{
			LOCAL idx IS self["tanks"][tank:NAME]["activeTanks"]:FIND(tank).
			self["tanks"][tank:NAME]["badTanks"]:ADD(tank).
			self["tanks"][tank:NAME]["activeTanks"]:REMOVE(idx).
		}
		ELSE			//Isolated tank
		{
			LOCAL idx IS self["tanks"][tank:NAME]["isolatedTanks"]:FIND(tank).
			self["tanks"][tank:NAME]["badTanks"]:ADD(tank).
			self["tanks"][tank:NAME]["isolatedTanks"]:REMOVE(idx).
		}
	}
}

print "ERIS version 0.3.0 loaded".