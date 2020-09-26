@LazyGlobal off.

//Block enumeration and identification
//Given a part, obtain the parts of a block (a set of parts limited by clampotrons)
//and the block root part (the part closest to the root within the block).
//Also provides identification services using tags with part numbers.

LOCAL partNumbers IS lexicon().
SET partNumbers["KSS-0001"] TO "C4 Module".
SET partNumbers["KSS-0002"] TO "Mini Habitat".
SET partNumbers["KSS-0003"] TO "Station Hub".
SET partNumbers["KSS-0004"] TO "Inline Docking Port".
SET partNumbers["KSS-0005"] TO "Station Airlock".
SET partNumbers["KSS-0006"] TO "Station Solar PSU".
SET partNumbers["KSS-0007"] TO "Cargo Truss".
SET partNumbers["KSS-0008"] TO "Base Tankage".
SET partNumbers["KSS-0009"] TO "Tug Attachment Truss".
SET partNumbers["KSS-0010"] TO "Container, GPA".
SET partNumbers["KSS-0011"] TO "Container, GPB".
SET partNumbers["KSS-0012"] TO "Container, MP1".
SET partNumbers["KSS-0013"] TO "Container, LF400".
SET partNumbers["KSS-0014"] TO "ST-7 High Endurance Tug".
SET partNumbers["KSS-0015"] TO "ST-6 Space Station Tug".
SET partNumbers["KSS-0016"] TO "ST-5 High Endurance Tug".
SET partNumbers["KSS-0017"] TO "AOC-0 Capsule".
SET partNumbers["KSS-0018"] TO "AOC-1 Capsule".
SET partNumbers["KSS-0019"] TO "AOC-2 Capsule".
SET partNumbers["KSS-0020"] TO "AOC-3 Capsule".
SET partNumbers["KSS-0021"] TO "AOC-4 Capsule".
SET partNumbers["KSS-0022"] TO "Clampotron Adaptor: jr to std".
SET partNumbers["KSS-0023"] TO "Space Station Habitat".
SET partNumbers["KSS-0024"] TO "Orbital Depot".

GLOBAL FUNCTION blockRootPart		//Given a part, locate the block's root part, usually a clampotron
{
	PARAMETER input.

	//A clampotron is the module root, as long as it's connected to next module's clampotron or opens to space
	//(A clampotron whose parent is another part IS NOT the module root, it just hangs from another module)
	//Note: the conditional below had to be changed because one clampotron's name was "dockingPort (Container Staging Station C-100)".
	//Looks like the root part is named differently

	IF (input:NAME:STARTSWITH("dockingPort") AND (not input:HASPARENT OR input:PARENT:NAME:STARTSWITH("dockingPort") ) )
	{
		return input.
	} 
	
	IF input:HASPARENT = False		//The ship's root part
	{
		return input.
	}

	return blockRootPart(input:PARENT).
}


GLOBAL FUNCTION blockPartList				//Given a part, obtain a list of parts comprising the block that holds it
{
	PARAMETER input.

	LOCAL rootPart IS blockRootPart(input).
	return rootToBlockPartList(rootPart).
}


GLOBAL FUNCTION highlightBlock
{
	PARAMETER part.
	PARAMETER enable IS True.

	FOR i IN blockPartList(part)
	{
		SET highlight(i,green):ENABLED TO enable.
	}

	SET highlight(part,yellow):ENABLED TO enable.	
	SET highlight(blockRootPart(part),red):ENABLED TO enable.
	
}

GLOBAL FUNCTION identifyBlock
{
	PARAMETER part.
	LOCAL blockParts IS blockPartList(part).
	FOR i IN blockParts
	{
		IF partNumbers:KEYS:CONTAINS(i:TAG)
			return partNumbers[i:TAG].
	}
	return "Unknown".
	
}


LOCAL FUNCTION rootToBlockPartList		//Given a block root, start the DFS search to enumerate all parts of a space station block
{
	PARAMETER input.

	LOCAL result IS list(input).

	FOR i IN input:CHILDREN			//We need to scan, even if we're already at a clampotron
	{
		IF not input:NAME:STARTSWITH("dockingPort") OR not i:NAME:STARTSWITH("dockingPort")
		//Special case, if we have a clampotron as vessel root, we should not explore on the connected side
		{
			LOCAL subtree IS rootToBlockPartListNext(i).
			FOR j IN subtree
			{
				result:ADD(j).
			}
		}
	}
	return result.

}


LOCAL FUNCTION rootToBlockPartListNext		//Given a part, do a depth first search on the part tree stopping at block limits
{
	PARAMETER input.

	LOCAL result IS list(input).

	IF input:NAME:STARTSWITH("dockingPort")
	{
		return result.
	} 

	FOR i IN input:CHILDREN
	{
		LOCAL subtree IS rootToBlockPartListNext(i).
		FOR j IN subtree
		{
			result:ADD(j).
		}
	}
	return result.
}


Print "Block enumerator loaded".

