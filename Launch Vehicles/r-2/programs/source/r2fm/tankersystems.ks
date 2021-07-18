@LazyGlobal off.

//R-2 tanker system manager

RUNONCEPATH("blocks").
RUNONCEPATH("resourcexfer").

LOCAL tankerSystems IS lexicon().

GLOBAL FUNCTION enumerateSystems
{
	LOCAL cpu IS core:part.
	LOCAL blockRoot IS blockRootPart(cpu).
	LOCAL blockParts IS blockPartList(blockRoot).

	FOR i in blockParts
	{
		//Parachute is unique
		IF i:NAME = "parachuteSingle"
			SET tankerSystems["Parachute"] TO i.

		//Engine is unique
		IF i:NAME = "liquidEngine3.v2"
			SET tankerSystems["Engine"] TO i.


		//Computing core is unique
		IF i:NAME = "KR-2042"
			SET tankerSystems["CPU"] TO i.


		//Docking adaptor is unique
		IF i:NAME = "dockingPort3"
			SET tankerSystems["Clampotron"] TO i.
		
		//Tank D is the only small tank
		IF i:NAME = "fuelTankSmall"
			SET tankerSystems["TankD"] TO i.
		
		//The RCS tank is of a different type
		IF i:NAME = "radialRCSTank"
			SET tankerSystems["RCSTank"] to i.

		//FL-T400 tanks can be distinguished by adjacencies
		IF i:name = "fuelTank"
		{
			//Tank A supports the radio antennas
			IF adjacencyList(i):CONTAINS("surfAntenna")
				SET tankerSystems["TankA"] TO i.

			//Tank B supports the RCS blocks
			IF adjacencyList(i):CONTAINS("RCSBlock.v2")
				SET tankerSystems["TankB"] TO i.

			//Tank C is adjacent to tank D
			IF adjacencyList(i):CONTAINS("fuelTankSmall")
				SET tankerSystems["TankC"] TO i.

		}
		
	}

}

GLOBAL FUNCTION listTanks
{
	return LIST(tankerSystems["TankA"],tankerSystems["TankB"],tankerSystems["TankC"],tankerSystems["TankD"]).
}

GLOBAL FUNCTION balanceTanks
{
	balanceResource(listTanks(),"LiquidFuel").
	balanceResource(listTanks(),"Oxidizer").
}

GLOBAL FUNCTION getDockingAdaptor
{
	return tankerSystems["Clampotron"].
}

//Module init
enumerateSystems().	//We should call enumerateWithCache instead, if we saved the system state.

//Function Registration
registerFunction(enumerateSystems@,"TankerSystems","enumerateSystems","Re-enumerate tanker systems").
registerFunction(balanceTanks@,"TankerSystems","balanceTanks","Balance fuel tanks").

print "Tanker system manager loaded".
