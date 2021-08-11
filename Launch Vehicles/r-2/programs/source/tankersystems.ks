@LazyGlobal off.

//R-2 tanker system manager

RUNONCEPATH("blocks").
RUNONCEPATH("resources").
RUNONCEPATH("menu").

LOCAL tankerSystems IS lexicon().

GLOBAL FUNCTION enumerateSystems
{
	LOCAL cpu IS core:part.
	LOCAL blockRoot IS blockRootPart(cpu).
	SET tankerSystems["allParts"] TO blockPartList(blockRoot).

	FOR i in tankerSystems["allParts"]
	{
		//Docking adaptor is unique
		IF i:ISTYPE("DockingPort")
			SET tankerSystems["Clampotron"] TO i.
	}
	return True.
}

GLOBAL FUNCTION balanceTanks
{
	balanceResource(tankerSystems["allParts"]:COPY,"LiquidFuel").
	balanceResource(tankerSystems["allParts"]:COPY,"Oxidizer").
	return True.
}

GLOBAL FUNCTION getDockingAdaptor
{
	return tankerSystems["Clampotron"].
}

LOCAL FUNCTION openTankValves
{
	enableResourceFlow(tankerSystems["allParts"],list("LiquidFuel","Oxidizer"),True).
	return True.
}

LOCAL FUNCTION closeTankValves
{
	enableResourceFlow(tankerSystems["allParts"],list("LiquidFuel","Oxidizer"),False).
	return True.
}

GLOBAL FUNCTION tankerResourceReport
{
	resourceReport(tankerSystems["allParts"]).
	return True.
}

GLOBAL FUNCTION myTanks
{
	return tankerSystems["allParts"]:COPY.
}

LOCAL FUNCTION dockingReport
{
	IF tankerSystems["Clampotron"]:HASPARTNER
		LOCAL dockingStatus IS "Docked to " + identifyBlock(tankerSystems["Clampotron"]:PARTNER).
	ELSE
		LOCAL dockingStatus IS "Undocked".
	

	print "Status: " + dockingStatus.
	return True.
}

//Module init
enumerateSystems().	//We should call enumerateWithCache instead, if we saved the system state.

//Function Registration
LOCAL systemsMenu IS createMenu("Tanker system functions").

LOCAL FUNCTION callSystemsMenu
{
	return callMenu(systemsMenu).
}


registerFunction(systemsMenu,enumerateSystems@,"Re-enumerate tanker systems").
registerFunction(systemsMenu,balanceTanks@,"Balance fuel tanks").
registerFunction(systemsMenu,openTankValves@,"Open LFOX tank valves").
registerFunction(systemsMenu,closeTankValves@,"Close LFOX tank valves").
registerFunction(systemsMenu,tankerResourceReport@,"Tanker resource status").
registerFunction(systemsMenu,dockingReport@,"Docking port status").
registerFunction(mainMenu,callSystemsMenu@,"Tanker systems").


print "Tanker system manager loaded".
