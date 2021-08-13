@LazyGlobal Off.

//List pager
//Takes a list and generates a menu prompting the user to select a value.
//Returns an integer with the response

RUNONCEPATH("readline").
RUNONCEPATH("multilist").

GLOBAL ERRNO_ABORTED IS -1.

LOCAL FUNCTION select
{
	PARAMETER max.
	print "Select value".
	LOCAL selection IS readScalar(-1).
	CLEARSCREEN.
	if ( selection < 0 OR selection >= max )
	{
		print "Nonsense number entered, aborting".
		return ERRNO_ABORTED.
	}
	return selection.
}

GLOBAL FUNCTION pager
{
	PARAMETER systemMessage.
	PARAMETER input.
	PARAMETER start IS 0.
	PARAMETER page IS 10.
	
	LOCAL max is input:LENGTH.

	IF systemMessage:ISTYPE("String")
		SET systemMessage TO list(systemMessage).

	//Print system message
	CLEARSCREEN.
	FOR i IN systemMessage
		print i.
	print " ".


	//Print current page number
	FROM { LOCAL i IS start. } UNTIL i = max OR i = start+page  STEP { SET i to i+1. } DO
	{
		print i:TOSTRING:PADLEFT(3) + " " + input[i]:PADRIGHT(36).
	}

	print " ".
	print "Select using number keys.".
	print "ENTER to manually select value.".
	print "BACKSPACE to exit.".
	print "PGUP/PGDN for previous/next page.".

	//Get menu command

	LOCAL readKey IS TERMINAL:Input:getChar().

	//Which character is it?

	IF readKey = TERMINAL:Input:PAGEUPCURSOR
	{
		IF start-10 >= 0
			return pager(systemMessage,input,start-10).
		ELSE
			return pager(systemMessage,input,start).

	}
	IF readKey = TERMINAL:Input:PAGEDOWNCURSOR
	{
		IF start+10 < max
			return pager(systemMessage,input,start+10).
		ELSE
			return pager(systemMessage,input,start).
	}
	IF readKey = TERMINAL:Input:RETURN
		return select(input:LENGTH).


	IF readKey = TERMINAL:Input:BACKSPACE
		return ERRNO_ABORTED.


	LOCAL terminalInputs IS lexicon("0",0,"1",1,"2",2,"3",3,"4",4,"5",5,"6",6,"7",7,"8",8,"9",9,"0",0).

	IF terminalInputs:KEYS:CONTAINS(readkey) AND start+terminalInputs[readkey] < max
		return start+terminalInputs[readkey].
	
	return pager(systemMessage,input,start).

}

GLOBAL FUNCTION MLpager
{
	PARAMETER systemMessage.
	PARAMETER input.
	PARAMETER fieldSizes.

	//Convert multilist to regular list
	LOCAL compactedML IS list().

	FROM { LOCAL i IS 0. } UNTIL i = MLLength(input) STEP { SET i TO i+1. } DO
	{
		LOCAL line IS "".

		FOR j IN fieldSizes:KEYS
		{
			LOCAL field IS MLreadCell(input,i,j).
			IF field:LENGTH > fieldSizes[j]
			{
				SET field TO field:SUBSTRING(0,fieldSizes[j]-1).
			}
			
			SET field TO field:PADRIGHT(fieldSizes[j]).
			SET line TO line + field.
		}
		compactedML:ADD(line).
	}
	return pager(systemMessage,compactedML).

}

GLOBAL FUNCTION choice		//Take a list of items, return a chosen item by user
{
	PARAMETER choiceList.
	PARAMETER systemMessage IS "Choose an item to continue".
	PARAMETER abortValue IS False.

	LOCAL selector IS False.

	SET selector TO pager(systemMessage,choiceList).
	IF selector = ERRNO_ABORTED
		return abortValue.

	return choiceList[selector].
}

print "Pager loaded".