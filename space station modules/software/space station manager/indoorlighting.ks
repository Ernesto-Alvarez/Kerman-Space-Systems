@LazyGlobal off.

//Indoor lighting control
//Controls habitat lights. Can set them to on, off or automatically, depending on whether there is a kerbal in a part or not.

RUNONCEPATH("functionregistry").
RUNONCEPATH("crewmanifest").
RUNONCEPATH("cron").

LOCAL lightMode IS "Auto".

GLOBAL FUNCTION indoorLightsOff
{
	SET lightMode TO "Off".
	FOR i in Core:Vessel:Parts
	{
		IF i:MODULES:Contains("moduleColorChanger") 
			IF i:getmodule("moduleColorChanger"):ALLEVENTNAMES:CONTAINS("lights off")
				i:getModule("ModuleColorChanger"):DoEvent("lights off").
	}

}

GLOBAL FUNCTION indoorLightsOn
{
	SET lightMode TO "On".
	FOR i in Core:Vessel:Parts
	{
		IF i:MODULES:Contains("moduleColorChanger") 
			IF i:getmodule("moduleColorChanger"):ALLEVENTNAMES:CONTAINS("lights on")
				i:getModule("ModuleColorChanger"):DoEvent("lights on").

	}

}

GLOBAL FUNCTION indoorLightsAuto
{
	SET lightMode TO "Auto".
	FOR i in Core:Vessel:Parts
	{
		IF i:MODULES:Contains("moduleColorChanger")
		{
			IF crewedPart(i) 
			{
				IF i:getmodule("moduleColorChanger"):ALLEVENTNAMES:CONTAINS("lights on")
					i:getModule("ModuleColorChanger"):DoEvent("lights on").
			}
			ELSE
			{
				IF i:getmodule("moduleColorChanger"):ALLEVENTNAMES:CONTAINS("lights off")
					i:getModule("ModuleColorChanger"):DoEvent("lights off").
			}
		}
	}

}

GLOBAL FUNCTION indoorLightsCheck
{
	IF lightMode = "Auto"
		indoorLightsAuto().
}



print "Loading indoor lighting controls".

//Register function
registerFunction(indoorLightsOff@,"IndoorLighting","indoorLightsOff","Turn off cabin lights").
registerFunction(indoorLightsOn@,"IndoorLighting","indoorLightsOn","Turn on cabin lights").
registerFunction(indoorLightsAuto@,"IndoorLighting","indoorLightsAuto","Turn on cabin lights on crewed parts").
LOCAL check IS registerFunction(indoorLightsCheck@,"IndoorLighting","indoorLightsCheck","Run automatic indoor light check").

//Register cron

addCrontab(check,3).

print "Indoor lighting loaded".

