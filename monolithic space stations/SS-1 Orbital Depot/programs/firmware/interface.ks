@LazyGlobal off.

//Dependencies
RUNONCEPATH("menu").

GLOBAL FUNCTION attention
{
	LOCAL retval IS callMenu(mainMenu).

	IF retval = False
		print "Aborted".
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

SET TERMINAL:WIDTH TO 60.
SET TERMINAL:HEIGHT TO 40.

print "Interface loaded".

