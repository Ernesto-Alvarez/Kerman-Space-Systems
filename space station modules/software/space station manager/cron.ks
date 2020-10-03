@LazyGlobal off.

//Cron subsystem
//Registers and manages function calls that have to be done periodically

RUNONCEPATH("functionregistry").
RUNONCEPATH("pager").
RUNONCEPATH("readline").

LOCAL crontabTimes IS list().
LOCAL crontabFunctions IS list().
LOCAL crontabPeriods IS list().

LOCAL function nextRunTime
{
	PARAMETER period.
	return TIME + period.
}

GLOBAL FUNCTION addCrontab
{
	PARAMETER funcNumber.
	PARAMETER period.

	crontabFunctions:ADD(funcNumber).
	crontabPeriods:ADD(period).
	crontabTimes:ADD(nextRunTime(period)).
}

GLOBAL FUNCTION deleteCrontab
{
	PARAMETER cronIndex.
	
	crontabFunctions:REMOVE(cronIndex).
	crontabPeriods:REMOVE(cronIndex).
	crontabTimes:REMOVE(cronIndex).
}

GLOBAL FUNCTION checkCrontabs
{
//	print "Crontab check".
	LOCAL max IS crontabFunctions:LENGTH.
	FROM { LOCAL i IS 0. } UNTIL i = max STEP { SET i TO i+1. } DO
	{
//		print "Checking " + crontabFunctions[i].
		IF crontabTimes[i]:SECONDS <= TIME:SECONDS	//It's time to run this function
		{
//			print "Triggered".
			trigger(crontabFunctions[i]).		//running triggers is responsibility of the interrupt controller

			//And now, reset the run time	
			SET crontabTimes[i] TO crontabTimes[i] + crontabPeriods[i].
		}
	}
}

GLOBAL FUNCTION listCrontabsInterface
{
	LOCAL max IS crontabFunctions:LENGTH.
	LOCAL showData IS list().
	FROM { LOCAL i IS 0. } UNTIL i = max STEP { SET i TO i+1. } DO
	{
		LOCAL fnName IS functionName(crontabFunctions[i]):PADRIGHT(20):SUBSTRING(0,20).
		LOCAL fnPeriod IS crontabPeriods[i].
		LOCAL entry IS fnName + " " + fnPeriod.
		showData:ADD(entry).
	}
	LOCAL sysMessage IS list("Select entry to examine","","Idx Function            Period(sec)").
	LOCAL printIndex IS pager(sysMessage,showData).
	IF printIndex >= 0
	{
		print "Function number: " + crontabFunctions[printIndex].
		print "Function name:   " + functionName(crontabFunctions[printIndex]).
		print "Description:     " + functionDescription(crontabFunctions[printIndex]):PADRIGHT(30):SUBSTRING(0,30).
		print "Run every:       " + crontabPeriods[printIndex] + " seconds".
		LOCAL runTime IS crontabTimes[printIndex].
		print "Next run:        Year " + runTime:YEAR + ", Day " + runTime:DAY + " at " + runtime:HOUR + ":" + runtime:MINUTE + ":" + runtime:SECOND + " UT".
	}
}

GLOBAL FUNCTION addCrontabsInterface
{
	LOCAL sysMessage IS list("Select function to add to crontab").
	LOCAL addFunction IS pager(sysMessage,functionList()).
	print "Enter run interval in seconds".
	LOCAL addPeriod IS readScalar().

	IF addFunction >= 0 AND addPeriod >= 1
	{
		print "Adding function " + addFunction + " to crontab".
		addCrontab(addFunction,addPeriod).		
	}
	ELSE
	{
		print "Nonsense data entered, aborting.".
	}
}

GLOBAL FUNCTION deleteCrontabsInterface
{
	LOCAL sysMessage IS list("Select Function to remove").

	//THIS PAGING CODE IS DUPLICATED: maybe we should factor this into a page crontab functions.

	LOCAL max IS crontabFunctions:LENGTH.
	LOCAL showData IS list().
	FROM { LOCAL i IS 0. } UNTIL i = max STEP { SET i TO i+1. } DO
	{
		LOCAL entry IS functionName(crontabFunctions[i]):PADRIGHT(20):SUBSTRING(0,20) + " " + crontabPeriods[i].
		showData:ADD (entry).
	}
	SET sysMessage TO list("Select cron entry to remove").
	LOCAL removeMe IS pager(sysMessage,showData).
	if removeMe >= 0
	{
		print "Deleting crontab entry".
		deleteCrontab(removeMe).
	}
	ELSE
	{
		print "Crontab removal aborted".
	}
}

LOCAL FUNCTION setCronTrigger
{
//	print "SetCronTrigger".
	PARAMETER quantum IS 1.		//1 second granularity
	LOCAL triggerTime IS TIME:SECONDS + quantum.
	WHEN TIME:SECONDS >= triggerTime THEN
	{
		checkCrontabs().
		setCronTrigger().
		return False.	
	}
}


//Register functions
registerFunction(checkCrontabs@,"Cron","checkCrontabs","Manually check crontab and run pending jobs").
registerFunction(addCrontabsInterface@,"Cron","addCrontabsInterface","Add cron entry").
registerFunction(listCrontabsInterface@,"Cron","listCrontabsInterface","List cron entries").
registerFunction(deleteCrontabsInterface@,"Cron","deleteCrontabsInterface","Delete cron entry").


//init
LOCAL startTime IS 15.			//Wait 60 seconds to start crontab checks, to let other modules start
setCronTrigger(startTime).





