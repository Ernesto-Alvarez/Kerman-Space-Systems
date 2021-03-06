@LazyGlobal off.

//Interface

//Dependencies
RUNONCEPATH("pager").


GLOBAL FUNCTION attention
{
	LOCAL terminalMessage IS list("WARNING: autonomous functions are disabled when in attention mode!","Examine function list with PGUP and PGDN","Manual selection of function with ENTER","Cancel execution with BACKSPACE","Select from list with numbers").

	LOCAL programs IS functionList().

	LOCAL funcSelection IS pager(terminalMessage,programs).

	CLEARSCREEN.
	if funcSelection = -1		//Invalid value or abort
	{
		print "Execution aborted".
	}
	ELSE
	{
		print "Executing function " + funcSelection.
		callFunction(funcSelection).
		print "Execution complete".
	}
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