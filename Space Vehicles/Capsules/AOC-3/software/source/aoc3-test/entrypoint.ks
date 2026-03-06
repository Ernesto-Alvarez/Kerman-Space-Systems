@LazyGlobal off.

SET TERMINAL:WIDTH TO 60.
SET TERMINAL:HEIGHT TO 40.
SET TERMINAL:BRIGHTNESS TO 0.7.

RUNONCEPATH("scheduler").
RUNONCEPATH("eris").
RUNONCEPATH("RCSbalancer").
RUNONCEPATH("processExplorer").



//AOC-3 linear ports
//CORE:VESSEL:PARTS[32] = Right aft
//CORE:VESSEL:PARTS[33] = Left aft
//CORE:VESSEL:PARTS[34] = Top aft
//CORE:VESSEL:PARTS[35] = Bottom aft
//CORE:VESSEL:PARTS[36] = Top fore
//CORE:VESSEL:PARTS[37] = Bottom aft
//CORE:VESSEL:PARTS[38] = Left fore
//CORE:VESSEL:PARTS[39] = Right fore



LOCAL sch IS scheduler().
LOCAL eris IS ERIS(sch).


LOCAL engines IS 0.
LIST RCS IN engines.

LOCAL right is list().
LOCAL left is list().
LOCAL top is list().
LOCAL bottom is list().

FOR engine IN engines
{
	IF engine:NAME = "linearRCS"
	{
		IF round(relative(engine:facing:vector):y) = 1
			right:ADD(engine).
		IF round(relative(engine:facing:vector):y) = -1
			left:ADD(engine).
		IF round(relative(engine:facing:vector):z) = 1
			top:ADD(engine).
		IF round(relative(engine:facing:vector):z) = -1
			bottom:ADD(engine).
	}
}

right:ADD("RCS Balancer Right").
left:ADD("RCS Balancer Left").
top:ADD("RCS Balancer Top").
bottom:ADD("RCS Balancer Bottom").

LOCAL balancer IS RCSBalancer(sch,list(top,bottom,right,left)).

print "AOC-3 test program loaded".

UNTIL FALSE
{
	CLEARSCREEN.
	print "AOC-3 Menu".
	print "1. Review process list".
	print "2. Start ERIS".
	print "3. Stop ERIS".
	print "4. Clear ERIS data and reboot".
	print "5. Start RCS Balancer".
	print "6. Stop RCS Balancer".
	print "7. Reboot system".

	LOCAL input IS TERMINAL:Input:GETCHAR.
	TERMINAL:Input:CLEAR.
	IF input = 1
		processList(sch).

	IF input = 2
	{
		startERIS(eris).
		print "ERIS started".
	}
	IF input = 3
	{
		stopERIS(eris).
		print "ERIS stopped".
	}
	IF input = 4
		resetERISConfig().
	IF input = 5
	{
		startBalancer(balancer).
		print "RCS Balancer started".
	}
	IF input = 6
	{
		stopBalancer(balancer).
		print "RCS Balancer stopped".
	}
	IF input = 7
		reboot.
	WAIT 1.
}


