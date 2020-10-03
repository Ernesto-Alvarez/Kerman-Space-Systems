@LazyGlobal off.

//Base facility management
//Enumerates base blocks

RUNONCEPATH("blocks").
RUNONCEPATH("functionregistry").
RUNONCEPATH("pager").

LOCAL blockRegistry IS list().
LOCAL blockNames IS list().

//Enumerates blocks, usually starting from the root part. Works only if the base is a tree. Loops will hang this function
GLOBAL FUNCTION enumerateBlocks			
{
	PARAMETER start IS CORE:VESSEL:ROOTPART.
	PARAMETER scannedFrom IS 0.

	//Starting from the root part, enumerate its block parts, identify, register, then obtain all clampotron std pats and enumerate anything connected to them

	//Get root, parts and names	
	LOCAL blockRoot IS blockRootPart(start).
	LOCAL parts IS blockPartList(blockRoot).
	LOCAL blockName IS identifyBlock(blockRoot).

	//Register
	print "Registering " + blockName.
	blockRegistry:ADD(blockRoot).
	blockNames:ADD(blockName).

	//Find blocks attached to clampotron std and keep enumerating
	LOCAL bigClampotrons IS filterParts(parts,"dockingPort2").

	FOR port in bigClampotrons
	{
		if port:HASPARTNER and port:PARTNER <> scannedFrom
		{
			enumerateBlocks(port:PARTNER,port).
		}	

	}
}

GLOBAL FUNCTION highlightBlock
{
	PARAMETER start.
	PARAMETER enable IS True.
	
	LOCAL blockRoot IS blockRootPart(start).
	LOCAL parts IS blockPartList(blockRoot).

	FOR i IN parts
	{
		SET highlight(i,green):ENABLED to enable.
	}
	SET highlight(start,yellow):ENABLED TO enable.
	SET highlight(blockRoot,red):ENABLED TO enable.

}


LOCAL FUNCTION filterParts
{
	//Take a part list, and filter based on the start of the name
	PARAMETER bigList.
	PARAMETER filterString.

	LOCAL smallList IS list().	

	FOR i IN bigList
	{
		if i:NAME:startsWith(filterString)
		{
			smallList:ADD(i).
		}
	}	
	return smallList.
}

GLOBAL FUNCTION highlightAllModules
{
	FROM { LOCAL i IS 0. } UNTIL i >= blockRegistry:LENGTH STEP { SET i TO i+1. } DO
	{
		print blockNames[i].
		highlightBlock(blockRegistry[i]).
		WAIT 0.25.
		highlightBlock(blockRegistry[i],False).
	}
}

GLOBAL FUNCTION getBlockParts
{
	PARAMETER blockNumber.

	return blockPartList(blockRegistry[blockNumber]).
}

GLOBAL FUNCTION getNumberofBlocks
{
	return blockRegistry:LENGTH.
}

GLOBAL FUNCTION getBlockNameFromRoot
{
	PARAMETER blockRoot.
	FROM { LOCAL i IS 0. } UNTIL i = blockRegistry:LENGTH STEP { SET i TO i+1. } DO
	{
		IF blockRegistry[i] = blockRoot
			return blockNames[i].
	}
	return "Unknown".
}

GLOBAL FUNCTION showBlock
{

	LOCAL sysMessage IS list("Query which module?").
	LOCAL module IS pager(sysMessage,blockNames).

	highLightBlock(blockRegistry[module]).
	print "BLOCK INFORMATION".
	print "Type: " + blockNames[module].
	WAIT 1.
	highLightBlock(blockRegistry[module],False).
	
}

GLOBAL FUNCTION blockRoots
{
	return blockRegistry.
}

print "Loading base facility services".
print "Module enumeration in progress".
//module init
enumerateBlocks().
print "Module enumeration complete".

//print blockNames.
registerFunction(enumerateBlocks@,"Facilities","enumerateBlocks","Re-Enumerate Base Blocks").
registerFunction(highlightAllModules@,"Facilities","highlightAllModules","Highlight blocks, Base Tour").
registerFunction(showBlock@,"Facilities","showBlock","Show information about block").

print "Base facility services loading complete".