@LazyGlobal off.

//Dependencies
RUNONCEPATH("menu").

GLOBAL FUNCTION attention
{
	LOCAL retval IS callMenu(mainMenu).

	IF retval = False
		print "Execution incomplete".
	ELSE
		print "Execution complete".
	return.
}

//Set up terminal interrupt

WHEN (TERMINAL:Input:HASCHAR) THEN
{
	TERMINAL:Input:GETCHAR.
	attention().
	return True.
}

print "Interface loaded".

