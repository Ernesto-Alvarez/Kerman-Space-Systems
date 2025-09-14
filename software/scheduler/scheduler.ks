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
//	T	Terminated (should not be present)
//	p	Pausing
//	t	Terminating
//	r	Run requested

//Constructor: create an empty scheduler
//Do we run the "init" task at this point?
//Let´s not for now, but we'll need one if we want to be able to control processes

GLOBAL FUNCTION scheduler
{
	LOCAL newScheduler IS lexicon().
	SET newScheduler["typeId"] TO "KSS-Scheduler".
	SET newScheduler["runtable"] TO lexicon().
	SET newScheduler["nextPID"] TO 1.

	RETURN newScheduler.
}

GLOBAL FUNCTION loadProcess
{
	PARAMETER self.
	PARAMETER funcPointer.
	PARAMETER runPeriod.

	LOCAL pid IS self["nextPID"].

	SET self["nextPID"] TO self["nextPID"] + 1.

	SET self["runtable"][pid] TO list().
	self["runtable"][pid]:ADD(pid).
	self["runtable"][pid]:ADD(funcPointer).
	self["runtable"][pid]:ADD(runPeriod).
	self["runtable"][pid]:ADD(TIME+runPeriod).
}

GLOBAL FUNCTION start
{
	PARAMETER self.
	IF self["nextPid"] > 1 dispatcher(self).
}

LOCAL FUNCTION dispatcher
{
	PARAMETER self.

	//Determine which processes should be ran now and recompute run times

	LOCAL toRun IS list().
	LOCAL now IS TIME:SECONDS.

	FOR proc IN self["runtable"]:VALUES
	{
		IF proc[3] < now
		{
			toRun:ADD(proc[1]).
			SET proc[3] TO now + proc[2].
		}
	}

	//Determine next process to be run

	set nextTime TO 9999999999999999999999999999999.

	FOR proc IN self["runtable"]:VALUES
		IF nextTime > proc[3] SET nextTime to proc[3].

	WHEN nextTime < TIME:SECONDS THEN dispatcher(self).

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
