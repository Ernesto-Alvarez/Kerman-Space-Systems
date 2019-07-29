import threading
import time
import krpc
import math
from scipy import interpolate


class vessel_monitor:
	def __init__(self,conn,vessel):
		self.conn = conn
		self.vessel = vessel

		self.thr_status = "Running"
		self.state = "Pre-launch"

		self.met = self.conn.add_stream(getattr, vessel, 'met')
		self.us_resources = self.conn.add_stream(vessel.resources_in_decouple_stage,-1)

		resources = vessel.resources_in_decouple_stage(-1)
		
		self.lf = self.conn.add_stream(resources.amount, 'LiquidFuel')
		self.ox = self.conn.add_stream(resources.amount, 'Oxidizer')
		self.ec = self.conn.add_stream(resources.amount, 'ElectricCharge')

		self.ap_time = self.conn.add_stream(getattr, vessel.orbit, 'time_to_apoapsis')
		self.pe_time = self.conn.add_stream(getattr, vessel.orbit, 'time_to_periapsis')
		self.ap = self.conn.add_stream(getattr, vessel.orbit, 'apoapsis_altitude')
		self.pe = self.conn.add_stream(getattr, vessel.orbit, 'periapsis_altitude')

		fairing = vessel.parts.root
		self.fairing_temp = self.conn.add_stream(getattr,fairing, 'skin_temperature')
		self.max_fairing_temp = self.conn.add_stream(getattr,fairing, 'max_skin_temperature')

		self.flight_info = vessel.flight()

		self.mon_thread = threading.Thread(target=self.monitor)
		self.mon_thread.daemon = True
		self.mon_thread.start()

		#print "Thread spawn complete"

	def propellant_mass(self):
		fuel_kg = self.lf() * vessel.resources.density('LiquidFuel')
		oxi_kg = self.ox() * vessel.resources.density('Oxidizer')
		return fuel_kg + oxi_kg

	def deltav(self):
		#deltav = ve * ln (m0 / mf)
		#deltav = Isp * g0 * ln ( m0 / mf )

		m0 = self.vessel.mass
		mf = m0 - self.propellant_mass()
		g0 = 9.80665
		Isp = 345 #LV 909 terrier in vacuum

		return (Isp * g0 * math.log (m0 / mf))

	def monitor(self):

		while self.flight_info.mean_altitude < 100:	#Wait until launch
			if self.thr_status == "Stop":
				return
			time.sleep(1)

		self.state = "OK"

		while self.state == "OK":			
			if self.thr_status == "Stop":
				return

			if self.lf() < 0.1:
				self.state = "LF Starved"

			if self.ox() < 0.1:
				self.state = "OX Starved"

			if self.ec() < 0.1:
				self.state = "EC Starved"

			if self.ap_time() > self.pe_time():
				self.state = "Passed apoapsis"

			if ( self.fairing_temp() / self.max_fairing_temp() ) > 0.75:
				self.state = "Thermal issues"

			if self.ap_time() > 60 and self.pe() > 78400:
				self.state = "Successful orbit"

			time.sleep(1)


	def report(self):
		#Result, dV, EC, Apoapsis Error, Periapsis Error,state
		return "{:.2f};{:.2f};{:.2f};{:.2f};{:.2f};{}".format(self.deltav(),self.met(),1010 - self.ec(),self.ap() - 80000 ,self.pe() - 80000,self.state)

	def end(self):
		self.thr_status = "Stop"

	def __del__(self):
		self.end()


class fairing_autostager:
	def __init__(self,conn,vessel):
		self.vessel = vessel
		self.conn = conn

		self.thr_status = "Run"
		self.staged = False

		self.flight_info = vessel.flight()

		self.stager_thread = threading.Thread(target=self.autostage)
		self.stager_thread.daemon = True
		self.stager_thread.start()

	def autostage(self):
		while self.flight_info.mean_altitude < 70000:
			if self.thr_status == "Stop":
				return
			time.sleep(1)
	
		for i in vessel.parts.fairings:
			i.jettison()
		self.staged = True

	def end(self):
		self.thr_status = "Stop"

	def __del__(self):
		self.end()







