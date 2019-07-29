import threading
import time
import krpc
import math
import os
from collections import OrderedDict 


class mj_launch_autopilot:
#Launches the indicated vessel turning at turn_speed until turn_angle and heading towards an 80 km circular parking orbit of inclination degrees.

	def __init__(self,conn,vessel,turn_speed,turn_angle,inclination):
		self.vessel = vessel
		self.conn = conn
		self.turn_speed = turn_speed
		self.turn_angle = turn_angle
		self.inclination = inclination
		self.control = vessel.control

		self.state = "Pre-launch"

		self.lets_launch = threading.Event()
		self.orbital_insertion_complete = threading.Event()

		self.stager_thread = threading.Thread(target=self.autopilot)
		self.stager_thread.daemon = True
		self.stager_thread.start()

	def locate_fairing(self):
		fairing_list = self.vessel.parts.fairings

		#In theory, r3 rockets (and others I design) should have just one fairing.
		#If they don't, then it's a matter of random choice. I might as well choose the first

		self.fairing_stage = fairing_list[0].part.stage


	def autopilot(self):
		self.locate_fairing()
		self.configure_mj()
		if not( self.vessel.situation == connection.space_center.VesselSituation.pre_launch or self.vessel.situation == connection.space_center.VesselSituation.landed):
			return

		self.lets_launch.wait()
		if self.state == "Aborted":
			return

		self.state = "Launched"
		self.vessel.control.activate_next_stage()
		mj = self.conn.mech_jeb 
		ascent = mj.ascent_autopilot

		with self.conn.stream(getattr, ascent, "enabled") as enabled:
			enabled.rate = 1 #we don't need a high throughput rate, 1 second is more than enough
			with enabled.condition:
				while enabled() and not self.state == "Aborted":
					enabled.wait(timeout=1)

		if self.state != "Aborted":
			self.state = "Complete"
		self.orbital_insertion_complete.set()

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
		ascent.desired_inclination = self.inclination
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

		st_controller.autostage_limit = self.fairing_stage

		st_controller.hot_staging = False
		ascent.autodeploy_solar_panels = False
		ascent.auto_deploy_antennas = False
		ne.autowarp = True

		ascent.skip_circularization = False

		#Enable MJ
		ascent.enabled = True

	def end(self):
		self.state = "Aborted"
		self.lets_launch.set()		
		self.orbital_insertion_complete.set()

	def launch(self):
		self.lets_launch.set()

	def wait(self):
		self.orbital_insertion_complete.wait()

	def __del__(self):
		self.end()

class vessel_monitor:
	def __init__(self,conn,vessel):
		self.conn = conn
		self.vessel = vessel

		#Telemetry breakpoint: when certain conditions occur, a telemetry breakpoint can be set
		#this triggers two things: data capture is suspended until the breakpoint is cleared
		#waiting threads are awakened
		#In theory this allows a waiting thread to examine anomalous data and then clear the breakpoint (or take other actions)
		self.not_breakpoint = threading.Event()
		self.breakpoint = threading.Event()
		self.release_breakpoint()

		self.locate_fairing()
		self.calculate_ballast_mass()

		#Register all telemetry streams
		self.telemetry_functions = {
			'met' : self.conn.add_stream(getattr, self.vessel, 'met'),
			'fairing_temp' : self.conn.add_stream(getattr,self.fairing, 'skin_temperature'),
			'dry_mass' : self.conn.add_stream(getattr,self.vessel, 'dry_mass'),
			'mass' : self.conn.add_stream(getattr,self.vessel, 'mass'),
			'specific_impulse' : self.conn.add_stream(getattr,self.vessel, 'specific_impulse'),
			'fuel' : self.conn.add_stream(self.vessel.resources.amount, 'LiquidFuel'),
			'oxidiser' : self.conn.add_stream(self.vessel.resources.amount, 'Oxidizer'),
			'ec' : self.conn.add_stream(self.vessel.resources.amount, 'ElectricCharge'),
			'ap_time' : self.conn.add_stream(getattr, self.vessel.orbit, 'time_to_apoapsis'),
			'pe_time' : self.conn.add_stream(getattr, self.vessel.orbit, 'time_to_periapsis'),
			'apoapsis' : self.conn.add_stream(getattr, self.vessel.orbit, 'apoapsis_altitude'),
			'periapsis' : self.conn.add_stream(getattr, self.vessel.orbit, 'periapsis_altitude'),
			'direction' : self.conn.add_stream(self.vessel.direction,vessel.orbit.body.reference_frame),
			'velocity' : self.conn.add_stream(self.vessel.velocity,vessel.orbit.body.reference_frame),
			'ground_speed' : self.conn.add_stream(getattr, self.vessel.flight(vessel.orbit.body.reference_frame), 'speed'),
			'orbital_speed' : self.conn.add_stream(getattr, self.vessel.orbit, 'speed'),
			'altitude' : self.conn.add_stream(getattr, self.vessel.flight(vessel.orbit.body.reference_frame), 'mean_altitude'),
			'autopilot' : self.conn.add_stream(getattr, self.conn.mech_jeb.ascent_autopilot, 'enabled'),
			'ap_status' : self.conn.add_stream(getattr, self.conn.mech_jeb.ascent_autopilot, 'status')
		}

		#Set a telemetry data rate of 1/second
		for i in self.telemetry_functions:
