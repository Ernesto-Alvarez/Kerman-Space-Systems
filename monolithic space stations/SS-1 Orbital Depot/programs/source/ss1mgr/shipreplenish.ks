@LazyGlobal off.

//Ship replenishment

RUNONCEPATH("blocks").
RUNONCEPATH("functionregistry").
RUNONCEPATH("resourcexfer").
RUNONCEPATH("pager").

LOCAL wasteResources IS list("CarbonDioxide","Waste","WasteWater","SpareParts","Ablator").

LOCAL myTanks IS enumerateMyTanks().


LOCAL FUNCTION enumerateMyTanks
{
	return enumerateShipTanks(blockPartList(core:PART)).
}

LOCAL FUNCTION enumerateVisitorTanks
{
	LOCAL parts IS getVisitorPartList().
	return enumerateShipTanks(parts).
}

LOCAL FUNCTION enumerateShipTanks
{
	PARAMETER partList.		//List of visitor ship parts

	LOCAL resources IS lexicon().

	FOR i IN partList
		FOR j in i:RESOURCES
			IF NOT wasteResources:CONTAINS(j:NAME)
			{
				IF NOT resources:KEYS:CONTAINS(j:NAME)	
					//init DB if resource not present
					SET resources[j:NAME] TO list().
			
				resources[j:NAME]:ADD(i).

				//Special case for LFOX
				IF j:NAME = "Oxidizer" OR j:NAME = "LiquidFuel"
				{
					IF NOT resources:KEYS:CONTAINS("LFOX")
						SET resources["LFOX"] TO list().

					IF NOT resources["LFOX"]:CONTAINS(i)
						resources["LFOX"]:ADD(i).
				}
			}
	return resources.
}

LOCAL FUNCTION manualResourceTransfer
{
	PARAMETER resource.
	PARAMETER amount.
	PARAMETER theirTanks.

	syncTransfer(myTanks[resource],theirTanks[resource],amount,resource).
}

GLOBAL FUNCTION manualResourceTransferIF
{
	LOCAL theirTanks IS enumerateVisitorTanks().

	LOCAL resource IS choice(myTanks:KEYS,"Select resource to transfer").

	IF NOT theirTanks:KEYS:CONTAINS(resource)
	{
		print "Resource not available on target".
		return.
	}

	print "Input amount to transfer to target (negative values take from target to station).".
	LOCAL amount IS readScalar(0).

	manualResourceTransfer(resource,amount,theirTanks).
}


LOCAL FUNCTION fuelingStatus
{
	LOCAL theirTanks IS enumerateVisitorTanks().

	reportBaseSupplies().

	print "=====Target Status======".
	print "Resource                      Qty       Capacity  Free     % full".
	FOR resource IN theirTanks:KEYS
		IF NOT (resource = "LFOX")
		{
			LOCAL quantity IS measureTankResource(theirTanks[resource],resource,"AMOUNT").
			LOCAL capacity IS measureTankResource(theirTanks[resource],resource,"CAPACITY").
			LOCAL freeSpace IS measureTankResource(theirTanks[resource],resource,"SPACE").
			LOCAL percent IS 0.
			IF measureTankResource(theirTanks[resource],resource,"CAPACITY") > 0
				SET percent TO 100 * measureTankResource(theirTanks[resource],resource,"AMOUNT") / measureTankResource(theirTanks[resource],resource,"CAPACITY").

			print resource:PADRIGHT(25) + round(quantity):TOSTRING:PADLEFT(10) + round(capacity):TOSTRING:PADLEFT(10) + round(freeSpace):TOSTRING:PADLEFT(10) + round(percent):TOSTRING:PADLEFT(10).
		}
}

LOCAL FUNCTION reportBaseSupplies
{
	print "=====Station supplies======".
	print "Resource                      Qty       Capacity  Free     % full".
	FOR resource IN myTanks:KEYS
		IF NOT (resource = "LFOX")
		{
			LOCAL quantity IS measureTankResource(myTanks[resource],resource,"AMOUNT").
			LOCAL capacity IS measureTankResource(myTanks[resource],resource,"CAPACITY").
			LOCAL freeSpace IS measureTankResource(myTanks[resource],resource,"SPACE").
			LOCAL percent IS 0.
			IF measureTankResource(myTanks[resource],resource,"CAPACITY") > 0
				SET percent TO 100 * measureTankResource(myTanks[resource],resource,"AMOUNT") / measureTankResource(myTanks[resource],resource,"CAPACITY").

			print resource:PADRIGHT(25) + round(quantity,1):TOSTRING:PADLEFT(10) + round(capacity,1):TOSTRING:PADLEFT(10) + round(freeSpace,1):TOSTRING:PADLEFT(10) + round(percent,1):TOSTRING:PADLEFT(10).

		}
}

GLOBAL FUNCTION autoReplenishAbsolute
{
	PARAMETER resource.
	PARAMETER quantity.

	LOCAL LFquantity IS quantity * 0.45.
	LOCAL OXquantity IS quantity * 0.55.

	LOCAL LFlevel IS measureTankResource(theirTanks["LiquidFuel"],"LiquidFuel","AMOUNT").
	LOCAL OXlevel IS measureTankResource(theirTanks["Oxidizer"],"Oxidizer","AMOUNT").

	LOCAL LFdelta IS LFquantity - LFlevel.
	LOCAL OXdelta IS OXquantity - OXlevel.

	manualLFTransfer(LFdelta).
	manualOXTransfer(OXdelta).

}





//Test function
LOCAL FUNCTION balanceStationTanks
{
	FOR resource IN myTanks:KEYS
		balanceResource(myTanks[resource],resource).
}

registerFunction(balanceStationTanks@,"Systems","balanceStationTanks","Balance station tanks").



//registerFunction(enumerateMyTanks@,"Systems","enumerateMyTanks","Re-enumerate station tanks").
registerFunction(manualResourceTransferIF@,"Systems","manualResourceTransferIF","Transfer resources").
registerFunction(fuelingStatus@,"Systems","fuelingStatus","Visitor supply status").
registerFunction(reportBaseSupplies@,"Systems","reportBaseSupplies","Space station supply status").