class stage_autostager():
	def __init__(self,conn,vessel,last_stage):
		self.vessel = vessel
		self.conn = conn

		self.thr_status = "Run"
		self.last_stage = last_stage
		self.staged = False

		self.stager_thread = threading.Thread(target=self.autostage)
		self.stager_thread.daemon = True
		self.stager_thread.start()

	def autostage(self):
		current_stage = self.determine_current_stage()

		resources = {}
		for i in range(-1,current_stage+1):
			resources[i] = self.vessel.resources_in_decouple_stage(i,cumulative=True)
		res = resources[current_stage]

		while current_stage >= self.last_stage and self.thr_status == "Run":
			if (res.amount("LiquidFuel") < 0.1 or res.amount("Oxidizer") < 0.1) and res.amount("SolidFuel") < 0.1:
				current_stage = self.determine_current_stage()
				res = resources[current_stage]
				if res.amount("LiquidFuel") < 0.1 or res.amount("Oxidizer") < 0.1:
					if current_stage >= self.last_stage:
						self.vessel.control.activate_next_stage()
			time.sleep(1)
		self.staged = True
		#print "Staging complete"


	def end(self):
		self.thr_status = "Stop"

	def determine_current_stage(self):
		parts = vessel.parts
		stage = self.last_stage
		while len(parts.in_decouple_stage(stage)) > 0:
			stage = stage + 1
		return stage - 1

	def __del__(self):
		self.end()









class gt_autopilot:

	performance_data_r3_400 = [ (0,1),(100,2.5),(200,3.7),(300,5.8),(400,8),(500,11),(600,12.5),(700,14.5),(800,16.5),(900,19),(1000,21),(1100,22.5),(1200,24.5),(1300,27.5),(1400,29),(1500,30),(1600,31),(1700,32),(1800,33),(1900,34),(2300,35) ]

	performance_data_r3_1200 = [(0,2),(100,4),(200,6),(300,8),(400,11),(500,13),(600,16),(700,19),(800,22),(900,25),(1000,27),(1100,30),(1200,33),(1300,36),(1400,38),(1500,40),(1600,41),(1700,42),(1800,43),(1900,44),(2000,45),(2100,46),(2200,47),(2300,48)]

	performance_data_r3_1200b = [(0,2),(100,6),(200,8),(300,12),(400,16),(500,20),(600,24),(700,28),(800,32),(900,36),(1000,40),(1100,44),(1200,48),(1300,52),(1400,56),(1500,60),(1600,64),(1700,68),(1800,72),(1900,76),(2000,80),(2100,84),(2200,88),(2300,92)]

	x = []
	y = []

