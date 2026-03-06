@LazyGlobal off.

RUNONCEPATH("scheduler").

GLOBAL FUNCTION processList
{
	PARAMETER self.

	CLEARSCREEN.
	LOCAL row IS 0.

	FOR process in self["runTable"]:VALUES
	{
		print process["PID"] AT(0,row).
		print process["RunPeriod"] AT(5,row).
		print process["Status"] AT(10,row).
		print process["Description"] AT(15,row).
		SET row TO row+1.
	}
}

print "Process Explorer version 0.2.1 loaded".