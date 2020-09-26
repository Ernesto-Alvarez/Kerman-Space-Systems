@LazyGlobal OFF.

RUNONCEPATH("functionregistry").
RUNONCEPATH("readline").
RUNONCEPATH("inthandler").

//ANTICOLLISION BEACON SUBSYSTEM
//Controls station self illumination external lights
//Beacons are exclusively W485 omnidirectional lights, arranged in groups of 4 around a space station module
//They are tagged with the "SS Beacon" tag.


LOCAL beaconLightRegistry IS lexicon().
LOCAL beaconLightMode IS "Auto".
LOCAL beaconLightIntensityOn IS 1.
LOCAL beaconLightIntensityOff IS 0.
LOCAL lastPriorityAssignmentDay IS TIME:DAY.		//We change beacon priority each day

GLOBAL FUNCTION beaconsOff
{
	SET beaconLightMode TO "Off".
	beaconControl(beaconLightIntensityOff).
}

GLOBAL FUNCTION beaconsOn
{
	SET beaconLightMode TO "On".
	beaconControl(beaconLightIntensityOn).
}

GLOBAL FUNCTION beaconsAuto
{
	SET beaconLightMode TO "Auto".
	beaconCheck().
}

LOCAL FUNCTION beaconReset
{
	If beaconLightMode = "On"
		beaconsOn().
	IF beaconLightMode = "Off"
		beaconsOff().
	IF beaconLightMode = "Auto"
		beaconsAuto().
}

LOCAL FUNCTION setBeaconIntensity
{
	PARAMETER off.
	PARAMETER on.
	SET beaconLightIntensityOn TO on.
	SET beaconLightIntensityOff TO off.
	beaconReset().
	
}

LOCAL FUNCTION setBeaconColour
{
	PARAMETER red.
	PARAMETER green.
	PARAMETER blue.

	FOR i in beaconLightRegistry:keys
	{
		i:getModule("ModuleColoredLensLight"):SETFIELD("light r",red).
		i:getModule("ModuleColoredLensLight"):SETFIELD("light g",green).
		i:getModule("ModuleColoredLensLight"):SETFIELD("light b",blue).
	}
}

LOCAL FUNCTION cooperativeBeaconEnumeration
{
	//Clean registry
	GLOBAL beaconLightRegistry IS lexicon().

	//Add every tagged beacon light to the registry
	FOR i IN Core:Vessel:PartsTagged("SS Beacon")
	{
		SET beaconLightRegistry[i] TO 0.
	}
	reprioritiseBeacons().
}

LOCAL FUNCTION reprioritiseBeacons
{
	//Take every beacon on the registry and assign a random priority

	FOR i IN beaconLightRegistry:keys
	{
		SET beaconLightRegistry[i] TO random().
	}
	SET lastPriorityAssignmentDay TO TIME:DAY.
	beaconReset().
}

LOCAL FUNCTION beaconControl
{
	//For every lamp in the registry, turn on everything with lower priority value, turn off everything else.
	//Use priority to turn roughly that proportion of the station beacons to save power
	//Priority 1 turns every beacon on, 0 turns off everything

	PARAMETER priority.
	FOR i IN beaconLightRegistry:keys
	{
		IF beaconLightRegistry[i] < priority
		{
			i:getModule("ModuleColoredLensLight"):DoAction("turn light on",True).	
		}
		ELSE
		{
			i:getModule("ModuleColoredLensLight"):DoAction("turn light off",True).
		}
	}
}

GLOBAL FUNCTION beaconCheck
{
//	print "Anticollision beacon check called".
	IF TIME:DAY <> lastPriorityAssignmentDay
	{
		reprioritiseBeacons.
	}

	IF beaconLightMode = "Auto"
	{
		IF Core:Vessel:Sensors:Light = 0		//If we're in the dark
		{
			beaconControl(beaconLightIntensityOn).			//Turn on the anticollision beacons
		}
		ELSE
		{
			beaconControl(beaconLightIntensityOff).			//Else turn them off (we're visible anyway)
		}
	}

}

GLOBAL FUNCTION beaconColour
{
	//Configure beacon colour, reading terminal input

	LOCAL newRed IS -1.
	LOCAL newGreen IS -1.
	LOCAL newBLue IS -1.

	print "Enter new RED intensity (0 to 1)".
	SET newRed TO readScalar().
	IF ( newRed < 0 OR newRed > 1 )
	{
		print "Nonsense value entered, aborting".
		return False.
	}

	print "Enter new GREEN intensity (0 to 1)".
	SET newGreen TO readScalar().
	IF ( newGreen < 0 OR newGreen > 1 )
	{
		print "Nonsense value entered, aborting".
		return False.
	}

	print "Enter new BLUE intensity (0 to 1)".
	SET newBlue TO readScalar().
	IF ( newBlue < 0 OR newBlue > 1 )
	{
		print "Nonsense value entered, aborting".
		return False.
	}
	setBeaconColour(newRed,newGreen,newBlue).
	return True.
}

GLOBAL FUNCTION beaconIntensity
{
	//Configure how many beacons are on/off for each cicle

	LOCAL onIntensity IS -1.
	LOCAL offIntensity IS -1.
	
	
	print "Enter new off value (0 to 1)".
	SET offIntensity TO readScalar().
	IF ( offIntensity < 0 OR offIntensity > 1)
	{
		print "Nonsense value entered, aborting".
		return False.
	}


	print "Enter new on value (0 to 1)".
	SET onIntensity TO readScalar().
	IF ( offIntensity < 0 OR offIntensity > 1)
	{
		print "Nonsense value entered, aborting".
		return False.
	}

	IF ( offIntensity > onIntensity )
	{
		print "OFF intensity should be lower than ON intensity. Aborting.".
		return False.
	}

	setBeaconIntensity(offIntensity,onIntensity).
	return True.

}


print "Loading beacon system".

//INIT ROUTINE
cooperativeBeaconEnumeration().
beaconCheck().

//Function registration
LOCAL bCheck IS registerFunction(beaconCheck@,"Beacon","beaconCheck","Run automatic beacon routine check").
registerFunction(beaconsOff@,"Beacon","beaconsOff","Turn off all anticollision beacons").
registerFunction(beaconsOn@,"Beacon","beaconsOn","Turn on all anticollision beacons").
registerFunction(beaconsAuto@,"Beacon","beaconsAuto","Anticollision beacons to automatic mode").
registerFunction(beaconColour@,"Beacon","beaconColour","Set beacon colour").
registerFunction(beaconIntensity@,"Beacon","beaconIntensity","Set beacon system intensity").
registerFunction(reprioritiseBeacons@,"Beacon","reprioritiseBeacons","Manually reprioritize beacons").

//Interrupt vector registration

ON (Core:Vessel:Sensors:Light = 0)
{
	trigger(bCheck).
}

print "Beacon system loaded".