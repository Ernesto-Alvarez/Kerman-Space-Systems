@LazyGlobal off.

//Tug operations

RUNONCEPATH("blocks").
RUNONCEPATH("functionregistry").
RUNONCEPATH("readline").

LOCAL tugFunctionRegistry IS multilist(list("module","name","description","pointer")).
LOCAL tugSystems IS lexicon().
LOCAL ST6FunctionRegistry IS multilist(list("module","name","description","pointer")).
LOCAL ST7FunctionRegistry IS multilist(list("module","name","description","pointer")).

//Tug states:
// 	Shut down:
//		Batteries: Don't care, connected, recharging
//		Reaction wheels: disabled
//		OKTO: Hibernating		
//		RCS: OFF
//		MP Tanks: Disabled, 0% full
//		Radios: OFF
//	Readiness:
//		Batteries: Full, connected
//		Reaction wheels: disabled
//		OKTO: Hibernating		
//		RCS: OFF
//		MP Tanks: Disabled, full
//		Radios: ON (at least 1)
//	Pre-Flight:
//		Batteries: Full, connected
//		Reaction wheels: enabled (All or just OKTO)
//		OKTO: Running
//		RCS: ON
//		MP Tanks: Enabled, full
//		Radios: ON

//Available procedures
//Set state
//Autolaunch (set to pre-flight, undock)

//System list
//	Batteries	
//	CPU
//	Reaction wheels
//	RCS
//	MP Tanks
//	Radios
//	LFOX tanks, internal
//	LFOX tanks, external
//	Engine
//	Solar panels
//	Docking ports (station, other)
//	Lamps


LOCAL stationParts IS depotParts().

LOCAL FUNCTION enumerateSystems
{
	PARAMETER partList.
	LOCAL tugSystems IS lexicon("Batteries",list(),"CPU",list(),"Gyros",list(),"RCS",list(),"MPTanks",list(),"Radios",list(),"ExternalTanks",list(),"InternalTanks",list(),"Engine",list(),"SolarPanels",list(),"DockingPorts",list(),"Lamps",list()).
	
	FOR part IN partList
	{
		FOR resource IN part:RESOURCES
		{
			//Switch resource
			IF resource:NAME = "ElectricCharge"
			{
				tugSystems["Batteries"]:ADD(part).
				IF part:NAME:STARTSWITH("probeCore")
				{
					tugSystems["CPU"]:ADD(part).
					tugSystems["Gyros"]:ADD(part).
				}
			}
			IF resource:NAME = "MonoPropellant"
				tugSystems["MPTanks"]:ADD(part).

			IF resource:NAME = "LiquidFuel"
			{
				//OSCAR-B are internal tanks, baguettes are external
				IF part:NAME:STARTSWITH("externalTankCapsule")
					tugSystems["ExternalTanks"]:ADD(part).
				IF part:NAME:STARTSWITH("miniFuelTank")
					tugSystems["InternalTanks"]:ADD(part).
			}
		}
		IF part:NAME:STARTSWITH("sasModule")
			tugSystems["Gyros"]:ADD(part).

		IF part:NAME:STARTSWITH("RCSBlock") OR part:NAME:STARTSWITH("linearRcs")
			tugSystems["RCS"]:ADD(part).
			
		IF part:NAME:STARTSWITH("longAntenna") OR part:NAME:STARTSWITH("surfAntenna")
			tugSystems["Radios"]:ADD(part).

		IF part:NAME:STARTSWITH("spotLight")
			tugSystems["Lamps"]:ADD(part).

		IF part:NAME:STARTSWITH("SolarPanels")
			tugSystems["SolarPanels"]:ADD(part).		

		IF part:NAME:STARTSWITH("liquidEngine")
			tugSystems["Engine"]:ADD(part).

		IF part:NAME:STARTSWITH("dockingPort")
			tugSystems["DockingPorts"]:ADD(part).
	}

	return tugSystems.
	
}


LOCAL FUNCTION enumerateSystemsIF
{
	return enumerateSystems(getVisitorPartList()).
}

LOCAL FUNCTION depotParts
{
	return blockPartList(CORE:PART).
}

