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

		self.direction = self.conn.add_stream(vessel.direction,vessel.orbit.body.reference_frame)
		self.velocity = self.conn.add_stream(vessel.velocity,vessel.orbit.body.reference_frame)


		fairing = vessel.parts.root
		self.fairing_temp = self.conn.add_stream(getattr,fairing, 'skin_temperature')
		self.max_fairing_temp = self.conn.add_stream(getattr,fairing, 'max_skin_temperature')

		self.flight_info = vessel.flight()

		self.mon_thread = threading.Thread(target=self.monitor)
		self.mon_thread.daemon = True
		self.mon_thread.start()

		#print "Thread spawn complete"

	def angle_of_attack(self):

		d = self.direction()
		v = self.velocity()

		# Compute the dot product of d and v
		dotprod = d[0]*v[0] + d[1]*v[1] + d[2]*v[2]

		# Compute the magnitude of vS
		vmag = math.sqrt(v[0]**2 + v[1]**2 + v[2]**2)

		magprod = vmag
		# Compute the angle between the vectors

		try:
			angle = abs(math.acos(dotprod / vmag) * (180.0 / math.pi))
		except ValueError:
			angle = 0

		#print angle

		return angle

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
		mj = self.conn.mech_jeb
		ascent = mj.ascent_autopilot

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

			if self.ap_time() > self.pe_time() and ascent.status != "Circularizing":
				self.state = "Passed apoapsis"

			if ( self.fairing_temp() / self.max_fairing_temp() ) > 0.75:
				self.state = "Thermal issues"

			if self.ap_time() > 60 and self.pe() > 70000 and ascent.status != "Circularizing":
				self.state = "Successful orbit"

			if self.angle_of_attack() > 20 and self.flight_info.mean_altitude < 70000:
				self.state = "Unstable flight"

			time.sleep(1)


			

	def report(self):
		#Result, dV, EC, Apoapsis Error, Periapsis Error,state
		return "{:.2f};{:.2f};{:.2f};{:.2f};{:.2f};{}".format(self.deltav(),self.met(),self.ec(),self.ap() - 80000 ,self.pe() - 80000,self.state)

	def end(self):
		self.thr_status = "Stop"

	def __del__(self):
		self.end()


class mj_autopilot:

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
		self.configure_mj()
		while self.state == "Pre-launch":
			time.sleep(1)
		self.state = "Launched"
		self.vessel.control.activate_next_stage()
		mj = self.conn.mech_jeb
		ascent = mj.ascent_autopilot
		while ascent.enabled:
			time.sleep(1)


	def configure_mj(self):
		mj = self.conn.mech_jeb
		ascent = mj.ascent_autopilot
		st_controller = ascent.staging_controller
		t_controller = ascent.thrust_controller
		gt = ascent.ascent_path_gt
		ne = mj.node_executor

		st_controller.enabled = True

		#All of these options will be filled directly into Ascent Guidance window and can be modified manually during flight.
		#Target
		ascent.desired_orbit_altitude = 80000
		ascent.desired_inclination = 0
		ascent.ascent_path_index = 1

		#Guidance
		
		gt.hold_ap_time = 1
		gt.intermediate_altitude = 80000
		gt.turn_start_altitude = 500
		gt.turn_start_pitch = self.turn_angle
		gt.turn_start_velocity = self.turn_speed

		#Options

		t_controller.limit_to_prevent_overheats = False

		t_controller.limit_to_prevent_overheats = False
		t_controller.max_dynamic_pressure = 20000

		t_controller.limit_acceleration = False
		t_controller.max_acceleration = 40

		t_controller.limit_throttle = False
		t_controller.max_throttle = 1
		t_controller.min_throttle = 0

		t_controller.electric_throttle = False
		t_controller.electric_throttle_hi = 0.15
		t_controller.electric_throttle_lo = 0.05

		ascent.force_roll = True
		ascent.turn_roll = 90
		ascent.vertical_roll = 90

		ascent.limit_ao_a = True
		ascent.max_ao_a = 5	

		ascent.ao_a_limit_fadeout_pressure = 2500

		ascent.autostage = True
		st_controller.post_delay = 1
		st_controller.pre_delay = 0.5

		st_controller.clamp_auto_stage_thrust_pct = 0.99

		st_controller.fairing_max_aerothermal_flux = 1135
		st_controller.fairing_max_dynamic_pressure = 50
		st_controller.fairing_min_altitude = 50000

		st_controller.autostage_limit = 1

		st_controller.hot_staging = False
		ascent.autodeploy_solar_panels = False
		ascent.auto_deploy_antennas = False
		ne.autowarp = False

		ascent.skip_circularization = False

		#Enable MJ
		ascent.enabled = True

	def end(self):
		self.thr_status = "Stop"

	def __del__(self):
		self.end()

	def launch(self):
		self.state = "Launch requested"


connection = krpc.connect()
for j in ["R3-400-S1-H01N1X-0","R3-400-S1-H01N1X-100","R3-400-S1-H01N1X-200","R3-400-S1-H01N1X-300","R3-400-S1-H01N1X-400","R3-400-S1-H01N1X-500","R3-400-S1-H01N1X-600","R3-400-S1-H01N1X-700","R3-400-S1-H01N1X-800"]:
		print j
		print "pitch;deltav;time to orbit;ec remain;ap error;pe error;status"
		for i in [5,10,15,20,25,30,35,40]:
			connection.space_center.load(j)
			vessel = connection.space_center.active_vessel
			monitor = vessel_monitor(connection,vessel)
			ap = mj_autopilot(connection,vessel,50,i)
			time.sleep(10)
			ap.launch()
			while (monitor.state == "OK" or monitor.state == "Pre-launch"):
				time.sleep(1)
			monitor.end()
			ap.end()
			print "{};{}".format(i,monitor.report())

		print "end"