#	for i in performance_data_r3_400:
#	for i in performance_data_r3_1200:
	for i in performance_data_r3_1200b:

		x.append(i[0])
		y.append(i[1])

	circulatisation_table = interpolate.interp1d(x,y,kind='cubic',fill_value = 0,bounds_error=False)


	def __init__(self,conn,vessel,turn_speed,turn_angle):
		self.vessel = vessel
		self.conn = conn
		self.turn_speed = turn_speed
		self.turn_angle = turn_angle
		self.control = vessel.control

		self.thr_status = "Run"
		self.state = "Pre-launch"

		self.stager_thread = threading.Thread(target=self.autopilot)
		self.stager_thread.daemon = True
		self.stager_thread.start()

	def autopilot(self):
		while self.state == "Pre-launch" and self.thr_status == "Run":
			time.sleep(1)
		
		if self.thr_status == "Run":
			self.payload_mass_determination()

		if self.thr_status == "Run":
			self.vertical_ascent(self.turn_speed)

		if self.thr_status == "Run":
			self.initiate_turn(self.turn_angle)

		if self.thr_status == "Run":
			self.gravity_turn()

		if self.thr_status == "Run":
			self.atmospheric_coast()

		if self.thr_status == "Run":
			self.circularise()
		
	def payload_mass_determination(self):
		if self.vessel.mass > 11643 and self.vessel.mass < 13643:		#R-3-1200
			self.payload_mass = self.vessel.mass - 11643
		else:
			self.payload_mass = 0

	def launch(self):
		self.state = "Launch"

	def vertical_ascent(self,to_speed):
		self.state = "Vertical ascent"
		self.vessel.control.throttle = 1		
		self.control.sas = True
		self.control.sas_mode = self.conn.space_center.SASMode.stability_assist
		flight_info = self.vessel.flight(vessel.orbit.body.reference_frame)
		speed = self.conn.add_stream(getattr, flight_info, 'speed')

		self.vessel.control.activate_next_stage()

		while speed() < to_speed and self.thr_status == "Run":
			time.sleep(0.1)

	def initiate_turn(self,to_angle):
		self.state = "Initiate turn"
		ref_frame = self.conn.space_center.ReferenceFrame.create_hybrid(position=vessel.orbit.body.reference_frame,rotation=vessel.surface_reference_frame)
		zenith = (1,0,0)

		#Execute hard right until the velocity vector pitches to indicated angle

		angle = 0

		self.control.input_mode = self.conn.space_center.ControlInputMode.override
		self.control.yaw = 1

		while angle < to_angle and self.thr_status == "Run":
			v = self.vessel.velocity(ref_frame)
			dotprod = v[0] * zenith[0] + v[1] * zenith[1] + v[2] * zenith[2]
			vmag = math.sqrt(v[0]**2 + v[1]**2 + v[2]**2)
			if dotprod > 0:
				angle = abs(math.acos(dotprod / vmag) * (180.0 / math.pi))
			else:
				angle = 0
			time.sleep(0.1)

		#Once angle is reached, release stick and set SAS to prograde

		self.control.input_mode = self.conn.space_center.ControlInputMode.additive
		self.control.yaw = 0
		self.control.sas = True
		self.control.sas_mode = self.conn.space_center.SASMode.prograde		

	def gravity_turn(self):
		self.state = "Gravity turn"
		self.control.throttle = 1
		while self.vessel.orbit.apoapsis_altitude < 79000 and self.thr_status == "Run":
			time.sleep(0.2)

		self.control.throttle = 0.1
		while self.vessel.orbit.apoapsis_altitude < 80000 and self.thr_status == "Run":
			time.sleep(0.05)

		self.control.throttle = 0
		time.sleep(1)
 
	def atmospheric_coast(self):
		self.state = "Coasting to apoapsis"
		orbit = self.vessel.orbit
		
		flight_info = self.vessel.flight()
		altitude = self.conn.add_stream(getattr, flight_info, 'mean_altitude')

		while altitude() < 70000 and self.thr_status == "Run":

			if self.vessel.orbit.apoapsis_altitude > 80000:
				self.control.throttle = 0
			else:
				self.control.throttle = 0.1
			time.sleep(0.1)	

		self.control.throttle = 0

	def circularise(self):
		self.state = "Circularising"
		orbit = self.vessel.orbit
		obt_frame = vessel.orbit.body.non_rotating_reference_frame
		target_speed = 2296

		while self.vessel.orbit.periapsis_altitude < 80000 and self.thr_status == "Run": 
			ap_time = orbit.time_to_apoapsis
			per_time = orbit.time_to_periapsis
			obt_speed = self.vessel.flight(obt_frame).speed
			v_deficit = target_speed - obt_speed

			set_ap_time = self.circulatisation_table(v_deficit)

			throttle = self.control.throttle
			
			if  ap_time > set_ap_time:			
				throttle -= 0.03125
			else:
				throttle += 0.03125

			#Contingency modes
			#We've pushed the apoapsis far away during the fine tuning of the orbit
			#We're with less than 2% error, so we're not bothering to wait that much to finalize
			if self.vessel.orbit.periapsis_altitude > 78400 and orbit.time_to_apoapsis > 60:
				self.control.throttle = 0
				self.state = "ended"
				return

			#We've passed apoapsis. This, for the purposes of the test autopilot, is a failure.
			#End autopilot and let the flight recorder take its data.
			if orbit.time_to_apoapsis > orbit.time_to_periapsis:
				self.control.throttle = 0
				self.state = "ended"
				return

			self.control.throttle = throttle			
			time.sleep(0.05)

		self.control.throttle = 0
		self.state = "ended"

	def end(self):
		self.thr_status = "Stop"

	def __del__(self):
		self.end()


connection = krpc.connect()
for j in ["R-3-1200B-2500"]:
		print j
		print "pitch;deltav;time to orbit;ec use;ap error;pe error;status"
		for i in range(46,56):
			connection.space_center.load(j)
			vessel = connection.space_center.active_vessel
			monitor = vessel_monitor(connection,vessel)
			f_stager = fairing_autostager(connection,vessel)
			r_stager = stage_autostager(connection,vessel,2)
			ap = gt_autopilot(connection,vessel,50,i)
			time.sleep(1)
			ap.launch()
			while (monitor.state == "OK" or monitor.state == "Pre-launch"):
				time.sleep(1)
			monitor.end()
			f_stager.end()
			r_stager.end()
			ap.end()
			print "{};{}".format(i,monitor.report())

		print "end"