#			self.telemetry_functions[i].rate = 1
			self.telemetry_functions[i].start()

		#Calculate vessel constants
		self.telemetry_data = {
			'ballast_mass' : self.calculate_ballast_mass(),
			'max_fairing_temp' : self.fairing.max_skin_temperature
		}

		#Variable derived data is calculated in the monitor function

		self.thread_run = True

		self.mon_thread = threading.Thread(target=self.monitor)
		self.mon_thread.daemon = True
		self.mon_thread.start()

#		self.mon_thread = threading.Thread(target=self.autoprint)
#		self.mon_thread.daemon = True
#		self.mon_thread.start()



	def locate_fairing(self):
		fairing_list = self.vessel.parts.fairings

		#In theory, r3 rockets (and others I design) should have just one fairing.
		#If they don't, then it's a matter of random choice. I might as well choose the first

		self.fairing = fairing_list[0].part

	def calculate_ballast_mass(self):
		ballast_mass = 0
		for i in self.vessel.resources.all:
			if not i.enabled:
				ballast_mass += i.amount * i.density
		return ballast_mass

	def deltav(self):
		#deltav = ve * ln (m0 / mf)
		#deltav = Isp * g0 * ln ( m0 / mf )

		m0 = self.vessel.mass
		mf = self.telemetry_data['dry_mass'] + self.telemetry_data['ballast_mass']
		g0 = 9.80665
		Isp = self.telemetry_data['specific_impulse']

		return (Isp * g0 * math.log (m0 / mf))

	def angle_of_attack(self):

		d = self.telemetry_data['direction']
		v = self.telemetry_data['velocity']

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

		return angle


	def monitor(self):
		tm_error = False
		while self.thread_run == True:
			#Read telemetry
			for i in self.telemetry_functions:
				try:
					self.telemetry_data[i] = self.telemetry_functions[i]()
				except:
					tm_error = True


			#Calculate derived values
			self.telemetry_data['propellant_mass'] = self.telemetry_data['mass'] - self.telemetry_data['dry_mass'] - self.telemetry_data['ballast_mass']
			self.telemetry_data['delta_v'] = self.deltav()
			self.telemetry_data['fuel'] -= self.telemetry_data['ballast_mass'] / 5
			self.telemetry_data['fairing_heat_percent'] = 100 * self.telemetry_data['fairing_temp'] / self.telemetry_data['max_fairing_temp']
			self.telemetry_data['aoa'] = self.angle_of_attack()

			#Vessel state:
			# 1 = autopilot stopped
			# 2 = LF starved
			# 4 = OX starved
			# 8 = EC starved
			# 16 = Heat problems
			# 32 = AOA too big
			# 64 = Passed apoapsis during insertion
			# 128 = Stream error

			self.telemetry_data['vessel_state'] = 0
			
			if self.telemetry_data['autopilot'] == False and self.telemetry_data['altitude'] > 100:
				self.telemetry_data['vessel_state'] += 1

			if self.telemetry_data['fuel'] < 0.1:
				self.telemetry_data['vessel_state'] += 2
				
			if self.telemetry_data['oxidiser'] < 0.1:
				self.telemetry_data['vessel_state'] += 4

			if self.telemetry_data['ec'] < 0.1:
				self.telemetry_data['vessel_state'] += 8

			if self.telemetry_data['fairing_heat_percent'] > 75:
				self.telemetry_data['vessel_state'] += 16

			if self.telemetry_data['aoa'] > 10 and self.telemetry_data['altitude'] > 100 and self.telemetry_data['altitude'] < 70000:
				self.telemetry_data['vessel_state'] += 32

			if self.telemetry_data['ap_time'] > self.telemetry_data['pe_time'] and self.telemetry_data['ap_status'] != "Circularizing" and self.telemetry_data['altitude'] > 100:
				self.telemetry_data['vessel_state'] += 64			

			if tm_error == True:
				self.telemetry_data['vessel_state'] += 128			
	
			if self.telemetry_data['vessel_state'] > 0:
				self.trigger_breakpoint()
			time.sleep(1)

			self.not_breakpoint.wait()

	def release_breakpoint(self):
		self.breakpoint.clear()
		self.not_breakpoint.set()

	def trigger_breakpoint(self):
		self.breakpoint.set()
		self.not_breakpoint.clear()

	def wait_breakpoint(self):
		self.breakpoint.wait()

	def read_telemetry(self,parameter):
		return str(self.telemetry_data[parameter])

	def autoprint(self):
		display_data = OrderedDict()
		display_data['vessel_state']='VST'
		display_data['met']='MET'
		display_data['periapsis'] = 'PER'
		display_data['apoapsis'] = 'APO'
		display_data['altitude'] = 'ALT'
		display_data['pe_time'] = 'PET'
		display_data['ap_time'] = 'APT'
		display_data['ground_speed'] = 'GS'
		display_data['orbital_speed'] = 'OS'
		display_data['aoa'] = 'AOA'
		display_data['fairing_heat_percent'] = 'HEAT'
		display_data['fuel'] = 'FUEL'
		display_data['oxidiser'] = 'OX'
		display_data['ec'] = 'EC'
		display_data['delta_v'] = 'DV'


		while self.thread_run:
			print "-----------------------------------------------------"
			for i in display_data:
				try:
					print display_data[i] + "\t" + str(int(self.telemetry_data[i]))
				except:
					print display_data[i]
			time.sleep(1)

	def report(self):
		return self.read_telemetry('met') + ';' + self.read_telemetry('delta_v') + ';' + self.read_telemetry('vessel_state') + ';' + self.read_telemetry('periapsis') + ';' + self.read_telemetry('apoapsis') 

	def __del__(self):
		self.thread_run = False
		self.release_breakpoint()
		



