@LazyGlobal off.

RUNONCEPATH("tankersystems").
RUNONCEPATH("resourcexfer").

//=======Target enumeration=======

LOCAL managedResources IS LIST("LiquidFuel","Oxidizer").
LOCAL theirTanks IS Lexicon().
LOCAL myTanks IS Lexicon().


LOCAL FUNCTION enumerateTargetTanks
{
	initTargetDB().

	LOCAL RESLIST IS CORE:VESSEL:RESOURCES.
	
	FOR resource in RESLIST						//FOR all resource types
		IF managedResources:CONTAINS(resource:NAME)		//If we're managing that resource
			FOR tank in resource:PARTS			//Take a list of all tanks containing it
				IF NOT myTanks[resource:NAME]:CONTAINS(tank)
					theirTanks[resource:NAME]:ADD(tank).  //And append to their tank list except for our tanks

// At the end, we should have a lexicon of all resources, with list of tanks that are not ours
}

LOCAL FUNCTION initTargetDB
{
	SET theirTanks TO Lexicon().
	FOR res IN managedResources
		SET theirTanks[res] TO LIST().
}

LOCAL FUNCTION initMyDB
{
	SET myTanks TO Lexicon().
	SET myTanks["LiquidFuel"] TO listTanks().
	SET myTanks["Oxidizer"] TO listTanks().
}

LOCAL FUNCTION fuelingStatus
{
	IF getDockingAdaptor():HASPARTNER
		LOCAL dockingStatus IS "Docked to target".
	ELSE
		LOCAL dockingStatus IS  "Not Docked".
	print "Docking status: " + dockingStatus.


	print "=====Tanker Status======".
	print "Resource       Qty       Capacity  Free     % full".
	FOR resource IN managedResources
	{
		LOCAL quantity IS measureTankResource(myTanks[resource],resource,"AMOUNT").
		LOCAL capacity IS measureTankResource(myTanks[resource],resource,"CAPACITY").
		LOCAL freeSpace IS measureTankResource(myTanks[resource],resource,"SPACE").
		LOCAL percent IS 0.
		IF measureTankResource(myTanks[resource],resource,"CAPACITY") > 0
			SET percent TO 100 * measureTankResource(myTanks[resource],resource,"AMOUNT") / measureTankResource(myTanks[resource],resource,"CAPACITY").

	print resource:PADRIGHT(10) + round(quantity,1):TOSTRING:PADLEFT(10) + round(capacity,1):TOSTRING:PADLEFT(10) + round(freeSpace,1):TOSTRING:PADLEFT(10) + round(percent,1):TOSTRING:PADLEFT(10).

	}

	print "=====Target Status======".
	print "Resource       Qty       Capacity  Free     % full".
	FOR resource IN managedResources
	{
		LOCAL quantity IS measureTankResource(theirTanks[resource],resource,"AMOUNT").
		LOCAL capacity IS measureTankResource(theirTanks[resource],resource,"CAPACITY").
		LOCAL freeSpace IS measureTankResource(theirTanks[resource],resource,"SPACE").
		LOCAL percent IS 0.
		IF measureTankResource(theirTanks[resource],resource,"CAPACITY") > 0
			SET percent TO 100 * measureTankResource(theirTanks[resource],resource,"AMOUNT") / measureTankResource(theirTanks[resource],resource,"CAPACITY").

	print resource:PADRIGHT(10) + round(quantity):TOSTRING:PADLEFT(10) + round(capacity):TOSTRING:PADLEFT(10) + round(freeSpace):TOSTRING:PADLEFT(10) + round(percent):TOSTRING:PADLEFT(10).
	}

	//Consistency check

	//Check if there are target tanks listed
	LOCAL targetTanksPresent IS false.
	FOR resource in theirTanks:KEYS
		IF theirTanks[resource]:LENGTH > 0
			SET targetTanksPresent TO true.

	//If there are target tanks but we're not docked of vice versa, write warning
	IF (getDockingAdaptor():HASPARTNER AND NOT targetTanksPresent) OR (NOT getDockingAdaptor():HASPARTNER AND targetTanksPresent)
		print "WARNING: Target database appears to be stale. Re enumerate target.".
}


//=======Fuel transfer=======

