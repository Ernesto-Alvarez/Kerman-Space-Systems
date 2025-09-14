@LazyGlobal off.

//RUNONCEPATH("blocks").
RUNONCEPATH("testfunctions").
RUNONCEPATH("scheduler").

LOCAL sch IS scheduler().

print "AOC-3 test program loaded".

LOCAL count IS 0.
LOCAL myShip IS list().

LOCAL h1process IS 0.
LOCAL h2process IS 0.
LOCAL h3process IS 0.
LOCAL h4process IS 0.

UNTIL count = 110
{
	SET count TO count + 1.

//	IF count = 5 highlightBlock(CORE:PART).
//	IF count = 7 highlightBlock(CORE:PART,false).
	IF count = 10 SET h1process TO execProcess(sch,hello1@,5).
	IF count = 20 SET h2process TO execProcess(sch,hello2@,5).
	IF count = 30 pauseProcess(sch,h2process).
	IF count = 40 continueProcess(sch,h2process).
	IF count = 50 SET h3process TO execProcess(sch,hello3@,5,"Hello 3 function").
	IF count = 60 SET h4process TO execProcess(sch,hello4@,5,TRUE,"Hello 4 function").
	IF count = 70 continueProcess(sch,h4process).
	IF count = 80 terminateProcess(sch,h1process).
	IF count = 90 pauseProcess(sch,h2process).
	IF count = 90 pauseProcess(sch,h3process).
	IF count = 90 pauseProcess(sch,h4process).
	IF count = 95 continueProcess(sch,h4process).
	IF count = 100 terminateProcess(sch,h2process).
	IF count = 100 terminateProcess(sch,h3process).
	IF count = 100 terminateProcess(sch,h4process).
	IF count = 105 SET h1process TO execProcess(sch,hello1@,1).

	print(count).
	print(sch["dispatcherID"]).
	FOR proc IN sch["runtable"]:VALUES
	{
		print(proc["status"]).
	}



	WAIT 10.
}