class mission_planner:
	def __init__(self,connection,save_dir):
		self.connection = connection
		self.ship_type = None
		self.payload_mass = None
		self.save_dir = os.path.normpath(save_dir)
		self.launch_complete = threading.Event()

	def wait(self):
		self.launch_complete.wait()

	def load_template(self,template):
		with open(template, 'r') as file:
			self.save_data = file.read()
		self.ship_type = os.path.basename(template)

	def prepare_ship(self,mass):
		fuel_units = (mass - 25) / 5
		assert(fuel_units) >= 0	
		data = self.save_data.replace('PUTXFUELXHERE', str(fuel_units) )
		savefile = self.save_dir + '/current.sfs'
		with open(savefile, 'w') as file:
			data = file.write(data)
		self.payload_mass = mass
			
	def launch(self,turn_speed,turn_angle,inclination,mass=None,template=None):
		self.launch_complete.clear()
		if template != None:
			self.load_template(template)

		if mass != None:
			self.prepare_ship(mass)

		time.sleep(10)
		connection.space_center.load('current')
		time.sleep(10)
		vessel = connection.space_center.active_vessel
		monitor = vessel_monitor(connection,vessel)
		ap = mj_launch_autopilot(connection,vessel,turn_speed,turn_angle,inclination)
		time.sleep(1)
		ap.launch()
		monitor.wait_breakpoint()
		self.launch_complete.set()
		return self.ship_type + ';' + str(self.payload_mass) + ';' + str(inclination) + ';' + str(turn_speed) + ';' + str(turn_angle) + ';' + monitor.report()


connection = krpc.connect()
mp=mission_planner(connection,'/home/ealvarez/GOG Games/Kerbal Space Program/game/saves/rocket tests')
mp.load_template('/home/ealvarez/ksp/rocket tests/r-3/templates/R3-400-S1-H01N1X.sfs')
for inclination in [0,-90]:
	for mass in [25,50,75,100,125,150,175,200,300,400,450,460,470,480,500,600,650,660,670,680,700]:
		mp.prepare_ship(mass)
		for angle in range(3,40):
			print mp.launch(50,angle,-90)
time.sleep(10)


#R3-400 max payload = 670 EQ, 470 polar