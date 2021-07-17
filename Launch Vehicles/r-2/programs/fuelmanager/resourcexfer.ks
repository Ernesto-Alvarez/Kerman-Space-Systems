@LazyGlobal off.

//R-2 Tanker Resource transfer program

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



GLOBAL FUNCTION balanceResource
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

//Module Init

print "Resource Transfer system loaded".