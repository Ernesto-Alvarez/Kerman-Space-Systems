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
	PARAMETER engineAxes.
	PARAMETER axisDescriptions.

	LOCAL newBalancer IS lexicon().

	SET newBalancer["scheduler"] TO scheduler.
	SET newBalancer["runStatus"] TO FALSE.
	SET newBalancer["runFunctions"] TO list().

	FROM { LOCAL i IS 0. } UNTIL i = engineAxes:LENGTH STEP { SET i TO i + 1. } DO
	{
		LOCAL engines IS engineAxes[i].
		LOCAL axis IS axisDescriptions[i].
		LOCAL balanceFunction IS { balanceMany(engines). }.
		LOCAL pid IS execProcess(scheduler,balanceFunction,0.1,TRUE,"RCS Balancer " + axis).
		newBalancer["runFunctions"]:ADD(pid).
	}

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

LOCAL FUNCTION balanceMany
{
	PARAMETER engines.

	LOCAL positions IS list().
	LOCAL forces IS list().
	LOCAL coefficients IS list().
	FOR rcs IN engines
		{
		positions:ADD(relative(rcs:POSITION):X).
		forces:ADD(cos(vectorangle(relative(rcs:FACING:VECTOR),rounded(relative(rcs:FACING:VECTOR)))) * rcs:MAXTHRUST).
		coefficients:ADD(1).
		}

	LOCAL indices IS sortToIndex(positions).

	LOCAL torque IS computeTorque(forces,positions,coefficients).

	IF torque < 0
	{
		//Shut off outermost engines if not needed
		LOCAL i IS 0.

		FROM {  } UNTIL torque - forces[indices[i]] * positions[indices[i]] > 0 STEP { SET i TO i+1. } DO
		{
			SET coefficients[indices[i]] TO 0.
			SET torque TO torque - forces[indices[i]] * positions[indices[i]].
		}
		//Remaining torque can be compensated by throttling down outermost engine
		LOCAL engineTorque IS positions[indices[i]] * forces[indices[i]].
		SET coefficients[indices[i]] TO ( ABS(engineTorque) - ABS(torque) ) / ABS(engineTorque). 

	}
	ELSE IF torque > 0
	{
		//Shut off outermost engines if not needed
		LOCAL i IS forces:LENGTH.
		FROM { } UNTIL torque - forces[indices[i]] * positions[indices[i]] < 0 STEP { SET i TO i-1. } DO
		{
			SET coefficients[indices[i]] TO 0.
			SET torque TO torque - forces[indices[i]] * positions[indices[i]].
		}
		//Remaining torque can be compensated by throttling down outermost engine
		LOCAL engineTorque IS positions[indices[i]] * forces[indices[i]].
		SET coefficients[indices[i]] TO ( ABS(engineTorque) - ABS(torque) ) / ABS(engineTorque). 
	}

	FROM { LOCAL i IS 0. } UNTIL i = engines:LENGTH STEP { SET i to i+1. } DO
		SET engines[i]:THRUSTLIMIT TO 100 * coefficients[i].


}

LOCAL FUNCTION computeTorque
{
	PARAMETER forces.
	PARAMETER positions.
	PARAMETER coefficients.
	LOCAL retval IS 0.

	FROM {LOCAL i IS 0.} UNTIL i = forces:LENGTH STEP { SET i TO i+1. } DO
		SET retval TO retval + forces[i] * positions[i] * coefficients[i].
	return retval.
}

LOCAL FUNCTION sortToIndex
{
	PARAMETER input.
	LOCAL indices IS list(0).

	FROM {LOCAL i IS 1. LOCAL j IS 0.} UNTIL i = input:LENGTH STEP {SET i TO i+1.} DO
	{
		FROM {SET j TO 0.} UNTIL (j = i OR input[i] < input[j]) STEP {SET j TO j+1.} DO {}.
			indices:INSERT(j,i).
	}
	return(indices).
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

print "RCS Balancer version 0.4.0 loaded".