@LazyGlobal off.

RUNONCEPATH("blocks").

//R-2 fuel management system

LOCAL tankerSystems IS lexicon().

LOCAL FUNCTION enumerateSystems
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
			SET tankerSystems["Clapmpotron"] TO i.
		
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

			//Tank B suppots the RCS blocks
			IF adjacencyList(i):CONTAINS("RCSBlock.v2")
				SET tankerSystems["TankB"] TO i.

			//Tank C is adjacent to tank D
			IF adjacencyList(i):CONTAINS("fuelTankSmall")
				SET tankerSystems["TankC"] TO i.

		}
		
	}

}

LOCAL FUNCTION measureTankResource
{
	PARAMETER tankList.
	PARAMETER resource.
	PARAMETER parameter IS "AMOUNT".

	if tankList:TYPENAME = "string"
		SET tankList TO list(tankList).

	LOCAL quantity IS 0.

	FOR i IN tankList
	{
		LOCAL systemId IS "Tank"+i.

		LOCAL tank IS tankerSystems[systemId].
		FOR j in tank:RESOURCES
		{
			if j:NAME = resource
			{
				IF parameter = "CAPACITY"
					SET quantity TO quantity + j:CAPACITY.
				ELSE
					SET quantity TO quantity + j:AMOUNT.	
			}
		}
	}
	return quantity.

}

LOCAL FUNCTION fillRatio
{
	PARAMETER tankList.
	PARAMETER resource.

	return measureTankResource(tankList,resource,"AMOUNT") / measureTankResource(tankList,resource,"CAPACITY").

}

GLOBAL FUNCTION balancePayload
{

	FOR resource IN list("LiquidFuel","Oxidizer")
	{
		//Compute overall fill ratio
		LOCAL totalFillRatio IS fillRatio(list("A","B","C","D"),resource).
	
		//Compute expected tank fills
		LOCAL tankTargets IS lexicon().

		FOR tank IN list("A","B","C","D")
		{
			LOCAL tankCapacity IS measureTankResource(tank,resource,"CAPACITY").
			LOCAL tankFill IS measureTankResource(tank,resource,"AMOUNT").

			LOCAL targetFill IS tankCapacity * totalFillRatio.

			//Compute how much propellant must go into the tank to reach target fill
			//Positive values mean deficit (must load LFOX into tank)
			//Negative values mean superavit (must unload tank into other tank)
			SET tankTargets[tank] TO targetFill - tankFill.

		}
		

		print tankTargets.

		FOR i IN list("A","B","C")
		{
			FOR j in list ("B","C","D")
			{
				//If one tank has a superavit and the other a deficit...
				IF tankTargets[i] * tankTargets[j] < 0		
				{
					LOCAL transfer IS min(abs(tankTargets[i]),abs(tankTargets[j])).
					IF tankTargets[i] > 0
					{		//Load i tank from j
							print "Transfer " + transfer + " from tank " + j + " to tank " + i.
							syncTransfer(tankerSystems["Tank" + i],tankerSystems["Tank" + j],transfer,resource).
							SET tankTargets[i] TO tankTargets[i] - transfer.
							SET tankTargets[j] TO tankTargets[j] + transfer.
					}
					ELSE
					{		//Load j tank from i
							print "Transfer " + transfer + " from tank " + i + " to tank " + j.
							syncTransfer(tankerSystems["Tank" + j],tankerSystems["Tank" + i],transfer,resource).
							SET tankTargets[i] TO tankTargets[i] + transfer.
							SET tankTargets[j] TO tankTargets[j] - transfer.
					}
					print tankTargets.
				}
			}

		}

	}


}

GLOBAL FUNCTION syncTransfer
{
	PARAMETER from.
	PARAMETER to.
	PARAMETER quantity.
	PARAMETER resource.

	LOCAL xfer IS TRANSFER(resource,from,to,quantity).
	SET xfer:ACTIVE TO True.

	print xfer:STATUS.

	WAIT UNTIL not(xfer:STATUS = "Transferring").
	print xfer:STATUS.
}
	
enumerateSystems().
//print measureTankResource(list("A","B","C","D"),"LiquidFuel") + "/" + measureTankResource(list("A","B","C","D"),"LiquidFuel","CAPACITY") + " " + fillRatio(list("A","B","C","D"),"LiquidFuel").
//print measureTankResource(list("A","B","C","D"),"Oxidizer") + "/" + measureTankResource(list("A","B","C","D"),"Oxidizer","CAPACITY") + " " + fillRatio(list("A","B","C","D"),"Oxidizer").

balancePayload().

