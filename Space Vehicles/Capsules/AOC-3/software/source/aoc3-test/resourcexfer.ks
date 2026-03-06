@LazyGlobal off.

GLOBAL FUNCTION syncTransfer
{
	PARAMETER from.
	PARAMETER to.
	PARAMETER quantity.
	PARAMETER resource.

	IF quantity = 0							//Nothing to transfer
		return.

	IF quantity < 0							//Reverse transfer
		return syncTransfer(to,from,quantity * -1,resource).

	IF resource = "LFOX"
	{
		syncTransfer(from,to,quantity*0.45,"LiquidFuel").
		syncTransfer(from,to,quantity*0.55,"Oxidizer").
	}

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
	//This should be unreachable
}

GLOBAL FUNCTION measureTankResource
{
	PARAMETER tankList.
	PARAMETER resource.
	PARAMETER parameter IS "AMOUNT".

	IF tankList:ISTYPE("Part")
		SET tankList TO LIST(tankList).

	LOCAL quantity IS 0.

	FOR tank IN tankList
		FOR j in tank:RESOURCES
			if j:NAME = resource
			{
				IF parameter = "CAPACITY"
					SET quantity TO quantity + j:CAPACITY.
				IF parameter = "AMOUNT"
					SET quantity TO quantity + j:AMOUNT.
				IF parameter = "SPACE"
					SET quantity TO quantity + ( j:CAPACITY - j:AMOUNT ).
			}
	return quantity.
}