@LazyGlobal off.

//R-2 fuel management system

//=====Systems======

RUNONCEPATH("blocks").

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

LOCAL FUNCTION listTanks
{
	return LIST(tankerSystems["TankA"],tankerSystems["TankB"],tankerSystems["TankC"],tankerSystems["TankD"]).
}



//======FUEL TRANSFER======


LOCAL FUNCTION fillRatio
{
	PARAMETER tankList.
	PARAMETER resource.

	return measureTankResource(tankList,resource,"AMOUNT") / measureTankResource(tankList,resource,"CAPACITY").

}


LOCAL FUNCTION measureTankResource
{
	PARAMETER tankList.
	PARAMETER resource.
	PARAMETER parameter IS "AMOUNT".

	IF tankList:ISTYPE("Part")
		SET tankList TO LIST(tankList).

	LOCAL quantity IS 0.

	FOR tank IN tankList
	{
		FOR j in tank:RESOURCES
		{
			if j:NAME = resource
			{
				IF parameter = "CAPACITY"
					SET quantity TO quantity + j:CAPACITY.
				IF parameter = "AMOUNT"
					SET quantity TO quantity + j:AMOUNT.
				IF parameter = "SPACE"
					SET quantity TO quantity + ( j:CAPACITY - j:AMOUNT ).
			}
		}
	}
	return quantity.

}


LOCAL FUNCTION syncTransfer
{
	PARAMETER from.
	PARAMETER to.
	PARAMETER quantity.
	PARAMETER resource.

	IF quantity = 0							//Nothing to transfer
		return.

	IF quantity < 0							//Reverse transfer
		return syncTransfer(to,from,quantity * -1,resource).

	IF to:ISTYPE("Part") AND from:ISTYPE("Part")			//Part to part transfer
	{
		print "Transfer from " + from + " to " + to + " " + quantity + " units of " + resource.

		LOCAL xfer IS TRANSFER(resource,from,to,quantity).
		SET xfer:ACTIVE TO True.
		WAIT UNTIL not(xfer:STATUS = "Transferring").
		return.
	}

	IF from:ISTYPE("List")						//From is a list
	{
		FOR tank IN from
		{
			LOCAL transferAmount IS min(quantity,measureTankResource(tank,resource,"AMOUNT")).
			syncTransfer(tank,to,transferAmount,resource).
			SET quantity TO quantity - transferAmount.
		}
		return.
	}

	IF to:ISTYPE("List")						//To is a list
	{
		FOR tank IN to
		{
			LOCAL transferAmount IS min(quantity,measureTankResource(tank,resource,"SPACE")).
			syncTransfer(from,tank,transferAmount,resource).
			SET quantity TO quantity - transferAmount.
		}		
		return.
	}

	print "This should never happen".
	return.

}



LOCAL FUNCTION balanceResource
{
	PARAMETER tankList.
	PARAMETER resource.
	PARAMETER tankFillRatio IS fillRatio(tankList,resource).

	IF tankList:LENGTH > 1
	{
		//Take one tank from the list
		LOCAL currentTank IS tankList[0].
		tankList:REMOVE(0).

		//Balance that tank, using the rest as reservoir
		LOCAL tankCapacity IS measureTankResource(tankList,resource,"CAPACITY").
		LOCAL tankLoad IS measureTankResource(tankList,resource,"AMOUNT").
		LOCAL targetLoad IS tankCapacity * tankFillRatio.
		LOCAL loadDifference IS targetLoad - tankLoad.

		syncTransfer(currentTank,tankList,loadDifference,resource).

		//Balance the rest of the tanks
		//Note: must carry fill ratio from the top call, computation would give a different result w/o the already
		//balanced tanks

		balanceResource(tankList,resource,tankFillRatio).
	}
	

}

enumerateSystems().
print "LF % = " + round(fillRatio(listTanks(),"LiquidFuel")*100).
print "OX % = " + round(fillRatio(listTanks(),"Oxidizer")*100).

balanceResource(listTanks(),"LiquidFuel").
balanceResource(listTanks(),"Oxidizer").

//balancePayload().

//syncTransfer(LIST(tankerSystems["TankA"],tankerSystems["TankB"]),LIST(tankerSystems["TankC"],tankerSystems["TankD"]),20,"LiquidFuel").

//syncTransfer(LIST(tankerSystems["TankA"],tankerSystems["TankB"]),LIST(tankerSystems["TankC"],tankerSystems["TankD"]),420,"Oxidizer").
