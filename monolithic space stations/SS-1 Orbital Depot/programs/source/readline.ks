@LazyGlobal off.
//READLINE
//A simple readline implementation

GLOBAL FUNCTION readLine
{
	LOCAL inputString IS "".
	LOCAL inputChar IS "".

	UNTIL False
	{
		print "INPUT: " + inputString:PADRIGHT(TERMINAL:Width - 1 - 7) AT (0,TERMINAL:Height).
		SET inputChar TO TERMINAL:Input:getChar().

		//Return pressed, end function and return line
		IF inputChar = TERMINAL:Input:RETURN
			return inputString.
	
		//Backspace, we need to erase one character, if the line has something.
		IF inputChar = TERMINAL:Input:BACKSPACE
		{
			IF inputString:LENGTH > 0
				SET inputString TO inputString:REMOVE(inputString:LENGTH - 1,1).
		}
		ELSE		//Regular character, append to the line
			SET inputString TO inputString + inputChar.
	}
}

GLOBAL FUNCTION readScalar
{
	PARAMETER errorValue IS -1.
	LOCAL retval IS readLine().
	return retval:ToScalar(errorValue).
}

print "Readline loaded".