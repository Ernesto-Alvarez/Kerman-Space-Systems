@LazyGlobal Off.

RUNONCEPATH("multilist").

//FUNCTION REGISTRY
//Registers functions callable from SSM software

//Registry contents: function number, function module, function name, function description (short) and pointer to the function

//Function numbers are assigned by registry
//De-registering is not allowed

LOCAL functionRegistry IS multilist(list("module","name","description","pointer")).

GLOBAL FUNCTION registerFunction
{
	PARAMETER pointer.
	PARAMETER module.
	PARAMETER name.
	PARAMETER brief IS "Undescribed function".

	LOCAL newNumber IS MLlength(functionRegistry).
	
	MLadd(functionRegistry,lexicon("module",module,"pointer",pointer,"name",name,"description",brief)).

	return newNumber.
}

GLOBAL FUNCTION callFunction
{
	PARAMETER number.
	
	IF not number:ISTYPE("Scalar")
	{
		return False.
	}

	IF number < 0
	{
		return False.
	}


	IF number >= MLlength(functionRegistry)
	{
		return False.
	}

	LOCAL fp IS MLreadCell(functionRegistry,number,"pointer").

	fp:CALL.
	return True.

}

GLOBAL FUNCTION functionList
{
	LOCAL retval IS list().
	FROM { LOCAL i IS 0. } UNTIL i = countFunctions() STEP { set i TO i+1. } DO
	{
		retval:ADD(MLreadCell(functionRegistry,i,"description")).
	}
	return retval.
}

GLOBAL FUNCTION countFunctions
{
	return MLlength(functionRegistry).
}

GLOBAL FUNCTION functionName
{
	PARAMETER funcNumber.
	return MLreadCell(functionRegistry,funcNumber,"name").
}

GLOBAL FUNCTION functionDescription
{
	PARAMETER funcNumber.
	return MLreadCell(functionRegistry,funcNumber,"description").
}

GLOBAL FUNCTION selectFunction
{
	PARAMETER systemMessage IS list("Select function").
	LOCAL fieldSizes IS lexicon("description",20).
	
	return MLpager(systemMessage,functionRegistry,fieldSizes).

}

GLOBAL FUNCTION callFunctionInteractive
{
	LOCAL systemMessage IS list("Select function to execute").
	LOCAL functionNumber IS selectFunction(systemMessage).

	callFunction(functionNumber).
}

print "Function registry loaded".