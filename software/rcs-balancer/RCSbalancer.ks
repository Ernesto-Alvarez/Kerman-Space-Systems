@LazyGlobal off.
RUNONCEPATH("scheduler").

GLOBAL FUNCTION relative
{
	PARAMETER input.

	LOCAL X IS ship:facing:forevector:normalized.
	LOCAL Y IS ship:facing:starvector:normalized.
	LOCAL Z IS ship:facing:topvector:normalized.

	return(v(input * X, input * Y, input * Z)).
}

GLOBAL FUNCTION rounded
{
	PARAMETER input.
	return(v(round(input:x),round(input:y),round(input:z))).
}

GLOBAL FUNCTION RCSBalancer
{
	PARAMETER scheduler.
	PARAMETER enginePairs.

	LOCAL newBalancer IS lexicon().

	SET newBalancer["scheduler"] TO scheduler.
	SET newBalancer["runStatus"] TO FALSE.
	SET newBalancer["runFunctions"] TO list().

	//Rolling this into a loop causes only one of the engine pairs to calibrate!
	//Started happening after introducing the relative coordinates

	LOCAL balanceFunction IS { balanceTwo(enginePairs[0][0],enginePairs[0][1]). }.
	LOCAL pid IS execProcess(scheduler,balanceFunction,0.1,TRUE,"RCS Balancer " + enginePairs[0][2]).
	newBalancer["runFunctions"]:ADD(pid).

	LOCAL balanceFunction IS { balanceTwo(enginePairs[1][0],enginePairs[1][1]). }.
	LOCAL pid IS execProcess(scheduler,balanceFunction,0.1,TRUE,"RCS Balancer " + enginePairs[1][2]).
	newBalancer["runFunctions"]:ADD(pid).

	LOCAL balanceFunction IS { balanceTwo(enginePairs[2][0],enginePairs[2][1]). }.
	LOCAL pid IS execProcess(scheduler,balanceFunction,0.1,TRUE,"RCS Balancer " + enginePairs[2][2]).
	newBalancer["runFunctions"]:ADD(pid).

	LOCAL balanceFunction IS { balanceTwo(enginePairs[3][0],enginePairs[3][1]). }.
	LOCAL pid IS execProcess(scheduler,balanceFunction,0.1,TRUE,"RCS Balancer " + enginePairs[3][2]).
	newBalancer["runFunctions"]:ADD(pid).

//	FOR pair in enginePairs
//	{
//		LOCAL balanceFunction IS { balanceTwo(pair[0],pair[1]). }.
//		LOCAL pid IS execProcess(scheduler,balanceFunction,0.1,TRUE,"RCS Balancer " + pair[2]).
//		newBalancer["runFunctions"]:ADD(pid).
//	}

	loadStatus(newBalancer).

	IF newBalancer["runStatus"]
		startBalancer(newBalancer).

	return newBalancer.
}

GLOBAL FUNCTION startBalancer
{
	PARAMETER self.
	FOR process in self["runFunctions"]
	{
		continueProcess(self["scheduler"],process).
	}
	SET self["runStatus"] TO TRUE.
	saveStatus(self).
}

GLOBAL FUNCTION stopBalancer
{
	PARAMETER self.
	FOR process in self["runFunctions"]
	{
		pauseProcess(self["scheduler"],process).
	}
	SET self["runStatus"] TO FALSE.
	saveStatus(self).
}

LOCAL FUNCTION balanceTwo
{
	PARAMETER engineOne.
	PARAMETER engineTwo.

	//Compute distances to CoM in the X axis
	LOCAL E1R IS relative(engineOne:position):x.
	LOCAL E2R IS relative(engineTwo:position):x.

	////print "E1 Pos".
	//print E1R.
	//print "E2 Pos".
	//print E2R.

	//Derate engines based on angle to top/side vectors
	LOCAL E1D IS sin(vectorangle(relative(engineOne:facing:vector),rounded(relative(engineOne:facing:vector)))).
	LOCAL E2D IS sin(vectorangle(relative(engineTwo:facing:vector),rounded(relative(engineTwo:facing:vector)))).

	//Compute thrust at 100%, derated for angle
	LOCAL E1F IS engineOne:MAXTHRUST * E1D.
	LOCAL E2F IS engineTwo:MAXTHRUST * E2D.

	//print "E1 Force".
	//print E1F.
	//print "E2 Force".
	//print E2F.

	//Compute engine torques
	LOCAL T1M IS E1R * E1F.
	LOCAL T2M IS E2R * E2F.

	//print "E1 Torque".
	//print T1M.
	//print "E2 Torque".
	//print T2M.

	//T = rF ==> r1 * F1 = r2 * F2
	//locate which F to reduce below 100%

	IF ABS(T1M) > ABS(T2M)
	{
		LOCAL NewThrust IS ABS((E2R / E1R) * E2F).
		//print "New Thrust E1".
		//print NewThrust.

		LOCAL NewPercent IS 100 * (NewThrust/E1F).
		//print "E1 Thrust %".
		//print NewPercent.
		SET engineOne:THRUSTLIMIT TO NewPercent.
		SET engineTwo:THRUSTLIMIT TO 100.
	}
	ELSE
	{
		LOCAL NewThrust IS ABS((E1R / E2R) * E1F).
		//print "New Thrust E2".
		//print NewThrust.

		LOCAL NewPercent IS 100 * (NewThrust/E2F).
		//print "E2 Thrust %".
		//print NewPercent.
		SET engineOne:THRUSTLIMIT TO 100.
		SET engineTwo:THRUSTLIMIT TO NewPercent.
	}

}

LOCAL FUNCTION loadStatus
{
	PARAMETER self.
	IF EXISTS("/config/RCSBalancer.cfg")
		SET self["runStatus"] TO READJSON("/config/RCSBalancer.cfg").
}

LOCAL FUNCTION saveStatus
{
	PARAMETER self.

	IF NOT EXISTS("/config")
		CREATEDIR("/config").

	WRITEJSON(self["runStatus"],"/config/RCSBalancer.cfg").	
}

print "RCS Balancer version 0.3.1 loaded".