LOCAL FUNCTION rechargeBatteries
{
	LOCAL tugBatteries IS tugSystems["Batteries"].
	LOCAL chargeNeeded IS measureTankResource(tugBatteries,"ElectricCharge","SPACE").

	syncTransfer(stationParts,tugBatteries,chargeNeeded,"ElectricCharge").
}

LOCAL FUNCTION loadMP
{
	PARAMETER percent.
	

	LOCAL capacity IS measureTankResource(tugSystems["MPTanks"],"MonoPropellant","CAPACITY").
	LOCAL load IS measureTankResource(tugSystems["MPTanks"],"MonoPropellant","AMOUNT").

	LOCAL targetLoad IS capacity * (percent / 100).

	syncTransfer(stationParts,tugSystems["MPTanks"],targetLoad - load,"MonoPropellant").
}

LOCAL FUNCTION fillMP
{
	loadMP(100).
}

LOCAL FUNCTION DrainMP
{
	loadMP(0).
}

LOCAL FUNCTION loadLFOX
{
	PARAMETER percent.
	PARAMETER internal IS True.
	
	IF internal = True
		LOCAL tanks IS tugSystems["InternalTanks"].
	ELSE
		LOCAL tanks IS tugSystems["ExternalTanks"].

	LOCAL capacity IS measureTankResource(tanks,"LiquidFuel","CAPACITY") + measureTankResource(tanks,"Oxidizer","CAPACITY").
	LOCAL load IS measureTankResource(tanks,"LiquidFuel","AMOUNT") + measureTankResource(tanks,"Oxidizer","AMOUNT").

	LOCAL targetLoad IS capacity * (percent / 100).

	syncTransfer(stationParts,tanks,targetLoad - load,"LFOX").
}

//BUG: Using percentages for filling and draining introduces problems if LF/OX is not balanced.

LOCAL FUNCTION DrainLFOX
{
	loadLFOX(0,True).
	loadLFOX(0,False).
}

LOCAL FUNCTION loadInternalLFOX
{
	loadLFOX(100,True).
}

LOCAL FUNCTION loadExternalLFOX
{
	loadLFOX(100,False).
}

LOCAL FUNCTION drainExternalLFOX
{
	loadLFOX(0,False).
}

LOCAL FUNCTION tugOps
{
	SET tugSystems TO enumerateSystems(getVisitorPartList()).

	//Switch tug type
	LOCAL id IS identifyBlock(tugSystems["CPU"][0]).	//May not work for dumb objects
	print id.

	
	//Generic function selection

	
	IF id = "ST-7 High Endurance Tug"
	{
		LOCAL funcSelection IS MLpager("ST7 tug operations",ST7FunctionRegistry,lexicon("Description",40)).

		CLEARSCREEN.
		if funcSelection = -1		//Invalid value or abort
		{
			print "Execution aborted".
		}
		ELSE
		{
			print "Executing function " + funcSelection.
			callFunction(funcSelection,ST7FunctionRegistry).
			print "Tug Operation complete".
		}

	}

	IF id = "ST-6 Space Station Tug"
	{
		LOCAL funcSelection IS MLpager("ST6 tug operations",ST6FunctionRegistry,lexicon("Description",40)).	

		CLEARSCREEN.
		if funcSelection = -1		//Invalid value or abort
		{
			print "Execution aborted".
		}
		ELSE
		{
			print "Executing function " + funcSelection.
			callFunction(funcSelection,ST6FunctionRegistry).
			print "Tug Operation complete".
		}

	}


	IF NOT ( id = "ST-6 Space Station Tug" OR id = "ST-7 High Endurance Tug")
	{
		LOCAL funcSelection IS MLpager(list("Tug not identified","Generic functions only"),tugFunctionRegistry,lexicon("Description",40)).

		CLEARSCREEN.
		if funcSelection = -1		//Invalid value or abort
		{
			print "Execution aborted".
		}
		ELSE
		{
			print "Executing function " + funcSelection.
			callFunction(funcSelection,tugFunctionRegistry).
			print "Tug Operation complete".
		}

	}

}

