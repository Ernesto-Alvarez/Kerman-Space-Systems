@LazyGlobal off.

//Resource management, transfer, reporting and measurement code
//Measures tank capacity and storage, and does complex resource transfers

//Measuring

LOCAL FUNCTION fillRatio
{
	PARAMETER tankList.
	PARAMETER resource.
	
	LOCAL amount IS measureTankResource(tankList,resource,"AMOUNT").
	LOCAL capacity IS measureTankResource(tankList,resource,"CAPACITY").

	IF capacity = 0
		return 0.

	return amount / capacity.
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

//Transfer

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

GLOBAL FUNCTION loadAbsolute
//Load a certain amount of resource in a target, using a reservoir to provide or absorb resources
{
	PARAMETER reservoir.
	PARAMETER target.
	PARAMETER resource.
	PARAMETER amount.

	LOCAL tankCapacity IS measureTankResource(target,resource,"CAPACITY").
	LOCAL tankLoad IS measureTankResource(target,resource,"AMOUNT").
	LOCAL loadDifference IS amount - tankLoad.

	syncTransfer(reservoir,target,loadDifference,resource).
}

GLOBAL FUNCTION loadRatio
//Load a certain resource to a ratio (0 to 1) of tank capacity, using a reservoir to provide or absorb resources
{
	PARAMETER reservoir.
	PARAMETER target.
	PARAMETER resource.
	PARAMETER ratio.

	LOCAL tankCapacity IS measureTankResource(target,resource,"CAPACITY").
	LOCAL targetLoad IS ratio * tankCapacity.

	loadAbsolute(reservoir,target,resource,targetLoad).
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
		loadRatio(tankList,currentTank,resource,tankFillRatio).

		//Balance the rest of the tanks
		//Note: must carry fill ratio from the top call, computation would give a different result w/o the already
		//balanced tanks

		balanceResource(tankList,resource,tankFillRatio).
	}
}

//Reporting

GLOBAL FUNCTION resourceReport
//Supply report generator, set for a 60x40 screen
{
	PARAMETER parts.

	LOCAL resourcesPresent IS list().
	
	FOR part IN parts
		FOR resource IN part:RESOURCES
			IF NOT resourcesPresent:CONTAINS(resource:NAME)
				resourcesPresent:ADD(resource:NAME).

	print "Resource                 Qty       Capacity  Free     % full".
	FOR resource IN resourcesPresent
	{
		LOCAL quantity IS measureTankResource(parts,resource,"AMOUNT").
		LOCAL capacity IS measureTankResource(parts,resource,"CAPACITY").
		LOCAL freeSpace IS measureTankResource(parts,resource,"SPACE").

		LOCAL percent IS 0.
		IF capacity > 0
			SET percent TO 100 * (quantity / capacity).

		print resource:PADRIGHT(20) + round(quantity,1):TOSTRING:PADLEFT(10) + round(capacity,1):TOSTRING:PADLEFT(10) + round(freeSpace,1):TOSTRING:PADLEFT(10) + round(percent,1):TOSTRING:PADLEFT(10).
	}
}

//Management

GLOBAL FUNCTION enableResourceFlow
{
	PARAMETER parts.
	PARAMETER resources.
	PARAMETER enabled.

	IF resources:ISTYPE("String")
		SET resources TO list(resources).

	FOR tank IN parts
		FOR tankResource IN tank:RESOURCES
			FOR resource IN resources
				IF tankResource:NAME = resource OR resource = "*"
					SET tankResource:ENABLED to enabled.
}

//Module Init

print "Resource Transfer system loaded".