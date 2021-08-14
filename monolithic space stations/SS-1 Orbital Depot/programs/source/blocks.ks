@LazyGlobal off.

//Block enumeration and identification
//Given a part, obtain the parts of a block (a set of parts limited by clampotrons)
//and the block root part (the part closest to the root within the block).
//Also provides identification services using tags with part numbers.
//Block part enumeration is also responsibility of this module

//This should be great for optimizing away
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
SET partNumbers["KSS-0025"] TO "R-2 LFOX Tanker".

GLOBAL FUNCTION blockRootPart
//Given a part, locate the block's root part, usually a clampotron
{
	PARAMETER input.

	//A clampotron is the module root, as long as it's connected to next module's clampotron or is the root part
	//A clampotron whose parent is another part IS NOT the module root, it just hangs from another part

	//The ship's root part
	IF NOT input:HASPARENT		
		return input.

	//A clampotron connected to another clampotron (a block root)
	//Note, this does not work with claws properly (goes up to next module)
	IF input:ISTYPE("DockingPort") AND input:PARENT:ISTYPE("DockingPort")
		return input.
	
	return blockRootPart(input:PARENT).
}

GLOBAL FUNCTION blockPartList
//Given a part, obtain a list of parts comprising the block that holds it, optionally filtering by type
{
	PARAMETER input.
	PARAMETER filter IS list().

	LOCAL rootPart IS blockRootPart(input).
	LOCAL parts IS rootToBlockPartList(rootPart).
	IF filter:LENGTH = 0
		return parts.
	LOCAL retvalue IS list().
	FOR i in parts
		IF filter:CONTAINS(i:NAME)
			retvalue:ADD(i).
	return retvalue.
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

LOCAL FUNCTION rootToBlockPartList
//Given a block root, start the DFS search to enumerate all parts of a space station block
{
	PARAMETER input.
	LOCAL result IS list(input).

	FOR i IN input:CHILDREN			//We need to scan, even if we're already at a clampotron
	{
		IF NOT input:ISTYPE("DockingPort") OR NOT i:ISTYPE("DockingPort")
		//Special case, if we have a clampotron as vessel root, we should not explore on the connected side
		{
			LOCAL subtree IS rootToBlockPartListNext(i).
			FOR j IN subtree
				result:ADD(j).
		}
	}
	return result.

}

LOCAL FUNCTION rootToBlockPartListNext
//Given a part, do a depth first search on the part tree stopping at block limits
{
	PARAMETER input.

	LOCAL result IS list(input).

	IF input:ISTYPE("DockingPort")
		return result.

	FOR i IN input:CHILDREN
	{
		LOCAL subtree IS rootToBlockPartListNext(i).
		FOR j IN subtree
			result:ADD(j).
	}
	return result.
}

GLOBAL FUNCTION adjacencyList
{
	PARAMETER inputPart.
	LOCAL retvalue IS list().

	IF inputPart:HASPARENT
		retvalue:ADD(inputPart:PARENT:NAME).

	FOR i IN inputPart:CHILDREN
		retvalue:ADD(i:NAME).

	return retvalue.
}

Print "Block enumerator loaded".