LOCAL FUNCTION activateRadio
{
	//Activate N antennas
	PARAMETER numberAntennas IS 100.	//100 is a default value that should work as "all"
	LOCAL antennaIndex IS 0.		

	FOR antenna IN tugsystems["Radios"]
	{
		//RemoteTech
		IF antennaIndex < numberAntennas
			antenna:GETMODULE("ModuleRTAntenna"):DOACTION("activate",True).
		ELSE
			antenna:GETMODULE("ModuleRTAntenna"):DOACTION("deactivate",True).
		SET antennaIndex TO antennaIndex + 1.
	//Stock
	}

}

LOCAL FUNCTION activateRadioIF
{
	print "Enter number of antennas".
	activateRadio(readScalar(0)).
}

LOCAL FUNCTION actuateTankValves
{
	PARAMETER resource.
	PARAMETER enabled.

	FOR system IN tugSystems:KEYS
		FOR part IN tugSystems[system]
			FOR tankResource IN part:RESOURCES
				IF tankResource:NAME = resource
					SET tankResource:ENABLED to enabled.

}


LOCAL FUNCTION actuateTankValvesIF
{
	LOCAL resource IS choice(list("LiquidFuel","Oxidizer","MonoPropellant"),"Select resource").
	LOCAL state IS choice(list("Disable","Enable"),"Should tank be enabled?").
	IF state = "Enable"
		SET state TO True.
	ELSE
		SET state TO False.

	actuateTankValves(resource,state).
}

LOCAL FUNCTION enableGenericSystem
{
	PARAMETER system.
	PARAMETER state.

	FOR i IN tugSystems[system]
		SET i:ENABLE TO state.
}

LOCAL FUNCTION enableGyros
{
	PARAMETER state.
	FOR wheel IN tugSystems["Gyros"]
		IF state = True
			wheel:GETMODULE("ModuleReactionWheel"):DOACTION("activate wheel",True).
		ELSE
			wheel:GETMODULE("ModuleReactionWheel"):DOACTION("deactivate wheel",True).
}

LOCAL FUNCTION enableEngine
{
	PARAMETER state.
	FOR engine IN tugSystems["Engine"]
		IF state = True
			engine:GETMODULE("ModuleEnginesFX"):DOACTION("activate engine",True).
		ELSE
			engine:GETMODULE("ModuleEnginesFX"):DOACTION("shutdown engine",True).

}

LOCAL FUNCTION enableLamps
{
	PARAMETER state.
	FOR panel in tugSystems["Lamps"]
		IF state = True
			panel:GETMODULE("ModuleLight"):DOACTION("turn light on",True).
		ELSE
			panel:GETMODULE("ModuleLight"):DOACTION("turn light off",True).
}


LOCAL FUNCTION enablePanels
{
	PARAMETER state.
	FOR panel in tugSystems["SolarPanels"]
		IF state = True
			panel:GETMODULE("ModuleDeployableSolarPanel"):DOACTION("extend solar panel",True).
		ELSE
			panel:GETMODULE("ModuleDeployableSolarPanel"):DOACTION("retract solar panel",True).
		
}

LOCAL FUNCTION activateCPU
{
	PARAMETER state.
	FOR cpu in tugSystems["CPU"]
		IF state = True
		{
			cpu:GETMODULE("ModuleCommand"):SETFIELD("hibernation",False).
			cpu:GETMODULE("ModuleCommand"):SETFIELD("hibernate in warp",True).
		}
		ELSE
			cpu:GETMODULE("ModuleCommand"):SETFIELD("hibernation",True).
			//Where are the SAS controls?

}

LOCAL FUNCTION shutDownTug
{
	drainLFOX().
	drainMP().
	enableGyros(False).
	enableEngine(False).
	actuateTankValves("Monopropellant",False).
	actuateTankValves("LiquidFuel",False).
	actuateTankValves("Oxidizer",False).
	activateRadio(0).
	enableLamps(False).
	enablePanels(False).
	activateCPU(False).
}

LOCAL FUNCTION readinessModeST6
{
	rechargeBatteries().
	fillMP().
	enableGyros(False).
	actuateTankValves("Monopropellant",False).
	activateRadio(1).
	activateCPU(False).
}

