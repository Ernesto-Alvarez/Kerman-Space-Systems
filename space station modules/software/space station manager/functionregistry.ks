@LazyGlobal Off.

//FUNCTION REGISTRY
//Registers functions callable from SSM software

//Registry contents: function number, function module, function name, function description (short), function description (long)

//Function numbers are assigned by registry
//De-registering is not allowed

LOCAL functionPointers IS list().
LOCAL functionModules IS list().
LOCAL functionNames IS list().
LOCAL functionDescriptions IS list().

GLOBAL FUNCTION registerFunction
{
	PARAMETER pointer.
	PARAMETER module.
	PARAMETER name.
	PARAMETER brief IS "Undescribed function".

	LOCAL newNumber IS functionPointers:LENGTH.
	
	functionPointers:ADD(pointer).
	functionModules:ADD(module).
	functionNames:ADD(name).
	functionDescriptions:ADD(brief).

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


	IF number >= functionPointers:LENGTH
	{
		return False.
	}

	functionPointers[number]:CALL.
	return True.

}

GLOBAL FUNCTION functionList
{
	return functionDescriptions.
}

GLOBAL FUNCTION countFunctions
{
	return functionPointers:LENGTH.
}

GLOBAL FUNCTION functionName
{
	PARAMETER funcNumber.
	return functionNames[funcNumber].
}

GLOBAL FUNCTION functionDescription
{
	PARAMETER funcNumber.
	return functionDescriptions[funcNumber].
}

print "Function registry loaded".