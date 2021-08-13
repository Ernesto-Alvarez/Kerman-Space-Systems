@LazyGlobal off.
RUNONCEPATH("menu").
GLOBAL FUNCTION attention
{
	callMenu(mainMenu).
}
WHEN (TERMINAL:Input:HASCHAR) THEN
{
	TERMINAL:Input:GETCHAR.
	attention().
	return True.
}
SET TERMINAL:WIDTH TO 60.
SET TERMINAL:HEIGHT TO 40.