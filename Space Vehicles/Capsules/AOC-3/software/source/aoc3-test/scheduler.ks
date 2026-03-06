@LazyGlobal off.

//	SCHEDULER
//	Process control object that acts as a multitasking scheduler
//	The scheduler contains data structures that are used to control multiple "daemon threads" running as triggers
//	The idea is that with the scheduler, you can take a function and create a process that will run that function at designated intervals
//	The scheduler can have the necessary info so that a monitor process can launch (and re-launch) tasks as needed. The information contained in the scheduler also allows each task to know whether to run, pause or terminate.

//	The scheduler data types are:
//	(PID,Delegate,Run period, Next run time, Process status,description)	->	Run table
//	Integer									->	Next PID to assign
//	Integer									->	Dispatcher thread ID
//	(implicit) (Delegate, Period)						->	Process loading table


//	Process status
//	R	Running
//	P	Paused

//Constructor: create an empty scheduler
//Dispatcher won't run until we have at least one process running

GLOBAL FUNCTION scheduler
{
	LOCAL newScheduler IS lexicon().
	SET newScheduler["typeId"] TO "KSS-Scheduler".
	SET newScheduler["runtable"] TO lexicon().
	SET newScheduler["nextPID"] TO 1.
	set newScheduler["dispatcherID"] TO 0.

	RETURN newScheduler.
}

//PROCESS CONTROL
//exec, stop, cont and terminate functions

//exec creates a new process that calls a delegate
//process may start paused or not, as requested
//Dispatcher thread will start if it's the first process being launched
//Dispatcher thread will be renewed in any case as the new process might run before the current process to run

GLOBAL FUNCTION execProcess
{
	PARAMETER self.
	PARAMETER funcPointer.
	PARAMETER runPeriod.
	PARAMETER paused IS false.
	PARAMETER description IS "Undescribed function".

	LOCAL pid IS self["nextPID"].
	SET self["nextPID"] TO self["nextPID"] + 1.

	//This is an attempt to minimise the race condition. Entries are filled separately first and assigned as close as the dispatcher launch as possible
	LOCAL newprocess IS lexicon().
	SET newprocess["PID"] TO pid.
	SET newprocess["funcPointer"] TO funcPointer.
	SET newprocess["runPeriod"] TO runPeriod.
	SET newprocess["nextRun"] TO TIME:SECONDS.
	SET newprocess["description"] TO description.
	IF paused SET newprocess["status"] TO "P".
	ELSE SET newprocess["status"] TO "R".

	SET self["runtable"][pid] TO newprocess.	//If this instruction is atomic, there will be no race condition
	launchDispatcher(self).
	return self["runtable"][pid]["PID"].
}

//Pauses the process, setting a special status
//Paused processes are still in the process queue and processed by the dispatcher, but are inhibited from running
//Process overhead is the same as a running process and will run at its programmed time if re-enabled

GLOBAL FUNCTION pauseProcess
{
	PARAMETER self.
	PARAMETER pid.

	SET self["runtable"][pid]["status"] TO "P".
}

//The complement of the pause call
//Process runs after the call

GLOBAL FUNCTION continueProcess
{
	PARAMETER self.
	PARAMETER pid.

	SET self["runtable"][pid]["status"] TO "R".
}

//Termination function
//Process is removed from the table
//New dispatcher thread is launched in case ???. We shouldn't need a new dispatcher thread when killing processes, do we?
//If last process, bump up thread ID to kill dispatcher

GLOBAL FUNCTION terminateProcess
{
	PARAMETER self.
	PARAMETER PID.

	self["runtable"]:REMOVE(PID).
	IF self["runtable"]:LENGTH = 0 SET self["dispatcherID"] TO self["dispatcherID"] + 1.
}

//Dispatch program. The launcher assigns an ID to the thread, allowing it to self-kill if necessary
//Possible race condition: if the old launcher is running while a new process is exec'd, it might read the process entry while incomplete, crashing the system
//Could be mitigated by changing the dispatcherID in the execProcess call at the very beginning or by somehow liimting access to an entry while incomplete
//but without semaphores, a complete fix is not possible

LOCAL FUNCTION launchDispatcher
{
	PARAMETER self.
	SET self["dispatcherID"] TO self["dispatcherID"] + 1.
	LOCAL ID IS self["dispatcherID"].
	IF self["nextPid"] > 1 dispatcher(self,ID).
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

	LOCAL nextTime IS TIME:SECONDS + 9203544600000.		//will re-run once in at least 1 million years

	FOR proc IN self["runtable"]:VALUES
		IF nextTime > proc["nextRun"] SET nextTime to proc["nextRun"].

	WHEN nextTime < TIME:SECONDS THEN dispatcher(self,ID).

	//Run ready processes
	FOR func in toRun func:CALL.
}	

print "Scheduler version 0.2.1 loaded".
