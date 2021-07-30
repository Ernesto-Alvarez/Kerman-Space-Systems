SS-1 Unmanned orbital depot

Unmanned orbital depot for spaceship repair and resupply.

This is an all purpose service station for spacecraft in orbit. Spacecraft that are damaged or low on supplies can rendezvous with an orbital depot for emergency repairs or resupply.

Main functions
	Orbital service station
	Emergency supply depot

Depot contains the following supplies:

Electric Charge: 3215 units and high capacity solar power source
Food, Water, Oxygen: 300 days worth, in a TAC LS container
Spare Parts: 150 units, in the service bay
Liquid Fuel: 270 units in main tanks
Oxidizer: 330 units in main tanks
Monopropellant: 160 units in lower tank farm
..
EVA repair kit x 4, EVA propellant, Spare EVA jetpack included in service bay.

Docking is possible using clampotron junior, KAS JS-1 socket, KAS Winch and KAS pipe.

Controlled by a HECS computer and KR-2042 scripting unit.

Station has no living facilities and is designed as a supply depot only

Repositioning is done by towing using the underside clampotron junior interface. CoM is places to ensure proper towing if thrust is applied towards (or opposite) the underside clapotron.

Communications are provided by 4 Communotron 16-S radios mounted on the hull.

Handgrips run over the full station length. They are designed for station inspection and for assisting in spaceship repair.

Depot contains high visibility lighting consisting of 8 navigation lights mk1, 4 domelights mk1 in the upper hull (FL-T200 tank next to computer end) and a cherry light on top of the computer. Upper navigation lights illuminate the MP tanks, making the station visible at night, lower navigation lights illuminate docking bays and EVA handgrips, making ships visible. The dome light, when used with all other lights cause the cherry light to light up the upper LFOX tank (don't ask, we don't know either how this can work).

Variants

Stock station core: contains fuel tanks, reduced size electrical system, basic lighting, docking, storage and HECS computer. Mod requirements: stock.

TAC station core: stock systems plus TAC LS supplies and full size electrical system. Mod requirements: TAC LS.

Full unit. Contains TAC station core plus KR-2042 kOS scripting unit, cherry light and multiple KAS adaptors (host, winch, telescopic joint and JS-1 socket). Mod requirements: TAC LS, KAS, kOS.

All stations can work with Dangit mod, supplies can be stored in service bay. RemoteTech compatible: power generation is more than sufficient for RT operation. The station is designed to be used with a combination of the following mods.

* KIS
* KAS
* kOS
* Dangit
* TAC life support
* RemoteTech
* RCS Build aid is recommended for station redesign
* NavBall Docking indicator is recommended for docking

Launching can be done on an R-4A rocket (D1 fairing) for cores without KAS hoses and winch. Full model requires the R-4B rocket (D2 fairing).

Test flights

TF-1

Launch vehicle: R4-B
Environment: sandbox
Objective: general validation, launch test, lighting test, towing test, fuel operation test, software development

Launch test: Successful, the station is now well below the 9 tons specified for the launch vehicle. Launched with over 400 m/s dV. Carrier rocket  tested as space tug. 

Lighting test: Discovered interaction between navigation lights and cherry light. Slight inward inclination of navigation lights being considered. Orbital tests show that lower nav lights should be mounted on top of MP tanks with a slight downward inclination.

Towing test: Carrier rocket serverd as a tug. Successful boost without any unwanted rotation. Awaiting rendezvous with R-2 tanker for further tests. R-2 towing showed slight rotation due to kraken damage. Kraken damage not a problem if SAS is used.

Fueling test: Sucess, hose and clampotron.

Software: Increase computer memory size to max available.

Docking test: Clampotron docking successful. Excellent clearance from solar panels. Hose docking partially successful. Hose attaches properly, clearance is excellent due to hose length. Hose should not be left unattended and connected. Transfer station ripped apart due to target maneuvering. JS1 test interrupted due to kraken. Not setting linkage to "connected" is suspected. Pipe test aborted, supplies destroyed by kraken. Partial data, as JS1 test was done with pipe connection. Winch test (EVA) passed. Good for tethered EVAs.

Payload: Consider replacing SEQ-3 container with SEQ-6 if possible. Consider replacing jetpack with handheld lamp and using stackable EVA MP tanks (the stock ones suck).

EVA: Good EVA handling if ships dock with hatches towards hand holds. Crew can reasonably reach service bay without assistance of jetpack (but is a dangerous operation). This feature does not exist for underside port (which is used for towing). Consider installing hand hold ring near MP tanks.

Power systems: Excessive power generation, even for Remotetech standards. Consider removing lower set of panels to provide space for hand hold rings.

Changes to be done after test:
	* Remove lower set of solar panels
	* Install additional hand holds at bottom of station
	* Increase computer memory
	* Replace SEQ-3 container with SEQ-6
	* Remove batteries from service bays
	* Move lower nav ligths to MP tank farm
	* Remove TJ-1 pipe interface
	* Remove JS-1 socket
	* Install dual RTS-1 hoses
	* Replace winch with heavy model, mount on HECS computer case
	* Added portable lamps to service bay
	* Extra EVA propellant tanks in service bay
	* Tank priority lowered to -15
	* Moved remaining solar panels away from batteries

TF-2

Launch vehicle: R4-B
Environment: sandbox
Objective: general validation, launch test, lighting test, towing test, fuel operation test, software development

Launch test: Successful. 242 m/s left on carrier rocket after insertion to 250x250 km orbit.

Maneuver test: Successful. Maneuvered to sun seeking attitude without problems. Sun seeking attitude is top pointing to prograde with panels pointing to normal.

Power test: Charging system is good. 

Lighting test: Lower nav lights illuminate most of the station. Upper nav light illuminate batteries and MP tanks. Domelight illuminates upper tank. Cherry light effect overpowered by lights. Cherry light illuminates top of the station.

Fueling test: Successful winch and hose refueling. Heavy winch holds spaceship in position while hose refuels it. Releasing hose without grabbing it and locking it to the station is dangerous because hose flaps around.

EVA test: Circular handholds insufficient. Kerbal cannot go around the circumference of the station. Longitudinal handholds adequate. Kerbal can operate refuelling station while holding to station. Ground tests indicate that 12 handholds are sufficient. Extra handhold intersecting ring should allow entering and leaving the ring without using RCS.

Changes to be done after the test:
	* Add double 6x symmetry hand hold ring
	* Expand longitudinal hand holds to intersect ring
	* Replace SEQ-6 container with 2x SEQ-3 (SEQ-6 is KIS only)

TF-3 (ongoing)

Launch vehicle: R4-B
Environment: sandbox
Objective: software development, full rehearsal

Launch: inserted into 85x85 km equatorial orbit, 366 m/s dV remaining. Bad fuel priorities, had to transfer fuel back to station.
Activation:
	Attitude: OK
	Solar panels: OK
	Lights: OK, station is highly visible at night.
	Visibility: OK, station visible as illuminated point at > 800M, recognizable at > 220M, cherry light shows docking ports
Space Ops:
	Docking: OK
	EVA: OK, simulated no RCS EVA could be used to reach service bay. Problems returning to capsule without jetpack.
	Winch: OK, at least 1 hour.
	Hose: OK. Tanks containing resources need to be enabled to use RTS.