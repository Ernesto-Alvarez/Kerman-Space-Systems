@LazyGlobal Off.

//List pager
//Takes a list and generates a menu prompting the user to select a value.
//Returns an integer with the response

RUNONCEPATH("readline").
RUNONCEPATH("multilist").

LOCAL FUNCTION select
{
	PARAMETER max.
	print "Select value".
	LOCAL selection IS readScalar(-1).
	CLEARSCREEN.
	if ( selection < 0 OR selection >= max )
	{
		print "Nonsense number entered, aborting".
		return -1.
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

	//Print system message
	CLEARSCREEN.
	FOR i IN systemMessage
		print i.
	print " ".


	//Print current page number
	FROM { LOCAL i IS start. } UNTIL i = max OR i = start+page  STEP { SET i to i+1. } DO
	{
		print i:TOSTRING:PADLEFT(3) + " " + input[i]:PADRIGHT(25).
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
	{
		return select(input:LENGTH).
	}
	IF readKey = TERMINAL:Input:BACKSPACE
	{
		return -1.
	}

	IF readKey = "0" and start+0 < max
	{
		return start+0.
	}

	IF readKey = "1" and start+1 < max
	{
		return start+1.
	}

	IF readKey = "2" and start+2 < max
	{
		return start+2.
	}

	IF readKey = "3" and start+3 < max
	{
		return start+3.
	}

	IF readKey = "4" and start+4 < max
	{
		return start+4.
	}

	IF readKey = "5" and start+5 < max
	{
		return start+5.
	}

	IF readKey = "6" and start+6 < max
	{
		return start+6.
	}

	IF readKey = "7" and start+7 < max
	{
		return start+7.
	}

	IF readKey = "8" and start+8 < max
	{
		return start+8.
	}

	IF readKey = "9" and start+9 < max
	{
		return start+9.
	}

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

//LOCAL ml1 IS multilist(list("c1","c2","c3")).

//MLadd(ml1,lexicon("c1","r11abcdefgaaaaaaaaaaaa","c2","r12abcdefgaaaaaaaaaaa","c3","r13abcdefgaaaaaaaaaa")).
//MLadd(ml1,lexicon("c1","r21","c2","r22","c3","r23")).
//MLadd(ml1,lexicon("c1","r31","c2","r32","c3","r33")).

//print MLPager(list("Test"),ml1,lexicon("c1",6,"c2",6,"c3",6)).

print "Pager loaded".