LOCAL FUNCTION flightModeST6
{
	rechargeBatteries().
	fillMP().
	enableGyros(True).
	actuateTankValves("Monopropellant",True).
	activateRadio(4).		//All ST-6 have at least 2 radios and at most 4
	activateCPU(True).
}

LOCAL FUNCTION readinessModeST7
{
	rechargeBatteries().
	loadInternalLFOX().
	fillMP().
	enableGyros(False).
	enableEngine(False).
	actuateTankValves("Monopropellant",False).
	actuateTankValves("LiquidFuel",False).
	actuateTankValves("Oxidizer",False).
	activateRadio(1).
	enableLamps(False).
	enablePanels(False).
	activateCPU(False).
}

LOCAL FUNCTION flightModeST7
{
	PARAMETER externalFuel IS True.

	rechargeBatteries().
	loadInternalLFOX().
	IF externalFuel
		loadExternalLFOX().
	ELSE
		drainExternalLFOX().
	fillMP().
	enableGyros(True).
	enableEngine(True).
	actuateTankValves("Monopropellant",True).
	actuateTankValves("LiquidFuel",True).
	actuateTankValves("Oxidizer",True).
	activateRadio(3).
	enableLamps(False).
	enablePanels(True).
	activateCPU(True).
}

LOCAL FUNCTION flightModeInternalST7
{
	flightModeST7(False).
}

LOCAL FUNCTION ST6Autolaunch
{
	flightModeST6().
	for i in tugSystems["DockingPorts"]
		i:UNDOCK().
}


LOCAL FUNCTION ST7Autolaunch
{
	PARAMETER externalFuel IS True.

	flightModeST7().
	for i in tugSystems["DockingPorts"]
		i:UNDOCK().
}

LOCAL FUNCTION ST7AutolaunchInternal
{
	ST7Autolaunch(False).
}

registerFunction(shutDownTug@,"Systems","shutDownTug","Shut down tug",ST6FunctionRegistry).
registerFunction(readinessModeST6@,"Systems","readinessModeST6","Set to readiness mode",ST6FunctionRegistry).
registerFunction(flightModeST6@,"Systems","flightModeST6","Set to flight mode",ST6FunctionRegistry).
registerFunction(ST6Autolaunch@,"Systems","ST6Autolaunch","Launch",ST6FunctionRegistry).

registerFunction(shutDownTug@,"Systems","shutDownTug","Shut down tug",ST7FunctionRegistry).
registerFunction(readinessModeST7@,"Systems","readinessModeST7","Set to readiness mode",ST7FunctionRegistry).
registerFunction(flightModeST7@,"Systems","flightModeST7","Set to flight mode (full tanks)",ST7FunctionRegistry).
registerFunction(flightModeInternalST7@,"Systems","flightModeInternalST7","Set to flight mode (internal tanks only)",ST7FunctionRegistry).
registerFunction(ST7Autolaunch@,"Systems","ST7Autolaunch","Launch (full tanks)",ST7FunctionRegistry).
registerFunction(ST7AutolaunchInternal@,"Systems","ST7AutolaunchInternal","Launch (internal fuel only)",ST7FunctionRegistry).

registerFunction(tugOps@,"Systems","tugOps","Tug Ops").

registerFunction(DrainLFOX@,"Systems","DrainLFOX","Drain LFOX tanks",tugFunctionRegistry).
registerFunction(loadInternalLFOX@,"Systems","loadInternalLFOX","Fill Internal LFOX tanks",tugFunctionRegistry).
registerFunction(loadExternalLFOX@,"Systems","loadExternalLFOX","Fill External LFOX tanks",tugFunctionRegistry).
registerFunction(fillMP@,"Systems","fillMP","Fill MP tanks",tugFunctionRegistry).
registerFunction(drainMP@,"Systems","drainMP","Drain MP tanks",tugFunctionRegistry).
registerFunction(rechargeBatteries@,"Systems","rechargeBatteries","Recharge Batteries tanks",tugFunctionRegistry).
registerFunction(activateRadioIF@,"Systems","activateRadioIF","Activate radios",tugFunctionRegistry).
registerFunction(shutDownTug@,"Systems","shutDownTug","Shut down tug",tugFunctionRegistry).