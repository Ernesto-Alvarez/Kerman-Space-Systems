//================ Thrust Balancer Script =================
//
//  This script changes the thrust limiters on engines to maintain the center of thrust exactly aligned with the the center of mass.
//	This only changes based on longitudinal distance, so engines can't be offset laterally.
//
//	It should work with both rocket engines and jet engines.
//
//
//		by u/DaBeesSteeze
//=========================================================

CLEARSCREEN.

// Intializations
set FlightState to 4.

if status = "PRELAUNCH" {
	print "Ship in pre-launch status." at (0,1).
	wait until MAXTHRUST > 0.
}

// Loop until flight is "over"
until FlightState = 0 {
		wait 0.05.
	
	// Define axes unit vectors (left handed system, like KSP-RAW)
	set Body_X to ship:facing:forevector:normalized. // X axis points forward
	set Body_Y to ship:facing:starvector:normalized. // Y axis points right
	set Body_Z to ship:facing:topvector:normalized.  // Z axis points up
	
	
	
	// ------------- Calculate Total Thrusts ------------- //
	
		// Initialize lists
		LIST ENGINES in AllEngines.
		set ForeEngines to list().
		set AftEngines to list().
		
		// Initialize variables
		set NumEngines to 0.
		set AvgThrustVec to v(0,0,0).
		set TotalThrust to 0.
		set TotalMaxThrust to 0.
		set TotalAvailableThrust to 0.
		
		// Calculate total thrusts
		for eng in AllEngines {
			
			// Reset thrust limiters on first run through
			if flightstate = 4 {set eng:THRUSTLIMIT to 100.}
			
			// Find engine position and add to separate list
			set PosVector to v(eng:position*Body_X,eng:position*Body_Y,eng:position*Body_Z). // Position in body axes
			if PosVector:x > 0 {ForeEngines:ADD(eng).}
			else if PosVector:x < 0 {AftEngines:ADD(eng).}
						
			// Find engine thrust vector
			set ThrustVector to eng:facing:vector. //This is a force vector.
			
			// Scale thrust vector be engine thrust
			set ThrustVector to ThrustVector:NORMALIZED * eng:THRUST.
			
			// Add to running total of thrusts
			set AvgThrustVec to AvgThrustVec + ThrustVector.
					
			// Bookkeeping tools
			set NumEngines to NumEngines+1.
			set TotalThrust to TotalThrust+eng:THRUST.
			set TotalAvailableThrust to TotalAvailableThrust+eng:AVAILABLETHRUST.
			set TotalMaxThrust to TotalMaxThrust+eng:MAXTHRUST.
		
		}
		
		// Find total average thrust vector
		if NumEngines <> 0 {set AvgThrustVec to AvgThrustVec/NumEngines.}
		else {set AvgThrustVec to v(0,0,0).}

	// ---------------------------------------------------- //
	
	
	
	// ----------- Calculate Centers of Thrust ------------ //
	
		// Initialize variables
		set ForeAvgThrustVec to v(0,0,0).
		set AftAvgThrustVec to v(0,0,0).
		set x_num_fore to 0.
		set y_num_fore to 0.
		set z_num_fore to 0.
		set x_num_aft to 0.
		set y_num_aft to 0.
		set z_num_aft to 0.
		set TotalForeThrust to 0.
		set TotalAftThrust to 0.
	
		// Add contributions of forward engines
		for eng in ForeEngines {
			
			// Find engine position and maximum thrust vectors
			set PosVec to v(eng:position*Body_X,eng:position*Body_Y,eng:position*Body_Z).
			set ThrustVec to v(eng:facing:vector*Body_X,eng:facing:vector*Body_Y,eng:facing:vector*Body_Z):normalized * eng:MAXTHRUST.
			
			// Add to running total of thrusts
			set ForeAvgThrustVec to ForeAvgThrustVec+ThrustVec.
			set TotalForeThrust to TotalForeThrust+eng:MAXTHRUST.
			
			// Add engine contribution to thrust*position
			set x_num_fore to x_num_fore + (eng:MAXTHRUST * PosVec:x).
			set y_num_fore to y_num_fore + (eng:MAXTHRUST * PosVec:y).
			set z_num_fore to z_num_fore + (eng:MAXTHRUST * PosVec:z).
			
		}
		
		// Divide fore engine contributions by totals to find fore CoT
		if ForeEngines:length <> 0 {set ForeAvgThrustVec to ForeAvgThrustVec/ForeEngines:length.}
			else {set ForeAvgThrustVec to v(0,0,0).}
		if TotalForeThrust <> 0 {set ForeAvgThrustPos to v(x_num_fore,y_num_fore,z_num_fore)/TotalForeThrust.}
			else {set ForeAvgThrustPos to v(0,0,0).}
			
		// Find pitching moment contribution from fore engines
		set Moment_Fore to VCRS(ForeAvgThrustVec,ForeAvgThrustPos).
		set phi_fore to vectorangle(ForeAvgThrustVec,ForeAvgThrustPos).
		
		// Add contributions of aft engines
		for eng in AftEngines {
			
			// Find engine position and maximum thrust vectors
			set PosVec to v(eng:position*Body_X,eng:position*Body_Y,eng:position*Body_Z).
			set ThrustVec to v(eng:facing:vector*Body_X,eng:facing:vector*Body_Y,eng:facing:vector*Body_Z):normalized * eng:MAXTHRUST.
			
			// Add to running total of thrusts
			set AftAvgThrustVec to AftAvgThrustVec+ThrustVec.
			set TotalAftThrust to TotalAftThrust+eng:MAXTHRUST.
			
			// Add engine contribution to thrust*position
			set x_num_aft to x_num_aft + (eng:MAXTHRUST * PosVec:x).
			set y_num_aft to y_num_aft + (eng:MAXTHRUST * PosVec:y).
			set z_num_aft to z_num_aft + (eng:MAXTHRUST * PosVec:z).
			
		}
		
		// Divide aft engine contributions by totals to find aft CoT
		if AftEngines:length <> 0 {set AftAvgThrustVec to AftAvgThrustVec/AftEngines:length.}
			else {set AftAvgThrustVec to v(0,0,0).}
		if TotalAftThrust <> 0 {set AftAvgThrustPos to v(x_num_aft,y_num_aft,z_num_aft)/TotalAftThrust.}
			else {set AftAvgThrustPos to v(0,0,0).}
			
		// Find pitching moment contribution from aft engines
		set Moment_Aft to VCRS(AftAvgThrustVec,AftAvgThrustPos).
		set phi_aft to vectorangle(AftAvgThrustVec,AftAvgThrustPos).
	
	// ---------------------------------------------------- //
	
	
	
	// --- Balance Thrust Limiters by Balancing Moments --- //
	
		// Find the limiting pitching moment
		if ABS(Moment_Fore:y) > ABS(Moment_Aft:y) {
			set LimitingMoment to "Aft".
			set Moment_Limit to ABS(Moment_Aft:y).
		}
		else if ABS(Moment_Aft:y) > ABS(Moment_Fore:y) {
			set LimitingMoment to "Fore".
			set Moment_Limit to ABS(Moment_Fore:y).
		}
		else {
			set LimitingMoment to "Centered".
			set Moment_Limit to ABS(Moment_Fore:y). // This could be set to either fore or aft
		}
		
		// Limit thrusts of engines on side with too much moment to balance pitch
		if LimitingMoment = "Fore" and flightstate <> 2{
			
			// Find thrust needed to provide the moment limit
			set Thrust_Limit to Moment_Limit/(sin(phi_aft)*AftAvgThrustPos:MAG). // This is a magnitude
			set Thrust_Ratio to Thrust_Limit/ABS(TotalAftThrust).
			
			// Limit the thrust on all aft engines
			for eng in AftEngines {
				set eng:THRUSTLIMIT to Thrust_Ratio * 100.
			}
			
		}
		else if LimitingMoment = "Aft" and flightstate <> 2 {
			
			// Find thrust needed to provide the moment limit
			set Thrust_Limit to Moment_Limit/(sin(phi_fore)*ForeAvgThrustPos:MAG). // This is a magnitude
			set Thrust_Ratio to Thrust_Limit/ABS(TotalForeThrust).
			
			// Limit the thrust on all fore engines
			for eng in ForeEngines {
				set eng:THRUSTLIMIT to Thrust_Ratio * 100.
			}
			
		}
		else if flightstate = 2 {
			
			// Aircraft in forward flight mode, set thrust limits to 100
			for eng in AllEngines {
				set eng:THRUSTLIMIT to 100.
			}
		
		}
		
	
	//----------------------------------------------------- //
	
	
	
	// ------------------- Bookkeeping -------------------- //
	
		// Read off status in kOS window
				
		print " --- Thrust Balancer Active --- " at (0,1).
		print "Current Total Thrust:   " + round(TotalThrust,2) + " kN     " at (0,2).
		print "Current Total Weight:   " + round((MASS*body:mu/(altitude+body:radius)^2),2) + " kN     " at (0,3).
		print "Thrust to Weight Ratio: " + round(TotalThrust/(MASS*body:mu/(altitude+body:radius)^2),2) at (0,4).
		print "Thrust Limits: " at (0,7).
		
		set engnum to 0.
		for eng in AllEngines {
			set engine_call to eng:title.
			if eng:tag:length > 0 {set engine_call to eng:tag.}
			if eng:THRUSTLIMIT <> 100 {set string to engine_call + " limited to " + round(eng:THRUSTLIMIT,1) + "%".}
			if eng:THRUSTLIMIT = 100 {set string to engine_call + " not limited.".}
			set strlength to string:length.
			if strlength > terminal:width {set terminal:width to strlength+5.}
			from {local i is strlength.} until i = terminal:width STEP {set i to i+1.} DO {
				set string to string + " ".
			}
			
			print string at (2,8+engnum).
			set engnum to engnum+1.
			
		}
		
		if flightstate = 2 {print " + Forward Flying Mode +" at (0,5).}
		else {print "                        " at (0,5).}
		
		// Check to see if flight is still running
		set EnginesOff to 0.
		for eng in AllEngines {
			// If the engine is off and not flamed out, the flight is over
			if eng:ignition = "False" and eng:flameout = "False" {set EnginesOff to EnginesOff + 1.}
		}
		if EnginesOff = NumEngines and status <> "PRELAUNCH" {set FlightState to 0.}
		
		set enginesvtol to 0.
		for eng in AllEngines {
			set ThrustUnitVec to v(eng:facing:vector*Body_X,eng:facing:vector*Body_Y,eng:facing:vector*Body_Z):normalized.
			if ABS(ThrustUnitVec:z) > sin(40) {
				set enginesvtol to enginesvtol + 1.
			}
		}
		if enginesvtol < 2 {set flightstate to 2.}
		else {set flightstate to 1.}
	
	// ----------------------------------------------------- //
	
}

// Finalize code
if flightstate = 0 {
	clearscreen.
	print "- - - - - - - - - - - - - - - - - - - - - - - - - " at (0,1).
	print "                Engines shut off.                 " at (0,2).
	print "Please restart program once engines are reignited." at (0,3).
	print "- - - - - - - - - - - - - - - - - - - - - - - - - " at (0,4).
}