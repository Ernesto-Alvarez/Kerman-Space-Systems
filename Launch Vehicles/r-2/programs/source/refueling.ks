@LazyGlobal off.

//R-2 refueling subsystem

RUNONCEPATH("tankersystems").
RUNONCEPATH("menu").

LOCAL visitorSystems IS lexicon().

LOCAL FUNCTION enumerateVisitor
{
	IF NOT getDockingAdaptor():HASPARTNER
	{
		SET visitorSystems["allParts"] TO list().
		return True.
	}

	LOCAL visitorClampotron IS getDockingAdaptor():PARTNER.

	SET visitorSystems["allParts"] TO blockPartList(visitorClampotron).
	return True.
}

LOCAL FUNCTION refuelingReport
{
	print "===========Tanker supplies==============".
	tankerResourceReport().
	print " ".
	print "===========Target supplies==============".
	return resourceReport(visitorSystems["allParts"]).
}

LOCAL FUNCTION fillTanks
{
	return refuelRatio(1).
}

LOCAL FUNCTION drainTanks
{
	return refuelRatio(0).
}

LOCAL FUNCTION refuelRatio
{
	PARAMETER ratio IS 1.
	loadRatio(myTanks(),visitorSystems["allParts"],"LiquidFuel",ratio).
	loadRatio(myTanks(),visitorSystems["allParts"],"Oxidizer",ratio).
	return True.
}

LOCAL FUNCTION refuelPercent
{
	print "Input percentage of LFOX that the target tanks should have".
	print "Do not use this function for ships with grossly unbalanced LF/OX capacities".
	LOCAL percent IS readScalar().
	IF percent < 0 OR percent > 100
	{
		print "Nonsense value entered. Aborting".
		return False.
	}

	LOCAL ratio IS (percent / 100).

	return refuelRatio(ratio).
}

LOCAL FUNCTION refuelAbsolute
{
	print "Input amount of LFOX that the target tanks should have".
	LOCAL amount IS readScalar().
	IF amount < 0
	{
		print "Nonsense value entered. Aborting".
		return.
	}
	
	LOCAL LF IS amount * 0.45.
	LOCAL OX IS amount * 0.55.

	loadAbsolute(myTanks(),visitorSystems["allParts"],"Oxidizer",OX).
	loadAbsolute(myTanks(),visitorSystems["allParts"],"LiquidFuel",LF).

	return True.
}

LOCAL FUNCTION manualResourceTransfer
{
	PARAMETER resource.
	PARAMETER amount.
	LOCAL theirTanks IS visitorSystems["allParts"]:COPY.
	LOCAL myTanks IS myTanks().

	syncTransfer(myTanks(),visitorSystems["allParts"],amount,resource).
	return True.
}

GLOBAL FUNCTION manualResourceTransferIF
{
	LOCAL theirTanks IS visitorSystems["allParts"]:COPY.

	UNTIL False
	{
		LOCAL resource IS choice(list("LiquidFuel","Oxidizer","LFOX","Monopropellant","ElectricCharge"),list("Select resource to transfer","BACKSPACE to end transfers"),False).

		IF resource = False
			return True.

		print "Input amount to transfer to target (negative values take from target to station).".
		LOCAL amount IS readScalar(0).
		manualResourceTransfer(resource,amount).
	}
}








//Module init
enumerateVisitor().

//Enumeration trigger
ON getDockingAdaptor():HASPARTNER
{
	enumerateVisitor().
}

//Function Registration
LOCAL refuelMenu IS createMenu("Refueling").

LOCAL FUNCTION callRefuelMenu
{
	return callMenu(refuelMenu).
}

registerFunction(refuelMenu,enumerateVisitor@,"Re-enumerate visitor").
registerFunction(refuelMenu,refuelingReport@,"Refueling report").
registerFunction(refuelMenu,fillTanks@,"Fill tanks").
registerFunction(refuelMenu,drainTanks@,"Drain tanks").
registerFunction(refuelMenu,refuelPercent@,"Auto refuel to percentage of capacity").
registerFunction(refuelMenu,refuelAbsolute@,"Auto refuel to absolute value").
registerFunction(refuelMenu,manualResourceTransferIF@,"Manual resource transfer").




registerFunction(mainMenu,callRefuelMenu@,"Fuel transfer").
print "Refueling system loaded".
