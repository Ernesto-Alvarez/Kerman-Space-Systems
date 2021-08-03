@LazyGlobal off.

//Docking port management

RUNONCEPATH("blocks").
RUNONCEPATH("functionregistry").
RUNONCEPATH("multilist").

LOCAL ports IS lexicon().

LOCAL FUNCTION enumeratePorts
{
	LOCAL cpu IS core:part.
	LOCAL blockRoot IS blockRootPart(cpu).
	LOCAL blockParts IS blockPartList(blockRoot).

	LOCAL portEnumeration IS lexicon().


	FOR i in blockParts
	{

		IF i:NAME:STARTSWITH("dockingPort3")
		{

			IF adjacencyList(i):CONTAINS("adapterSmallMiniShort")
			{	//Port T
				SET portEnumeration["T"] TO i.
			}
			ELSE
			{	//Port A or B
				if (portEnumeration:KEYS):CONTAINS("A")		//Port A has been assigned
					SET portEnumeration["B"] TO i.
				ELSE
					SET portEnumeration["A"] TO i.
			}
		}
	}
	SET ports TO portEnumeration.
}

LOCAL FUNCTION showPorts
{
	
	FOR i IN ports:KEYS
		{
		IF ports[i]:HASPARTNER
			LOCAL dockingStatus IS "Docked to " + identifyBlock(ports[i]:PARTNER).
		ELSE
			LOCAL dockingStatus IS  "Not Docked".

		print "Port " + i + " status: " + dockingStatus.
		}
}


GLOBAL FUNCTION getVisitorDockingPort
{
	LOCAL visitorRoster is multilist(list("Port","Type","Name","Part")).
	FOR i IN ports:KEYS
		IF ports[i]:HASPARTNER
			{
			LOCAL data is lexicon().
			SET data["Port"] TO i.
			SET data["Type"] TO identifyBlock(ports[i]:PARTNER).
			SET data["Name"] TO "Not implemented".
			SET data["Part"] TO ports[i]:PARTNER.			
			MLadd(visitorRoster,data).
			}

	LOCAL selection IS MLpager(list("Select visiting craft"),visitorRoster,lexicon("Port",10,"Type",30)).

	return MLreadCell(visitorRoster,selection,"Part").
}


GLOBAL FUNCTION getVisitorPartList
{
	
	LOCAL dockingPort IS getVisitorDockingPort().
	return blockPartList(dockingPort).
	
}



LOCAL FUNCTION highlightVisitor
{
	LOCAL dockingPort IS getVisitorDockingPort().
	print "Highlighting selected visitor".
	highlightBlock(dockingPort).
	WAIT 5.
	highlightBlock(dockingPort,False).
}

//Module init
enumeratePorts().

//Function registration
//registerFunction(enumeratePorts@,"Systems","enumeratePorts","Re-enumerate docking ports").
registerFunction(showPorts@,"Systems","showPorts","Docking port status").
registerFunction(highlightVisitor@,"Systems","highlightVisitor","Identify visiting ship").


print "Docking port loading complete".