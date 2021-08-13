@LazyGlobal off.

//Ship replenishment

RUNONCEPATH("systems").
RUNONCEPATH("menu").
RUNONCEPATH("resources").

LOCAL visitorSystems IS lexicon("A",list(),"B",list(),"T",list()).

GLOBAL FUNCTION getVisitorParts
{
	PARAMETER portName.

	return visitorSystems[portName].
}

LOCAL FUNCTION enumerateVisitor
{
	PARAMETER portName.

	IF NOT getDockingAdaptor(portName):HASPARTNER
	{
		SET visitorSystems[portName] TO list().
		return True.
	}

	LOCAL visitorClampotron IS getDockingAdaptor(portName):PARTNER.

	SET visitorSystems[portName] TO blockPartList(visitorClampotron).
	return True.
}

LOCAL FUNCTION reEnumerateVisitor
{
	LOCAL port IS selectPort().
	IF port = False
		return False.
	return enumerateVisitor(port).
}

LOCAL FUNCTION refuelingReport
{
	LOCAL port IS selectPort().
	IF port = False
		return False.

	print "===========Station supplies==============".
	stationResourceReport().
	print " ".
	print "===========Target supplies==============".
	resourceReport(visitorSystems[port]).
	return True.
}

LOCAL FUNCTION manualResourceTransfer
{
	PARAMETER resource.
	PARAMETER amount.
	PARAMETER port.

	LOCAL myTanks IS myTanks().
	LOCAL theirTanks IS visitorSystems[port]:COPY.

	syncTransfer(myTanks(),theirTanks,amount,resource).
	return True.
}

GLOBAL FUNCTION manualResourceTransferIF
{
	LOCAL port IS selectPort().
	IF port = False
		return False.

	UNTIL False
	{
		LOCAL resource IS choice(list("LiquidFuel","Oxidizer","LFOX","Monopropellant","ElectricCharge","Food","Water","Oxygen"),list("Select resource to transfer","BACKSPACE to end transfers"),False).

		IF resource = False
			return True.

		print "Input amount to transfer to target (negative values take from target to station).".
		LOCAL amount IS readScalar(0).
		manualResourceTransfer(resource,amount,port).
	}
}

LOCAL FUNCTION resupplyRatio
{
	PARAMETER port.
	PARAMETER resource.
	PARAMETER ratio IS 1.

	loadRatio(myTanks(),visitorSystems[port],resource,ratio).
	return True.
}

LOCAL FUNCTION refuelPercent
{
	LOCAL port IS selectPort().
	IF port = False
		return False.

	UNTIL False
	{
		LOCAL resource IS choice(list("LiquidFuel","Oxidizer","Monopropellant","ElectricCharge","Food","Water","Oxygen"),list("Select resource to resupply","BACKSPACE to end transfers"),False).

		IF resource = False
			return True.

		print "Input percentage of resource that the target tanks should have".
		LOCAL percent IS readScalar().
		IF percent < 0 OR percent > 100
		{
			print "Nonsense value entered. Aborting".
			return False.
		}

		LOCAL ratio IS (percent / 100).

		resupplyRatio(port,resource,ratio).
	}
}

LOCAL FUNCTION refuelAbsolute
{
	LOCAL port IS selectPort().
	IF port = False
		return False.

	UNTIL False
	{
		LOCAL resource IS choice(list("LiquidFuel","Oxidizer","Monopropellant","ElectricCharge","Food","Water","Oxygen"),list("Select resource to resupply","BACKSPACE to end transfers"),False).


		IF resource = False
			return True.

		print "Input amount of supply that the target tanks should have".
		LOCAL amount IS readScalar().
		IF amount < 0
		{
			print "Nonsense value entered. Aborting".
			return.
		}
		loadAbsolute(myTanks(),visitorSystems[port],resource,amount).
	}

}

//Enumeration trigger
ON getDockingAdaptor("A"):HASPARTNER
{
	enumerateVisitor("A").
}

ON getDockingAdaptor("B"):HASPARTNER
{
	enumerateVisitor("B").
}

ON getDockingAdaptor("T"):HASPARTNER
{
	enumerateVisitor("T").
}

//Module init
enumerateVisitor("A").
enumerateVisitor("B").
enumerateVisitor("T").

LOCAL FUNCTION callRefuelMenu
{
	return callMenu(refuelMenu).
}

LOCAL refuelMenu IS createMenu("Visitor resupply").

registerFunction(refuelMenu,reEnumerateVisitor@,"Re-enumerate visitor").
registerFunction(refuelMenu,refuelingReport@,"Visitor supply report").
registerFunction(refuelMenu,manualResourceTransferIF@,"Manual resource transfer").
registerFunction(mainMenu,callRefuelMenu@,"Supply transfer").
registerFunction(refuelMenu,refuelPercent@,"Auto resupply to percentage of capacity").
registerFunction(refuelMenu,refuelAbsolute@,"Auto resupply to absolute value").

