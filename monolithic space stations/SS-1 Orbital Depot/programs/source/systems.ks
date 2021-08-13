@LazyGlobal off.

//R-2 tanker system manager

RUNONCEPATH("blocks").
RUNONCEPATH("resources").
RUNONCEPATH("menu").

LOCAL stationSystems IS lexicon().

GLOBAL FUNCTION enumerateSystems
{
	LOCAL cpu IS core:part.
	LOCAL blockRoot IS blockRootPart(cpu).
	SET stationSystems["allParts"] TO blockPartList(blockRoot).

	SET stationSystems["clampotrons"] TO lexicon().

	FOR i in stationSystems["allParts"]
	{
		IF i:ISTYPE("DockingPort")
			IF adjacencyList(i):CONTAINS("adapterSmallMiniShort")
			{	//Port T
				SET stationSystems["clampotrons"]["T"] TO i.
			}
			ELSE
			{	//Port A or B
				if (stationSystems["clampotrons"]:KEYS):CONTAINS("A")		//Port A has been assigned
					SET stationSystems["clampotrons"]["B"] TO i.
				ELSE
					SET stationSystems["clampotrons"]["A"] TO i.
			}
	}
	return True.
}

GLOBAL FUNCTION balanceTanks
{
	balanceResource(stationSystems["allParts"]:COPY,"LiquidFuel").
	balanceResource(stationSystems["allParts"]:COPY,"Oxidizer").
	return True.
}

LOCAL FUNCTION dockingReport
{
	FOR port IN stationSystems["clampotrons"]:KEYS
	{
		IF stationSystems["clampotrons"][port]:HASPARTNER
			LOCAL dockingStatus IS "Docked to " + identifyBlock(stationSystems["clampotrons"][port]:PARTNER).
		ELSE
			LOCAL dockingStatus IS "Undocked".
	

		print "Port " + port + " Status: " + dockingStatus.
	}
	return True.
}

LOCAL FUNCTION highlightVisitor
{
	LOCAL dockingPort IS selectPort().
	if dockingPort = False
		return False.
	print "Highlighting selected visitor".
	highlightBlock(stationSystems["clampotrons"][dockingPort]:PARTNER).
	WAIT 5.
	highlightBlock(stationSystems["clampotrons"][dockingPort]:PARTNER,False).
	return True.
}

GLOBAL FUNCTION stationResourceReport
{
	resourceReport(stationSystems["allParts"]).
	return True.
}

LOCAL FUNCTION secureTanks
{
	enableResourceFlow(stationSystems["allParts"],"*",False).
	enableResourceFlow(stationSystems["allParts"],"ElectricCharge",True).
	return True.
}


GLOBAL FUNCTION selectPort
{
	LOCAL visitorRoster is multilist(list("Port","Type","Part")).
	FOR i IN stationSystems["clampotrons"]:KEYS
		IF stationSystems["clampotrons"][i]:HASPARTNER
			{
			LOCAL data is lexicon().
			SET data["Port"] TO i.
			SET data["Type"] TO identifyBlock(stationSystems["clampotrons"][i]:PARTNER).
			SET data["Part"] TO stationSystems["clampotrons"][i]:PARTNER.			
			MLadd(visitorRoster,data).
			}

	LOCAL selection IS MLpager(list("Select visiting craft"),visitorRoster,lexicon("Port",10,"Type",30)).
	IF selection = ERRNO_ABORTED
		return False.

	return MLreadCell(visitorRoster,selection,"Port").
}

GLOBAL FUNCTION myTanks
{
	return stationSystems["allParts"]:COPY.
}

GLOBAL FUNCTION getDockingAdaptor
{
	PARAMETER portName.
	return stationSystems["clampotrons"][portName].
}

//Module init
enumerateSystems().	//We should call enumerateWithCache instead, if we saved the system state.

//Function Registration
LOCAL systemsMenu IS createMenu("Tanker system functions").

LOCAL FUNCTION callSystemsMenu
{
	return callMenu(systemsMenu).
}


registerFunction(systemsMenu,enumerateSystems@,"Re-enumerate space station systems").
registerFunction(systemsMenu,balanceTanks@,"Balance fuel tanks").
registerFunction(systemsMenu,dockingReport@,"Docking port status").
registerFunction(systemsMenu,highlightVisitor@,"Highlight visitor").
registerFunction(systemsMenu,secureTanks@,"Secure tanks (remove tanks from flow)").
registerFunction(systemsMenu,stationResourceReport@,"Depot resource status").

registerFunction(mainMenu,callSystemsMenu@,"Station systems").


print "Station system manager loaded".
