@LazyGlobal off.

RUNONCEPATH("pager").

//System menus
//These are the tools that can be used to create menus which contain functions to be called
//and form the core of the kss-shell.
//Based on the function registry, but simpler and with some extra functions to simplify menu creation

//Menus contain: system message (to be displayed when called), description and function pointer.

GLOBAL FUNCTION createMenu
{
	PARAMETER systemMessage IS "Select item".

	return lexicon("Message",systemMessage,"Functions",Multilist(list("description","pointer"))).

}

GLOBAL FUNCTION registerFunction
{
	PARAMETER menu.
	PARAMETER pointer.
	PARAMETER brief IS "Undescribed function".

	LOCAL newNumber IS MLlength(menu["Functions"]).
	
	MLadd(menu["Functions"],lexicon("pointer",pointer,"description",brief)).

	return newNumber.
}

GLOBAL FUNCTION callFunction
{
	PARAMETER menu.
	PARAMETER number.

	
	IF not number:ISTYPE("Scalar")
	{
		return False.
	}

	IF number < 0
	{
		return False.
	}


	IF number >= MLlength(menu["Functions"])
	{
		return False.
	}

	LOCAL fp IS MLreadCell(menu["Functions"],number,"pointer").

	return fp:CALL.
}

GLOBAL FUNCTION callMenu
{
	PARAMETER menu.

	LOCAL funcSelection IS MLpager(menu["Message"],menu["Functions"],lexicon("Description",56)).

	CLEARSCREEN.
	if funcSelection = -1		//Invalid value or abort
		return False.
	ELSE
		return callFunction(menu,funcSelection).

}









