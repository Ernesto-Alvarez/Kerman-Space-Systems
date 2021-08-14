@LazyGlobal off.

//Visitor system control

RUNONCEPATH("systems").
RUNONCEPATH("resources").
RUNONCEPATH("shipreplenish").

LOCAL currentVisitor IS list().

LOCAL FUNCTION radioLevel
{
	//Activate N antennas
	PARAMETER numberAntennas IS 100.	//100 is a default value that should work as "all"
	LOCAL antennaIndex IS 0.		

	FOR antenna IN currentVisitor
	{
		//RemoteTech
		IF antenna:MODULES:CONTAINS("ModuleRTAntenna")		//We've located a RT antenna
		{
			IF antennaIndex < numberAntennas
				antenna:GETMODULE("ModuleRTAntenna"):DOACTION("activate",True).
			ELSE
				antenna:GETMODULE("ModuleRTAntenna"):DOACTION("deactivate",True).
			SET antennaIndex TO antennaIndex + 1.
		}
	//Stock
	}
}

LOCAL FUNCTION actuateTankValves
{
	PARAMETER resource.
	PARAMETER enabled.

	enableResourceFlow(currentVisitor,resource,enabled).
}

LOCAL FUNCTION enableGyros
{
	PARAMETER state.

	FOR wheel IN currentVisitor
		IF wheel:MODULES:CONTAINS("ModuleReactionWheel")
		{
			IF state = True
				wheel:GETMODULE("ModuleReactionWheel"):DOACTION("activate wheel",True).
			ELSE
				wheel:GETMODULE("ModuleReactionWheel"):DOACTION("deactivate wheel",True).
		}
}

LOCAL FUNCTION enableEngine
{
	PARAMETER state.
	FOR engine IN currentVisitor
		IF engine:MODULES:CONTAINS("ModuleEnginesFX")
		{
			IF state = True
				engine:GETMODULE("ModuleEnginesFX"):DOACTION("activate engine",True).
			ELSE
				engine:GETMODULE("ModuleEnginesFX"):DOACTION("shutdown engine",True).
		}
}

LOCAL FUNCTION shutOffLamps
{
	FOR lamp in currentVisitor
		IF lamp:MODULES:CONTAINS("ModuleLight")
			lamp:GETMODULE("ModuleLight"):DOACTION("turn light off",True).
}

LOCAL FUNCTION enablePanels
{
	PARAMETER state.
	FOR panel in currentVisitor
		IF panel:MODULES:CONTAINS("ModuleDeployableSolarPanel")
		{
			IF state = True
				panel:GETMODULE("ModuleDeployableSolarPanel"):DOACTION("extend solar panel",True).
			ELSE
				panel:GETMODULE("ModuleDeployableSolarPanel"):DOACTION("retract solar panel",True).
		}
}

LOCAL FUNCTION activateCPU
{
	PARAMETER state.
	FOR cpu in currentVisitor
	IF cpu:MODULES:CONTAINS("ModuleCommand") AND cpu:GETMODULE("ModuleCommand"):ALLFIELDS:CONTAINS("(settable) hibernation, is Boolean")
	{
		IF state = True
		{
			cpu:GETMODULE("ModuleCommand"):SETFIELD("hibernation",False).
			cpu:GETMODULE("ModuleCommand"):SETFIELD("hibernate in warp",True).
		}
		ELSE
			cpu:GETMODULE("ModuleCommand"):SETFIELD("hibernation",True).
	}

}


LOCAL FUNCTION shutDown
{
	loadRatio(myTanks(),currentVisitor,"LiquidFuel",0).
	loadRatio(myTanks(),currentVisitor,"Oxidizer",0).
	loadRatio(myTanks(),currentVisitor,"MonoPropellant",0).
	enableGyros(False).
	enableEngine(False).
	actuateTankValves("Monopropellant",False).
	actuateTankValves("LiquidFuel",False).
	actuateTankValves("Oxidizer",False).
	radioLevel(0).
	shutOffLamps().
	enablePanels(False).
	activateCPU(False).
	return True.
}

LOCAL FUNCTION readinessMode
{
	loadRatio(myTanks(),currentVisitor,"ElectricCharge",1).
	loadRatio(myTanks(),currentVisitor,"LiquidFuel",1).
	loadRatio(myTanks(),currentVisitor,"Oxidizer",1).
	loadRatio(myTanks(),currentVisitor,"MonoPropellant",1).
	enableGyros(False).
	enableEngine(False).
	actuateTankValves("Monopropellant",False).
	actuateTankValves("LiquidFuel",False).
	actuateTankValves("Oxidizer",False).
	radioLevel(1).
	enablePanels(False).
	activateCPU(False).
	return True.
}

LOCAL FUNCTION flightMode
{
	loadRatio(myTanks(),currentVisitor,"ElectricCharge",1).
	loadRatio(myTanks(),currentVisitor,"LiquidFuel",1).
	loadRatio(myTanks(),currentVisitor,"Oxidizer",1).
	loadRatio(myTanks(),currentVisitor,"MonoPropellant",1).
	enableGyros(True).
	enableEngine(True).
	actuateTankValves("Monopropellant",True).
	actuateTankValves("LiquidFuel",True).
	actuateTankValves("Oxidizer",True).
	radioLevel().		//Default of full activation
	enablePanels(True).
	activateCPU(True).
	return True.
}

LOCAL FUNCTION callVisitorMenu
{
	SET currentVisitor TO selectPort(True).
	IF currentVisitor:ISTYPE("Bool")
		return False.
	return callMenu(visitorMenu).
}

LOCAL visitorMenu IS createMenu("Ship ops").

registerFunction(visitorMenu,shutDown@,"Shut down").
registerFunction(visitorMenu,readinessMode@,"Readiness mode").
registerFunction(visitorMenu,flightMode@,"flight mode").

registerFunction(mainMenu,callVisitorMenu@,"Ship ops").

print "Ship ops system loaded".