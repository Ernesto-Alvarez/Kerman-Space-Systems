@LazyGlobal Off.

RUNONCEPATH("functionregistry").

//Interrupt handler
//Records and controls triggering of registered functions

LOCAL intVector IS lexicon().

GLOBAL FUNCTION trigger
{
	PARAMETER functionNumber.
//	print "Triggered " + functionNumber.
	SET intVector[functionNumber] TO True. 

}

GLOBAL FUNCTION handle
{
//	print "Interrupt Handler".
	FOR i IN intVector:KEYS
	{
		IF intVector[i] = True
		{
//			print "Handling " + i.
			callFunction(i).
			SET intVector[i] TO False.
		}
	}
}

Print "Interrupt handler loaded".