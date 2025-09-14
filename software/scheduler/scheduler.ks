//	SCHEDULER
//	Process control object that acts as a multitasking scheduler
//	The scheduler contains data structures that are used to control multiple "daemon threads" running as triggers
//	The idea is that with the scheduler, you can take a function and create a process that will run that function at designated intervals
//	The scheduler can have the necessary info so that a monitor process can launch (and re-launch) tasks as needed. The information contained in the scheduler also allows each task to know whether to run, pause or terminate.

//	The scheduler data types are:
//	(PID,Delegate,Run period, Next run time, Process status)	->	Run table
//	Integer								->	Next PID to assign
//	(implicit) (Delegate, Period)					->	Process loading table


//	Process status
//	R	Running
//	P	Paused

//Constructor: create an empty scheduler
//Do we run the "init" task at this point?
//Let´s not for now, but we'll need one if we want to be able to control processes

GLOBAL FUNCTION scheduler
{
	LOCAL newScheduler IS lexicon().
	SET newScheduler["typeId"] TO "KSS-Scheduler".
	SET newScheduler["runtable"] TO lexicon().
	SET newScheduler["nextPID"] TO 1.
	set newScheduler["dispatcherID"] TO 0.

	RETURN newScheduler.
}

GLOBAL FUNCTION execProcess
{
	PARAMETER self.
	PARAMETER funcPointer.
	PARAMETER runPeriod.
	PARAMETER paused IS false.
	PARAMETER description IS "Undescribed function".

	LOCAL pid IS self["nextPID"].
	SET self["nextPID"] TO self["nextPID"] + 1.

	SET self["runtable"][pid] TO lexicon().
	SET self["runtable"][pid]["PID"] TO pid.
	SET self["runtable"][pid]["funcPointer"] TO funcPointer.
	SET self["runtable"][pid]["runPeriod"] TO runPeriod.
	SET self["runtable"][pid]["nextRun"] TO TIME:SECONDS.
	SET self["runtable"][pid]["description"] TO description.
	IF paused SET self["runtable"][pid]["status"] TO "P".
	ELSE SET self["runtable"][pid]["status"] TO "R".

	launchDispatcher(self).
	return self["runtable"][pid]["PID"].
}

LOCAL FUNCTION launchDispatcher
{
	PARAMETER self.
	SET self["dispatcherID"] TO self["dispatcherID"] + 1.
	LOCAL ID IS self["dispatcherID"].
	IF self["nextPid"] > 1 dispatcher(self,ID).
}

GLOBAL FUNCTION pauseProcess
{
	PARAMETER self.
	PARAMETER pid.

	SET self["runtable"][pid]["status"] TO "P".
}

GLOBAL FUNCTION continueProcess
{
	PARAMETER self.
	PARAMETER pid.

	SET self["runtable"][pid]["status"] TO "R".
}

GLOBAL FUNCTION terminateProcess
{
	PARAMETER self.
	PARAMETER PID.

	self["runtable"]:REMOVE(PID).
	IF self["runtable"]:LENGTH = 0 SET self["dispatcherID"] TO self["dispatcherID"] + 1.
	ELSE launchDispatcher(self).
}

LOCAL FUNCTION dispatcher
{
	PARAMETER self.
	PARAMETER ID.

	//Determine if this dispatcher thread is the current one, self kill if not

	IF not self["dispatcherID"] = ID return FALSE.

	//Determine which processes should be ran now and recompute run times

	LOCAL toRun IS list().
	LOCAL now IS TIME:SECONDS.

	FOR proc IN self["runtable"]:VALUES
	{
		IF proc["nextRun"] < now 
		{
			SET proc["nextRun"] TO now + proc["runPeriod"].
			IF proc["status"] = "R" toRun:ADD(proc["funcPointer"]).
		}
	}

	//Determine next process to be run

	set nextTime TO 9999999999999999999999999999999.

	FOR proc IN self["runtable"]:VALUES
		IF nextTime > proc["nextRun"] SET nextTime to proc["nextRun"].

	WHEN nextTime < TIME:SECONDS THEN dispatcher(self,ID).

	//Run ready processes
	FOR func in toRun func:CALL.
}	


//GLOBAL FUNCTION daemon

//	PARAMETER self.
//	PARAMETER PID.



//THIS IDEA WORKS
//
//LOCAL nextRun IS TIME:SECONDS + 20.
//WHEN nextRun < TIME:SECONDS THEN daemon().
//
//LOCAL FUNCTION daemon
//{
//	print("daemon").
//	SET nextRun TO TIME:SECONDS + 10.
//	WHEN nextRun < TIME:SECONDS THEN daemon().
//}
//
//UNTIL FALSE
//{
//	WAIT 1.
//	print(nextRun).
//	print(TIME:SECONDS).
//}