GLOBAL FUNCTION manualLFTransfer
{
	PARAMETER amount.
	print amount.
	syncTransfer(myTanks["LiquidFuel"],theirTanks["LiquidFuel"],amount,"LiquidFuel").
}

GLOBAL FUNCTION manualOXTransfer
{
	PARAMETER amount.

	syncTransfer(myTanks["Oxidizer"],theirTanks["Oxidizer"],amount,"Oxidizer").
}

GLOBAL FUNCTION manualLFOXTransfer
{
	PARAMETER amount.

	LOCAL LFamount IS amount * 0.45.
	LOCAL OXamount IS amount * 0.55.

	manualLFTransfer(LFamount).
	manualOXTransfer(OXamount).
}

GLOBAL FUNCTION manualLFTransferIF
{
	print "Input amount of LF to transfer to target (negative values take from target to tanker).".
	LOCAL amount IS readScalar(0).

	manualLFTransfer(amount).
}

GLOBAL FUNCTION manualOXTransferIF
{
	print "Input amount of OX to transfer to target (negative values take from target to tanker).".
	LOCAL amount IS readScalar(0).
	manualOXTransfer(amount).
}

GLOBAL FUNCTION manualLFOXTransferIF
{
	print "Input amount of LFOX to transfer to target (negative values take from target to tanker).".
	LOCAL amount IS readScalar(0).
	manualLFOXTransfer(amount).
}

GLOBAL FUNCTION autoRefuelAbsolute
{
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

GLOBAL FUNCTION autoRefuelAbsoluteIF
{
	print "Input amount of LFOX that the target tanks should have".
	LOCAL amount IS readScalar().
	IF amount < 0
	{
		print "Nonsense value entered. Aborting".
		return.
	}
	autoRefuelAbsolute(amount).
}

GLOBAL FUNCTION autoRefuelPercentIF
{
	print "Input percentage of LFOX that the target tanks should have".
	print "Do not use this function for ships with grossly unbalanced LF/OX capacities".
	LOCAL percent IS readScalar().
	IF percent < 0
	{
		print "Nonsense value entered. Aborting".
		return.
	}

	LOCAL amount IS (percent / 100) * ( measureTankResource(theirTanks["LiquidFuel"],"LiquidFuel","CAPACITY") + measureTankResource(theirTanks["LiquidFuel"],"Oxidizer","CAPACITY")).

	autoRefuelAbsolute(amount).
}

GLOBAL FUNCTION fillTanks
{
	manualLFTransfer( measureTankResource(theirTanks["LiquidFuel"],"LiquidFuel","SPACE") ).
	manualOXTransfer( measureTankResource(theirTanks["Oxidizer"],"Oxidizer","SPACE") ).
}

GLOBAL FUNCTION drainTanks
{
	manualLFTransfer( -1 * measureTankResource(theirTanks["LiquidFuel"],"LiquidFuel","AMOUNT") ).
	manualOXTransfer( -1 * measureTankResource(theirTanks["Oxidizer"],"Oxidizer","AMOUNT") ).
}

//Module Init
initMyDB().
initTargetDB().

//Function registration
registerFunction(enumerateTargetTanks@,"Fueling","enumerateTargetTanks","Enumerate refuelling target").
registerFunction(fuelingStatus@,"Fueling","fuelingStatus","Fueling status report").
registerFunction(manualLFOXTransferIF@,"Fueling","manualLFOXTransferIF","Fuel transfer: LFOX").
registerFunction(fillTanks@,"Fueling","fillTanks","Fuel Transfer: Fill tanks").
registerFunction(drainTanks@,"Fueling","drainTanks","Fuel Transfer: Drain tanks").

registerFunction(autoRefuelAbsoluteIF@,"Fueling","autoRefuelAbsoluteIF","Autorefuel to absolute quantity").
registerFunction(autoRefuelPercentIF@,"Fueling","autoRefuelPercentIF","Autorefuel to percentage of tank capacity").

registerFunction(manualLFTransferIF@,"Fueling","manualLFTransferIF","Manual fuel transfer: Liquid Fuel").
registerFunction(manualOXTransferIF@,"Fueling","manualOXTransferIF","Manual fuel transfer: Oxidizer").


registerFunction(initMyDB@,"Fueling","initMyDB","Rebuild local fuel tank database").