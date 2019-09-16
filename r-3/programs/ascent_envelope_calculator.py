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

		for i in self.telemetry_functions:
			self.telemetry_functions[i].rate = 1
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

		self.mon_thread = threading.Thread(target=self.autoprint)
		self.mon_thread.daemon = True
		self.mon_thread.start()



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

			if self.telemetry_data['fuel'] < 0.27:			#Enough for a 10m/s deorbit burn
				self.telemetry_data['vessel_state'] += 2
				
			if self.telemetry_data['oxidiser'] < 0.33:		#Enough for a 10m/s deorbit burn
				self.telemetry_data['vessel_state'] += 4

			if self.telemetry_data['ec'] < 1:
				self.telemetry_data['vessel_state'] += 8

			if self.telemetry_data['fairing_heat_percent'] > 75:
				self.telemetry_data['vessel_state'] += 16

			if self.telemetry_data['aoa'] > 10 and self.telemetry_data['altitude'] > 100 and self.telemetry_data['altitude'] < 40000:
				self.telemetry_data['vessel_state'] += 32

			if self.telemetry_data['aoa'] > 20 and self.telemetry_data['altitude'] > 40000 and self.telemetry_data['altitude'] < 70000:
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


		while self.thread_run == True:
			print "-----------------------------------------------------"
			for i in display_data:
				try:
					print display_data[i] + "\t" + str(int(self.telemetry_data[i]))
				except:
					print display_data[i]
			time.sleep(1)

	def report(self):
		#return self.read_telemetry('met') + ';' + self.read_telemetry('delta_v') + ';' + self.read_telemetry('vessel_state') + ';' + self.read_telemetry('periapsis') + ';' + self.read_telemetry('apoapsis') 
		return (self.read_telemetry('met'),self.read_telemetry('delta_v'),self.read_telemetry('vessel_state'),self.read_telemetry('periapsis'),self.read_telemetry('apoapsis'))

	def stop_threads(self):
		self.thread_run = False

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
		monitor.stop_threads()		#Have to manually shut down threads because the destructor doesn't, or isn't called as monitor goes out of scope
		#return self.ship_type + ';' + str(self.payload_mass) + ';' + str(inclination) + ';' + str(turn_speed) + ';' + str(turn_angle) + ';' + monitor.report()
		return monitor.report()


class flight_data_recorder:
	def __init__(self,mission_planner,turn_speed,ship_type=None,inclination=0,log_file=None,allow_unknown=False):
		self.log_fd = None

		self.inclination = inclination
		if ship_type == None:
			self.ship_type = '*'
		else:
			self.ship_type = ship_type

		self.turn_speed = turn_speed
		self.flight_data = {}
		self.mass_index = {}
		self.mission_planner = mission_planner

		if log_file != None:
			try:
				self.load_data(log_file,log_data=False)
			except IOError:
				self.save_data(log_file)
			self.log_fd = open(log_file,"a")


	def add_entry(self,mass,angle,met,delta_v,state,apoapsis,periapsis,log_data=True):

		#Configure logging
		if self.log_fd == None:
			log_data = False

		if mass in self.mass_index:
			self.mass_index[mass].add(angle)
		else:
			self.mass_index[mass] = {angle}

		self.flight_data[(mass,angle)] = (met,delta_v,state,apoapsis,periapsis)
		
		if log_data == True:
			self.log_fd.write(self.to_file(self.ship_type,mass,self.inclination,self.turn_speed,angle,met,delta_v,state,apoapsis,periapsis))
			self.log_fd.flush()


	def to_file(self,ship_type,mass,inclination,turn_speed,angle,met,delta_v,state,apoapsis,periapsis):
		return self.ship_type + ";" + str(mass) + ";" + str(self.inclination) + ";" + str(self.turn_speed) + ";" + str(angle) + ";" + str(met) + ";" + str(delta_v) + ";" + str(state) + ";" + str(apoapsis) + ";" + str(periapsis) + "\n"

	def from_file(self,line):
		(ship_type,mass,inclination,turn_speed,angle,met,delta_v,state,apoapsis,periapsis) = line.rstrip('\n').split(';')
		return (ship_type, int(mass), int(inclination), int(turn_speed), int(angle), float(met), float(delta_v), int(state), float(apoapsis), float(periapsis))

	def load_data(self,file_name,alternate_ship_type=None,allow_unknown=False,log_data=True):
		#configure target object types
		if alternate_ship_type == None:
			alternate_ship_type = self.ship_type


		#Open file
		fd = open(file_name,"r")
		
		#Read every line, skip if comment
		for line in fd:
			if line[0] != "#":
				(ship_type,mass,inclination,turn_speed,angle,met,delta_v,state,apoapsis,periapsis) = self.from_file(line)

				#Load data if relevant to current test, skip otherwise
				if (ship_type == alternate_ship_type or (allow_unknown == True and ship_type == "*")) and \
				self.inclination == inclination and \
				self.turn_speed == turn_speed:
					self.add_entry(mass,angle,met,delta_v,state,apoapsis,periapsis,log_data=log_data)
		fd.close()				


	def save_data(self,file_name):
		#Open file
		fd = open(file_name,"w")

		#Write header
		fd.write("#Flight data file, revision 1\n")
		fd.write("#Data contained here is a CSV with ship type, mass, inclination, turn speed, gravity turn angle (from zenith), remaining delta v after orbit or failure, final ship state (see moonitor object), apoapsis, periapis.\n")
		fd.write("#Lines starting with pound are taken as coments\n")
		fd.write("#The original ship type for this file is: " + self.ship_type + "\n")

		#Write data
		for i in self.flight_data:
			(mass,angle) = i
			(met,delta_v,state,apoapsis,periapsis) = self.flight_data[i]
			fd.write(self.to_file(self.ship_type,mass,self.inclination,self.turn_speed,angle,met,delta_v,state,apoapsis,periapsis))

		fd.close()

	def test_mission(self,mass,angle):
		#Call the mission planner and perform a test flight. Then we add the results to the flight data and log
		(met,delta_v,state,apoapsis,periapsis) = self.mission_planner.launch(self.turn_speed,angle,self.inclination,mass=mass)

		
		met = float(met)
		delta_v = float(delta_v)
		state = int(state)
		apoapsis = float(apoapsis)
		periapsis = float(periapsis)		
		
		self.add_entry(mass,angle,met,delta_v,state,apoapsis,periapsis)


	def list_by_mass(self,mass):
		retvalue = []
		for i in mass_index:
			retvalue.append(i)
		return retvalue
		
	def read(self,mass,angle,research=True):
		#if we do not know have the flight test data yet, research it unless we don't want to
		if research == True and (mass,angle) not in self.flight_data:
			self.test_mission(mass,angle)
		
		
		#Force return data. We'll get a key error if we did not want to do a research flight.
		#If we allow research, we'll always have it (either we already had it, or we run a test flight)
		return self.flight_data[(mass,angle)]
				
	def __del__(self):
		if self.log_fd != None:
			self.log_fd.close()

class flight_envelope:
	def __init__(self, data_recorder):
		self.data_recorder = data_recorder
		self.default_fine_bracket_size = 10
		self.analysis_shallow_limit = 60
		self.analysis_steep_limit = 1
		self.max_dv = {}
		self.steep_envelope = {}
		self.shallow_envelope = {}
		self.envelope_size = {}
		self.max_dv_line = {}
		self.steep_corridor = {}
		self.shallow_corridor = {}
		self.envelope_reference_point = {}
		self.grapher = grapher(self.data_recorder.ship_type)

#=====Search criteria: used as a criterion function for different searches

	def dv_at_98(self,mass,angle):
		return self.orbits(mass,angle) and ( self.data_recorder.read(mass,angle)[1] >= 0.98 * self.max_dv[mass] )

	def orbits(self,mass,angle):
		(met,delta_v,state,periapsis,apoapsis) = self.data_recorder.read(mass,angle)
		return (state & 62) == 0 and apoapsis > 78000 and periapsis > 70000
		#No resource exhaustion or ship damage, apoapsis close to 80Km, periapsis above kerman line

	def dv_rises_to_steep(self,mass,angle):
		return self.data_recorder.read(mass,angle)[1] <= self.data_recorder.read(mass,angle-1)[1] and self.orbits(mass,angle-1)

	def dv_rises_to_shallow(self,mass,angle):
		return self.data_recorder.read(mass,angle)[1] <= self.data_recorder.read(mass,angle+1)[1] and self.orbits(mass,angle+1)

#delta v calculation functions, these are different from others, because max dv is a line and the direction of rise needs to be checked

	def locate_max_dv(self,mass,steep_limit=None,shallow_limit=None,start_point=None):
		if start_point == None:
			return self.locate_max_dv_bs(mass,steep_limit,shallow_limit)
		else:
			return self.locate_max_dv_ls(mass,start_point)

	def locate_max_dv_ls(self,mass,start_point=None):
		#Do a linear search for the angle with max dv remaining after orbit
		#This function takes a starting point and climbs the curve until a local maximum is found
		#Ideal for completing the base case for the binary search
		#MUST start within the envelope to work
	
		#Check all parameters
		if start_point > self.shallow_envelope[mass] or start_point < self.steep_envelope[mass]:
			start_point = None

		if start_point == None:
			start_point = ( self.steep_envelope[mass] + self.shallow_envelope[mass] ) / 2
	
		angle = start_point

		while angle >= self.analysis_steep_limit and angle <= self.analysis_shallow_limit:
			#print "LS Try: ", angle
			if self.dv_rises_to_steep(mass,angle):
				angle -= 1
			else:
				if self.dv_rises_to_shallow(mass,angle):
					angle += 1
				else:
					#print "LS Final result: ", angle
					return angle

		#Goes to maximum at the limit of the envelope!
		return angle	

	def locate_max_dv_bs(self,mass,steep_limit=None,shallow_limit=None):
		#Do a binary search, bracketing the max dv point as quickly as possible, and recursively divide and conquer the problem
		#Linear search when the search space is small enough
		#Requires knowing the envelope if not providing limits

		if steep_limit == None:
			steep_limit = self.steep_envelope[mass]

		if shallow_limit == None:
			shallow_limit = self.shallow_envelope[mass]

		angle = ( steep_limit + shallow_limit ) / 2

		#print "BS Try: ", steep_limit,angle,shallow_limit

		if shallow_limit - steep_limit < 4:		#With 3 or less, it's cheaper to do the linear search
			return self.locate_max_dv_ls(mass,angle)

		if self.dv_rises_to_shallow(mass,angle):
			return self.locate_max_dv_bs(mass,angle,shallow_limit)
		else:
			return self.locate_max_dv_bs(mass,steep_limit,angle)

#Generic search functions: fine and coarse functions for locating different parts of the envelope

			# 1 = autopilot stopped				not an indicator
			# 2 = LF starved				indicator of steep launch
			# 4 = OX starved				indicator of steep launch
			# 8 = EC starved				indicator of shallow launch
			# 16 = Heat problems				indicator of shallow launch
			# 32 = AOA too big				indicator of shallow launch
			# 64 = Passed apoapsis during insertion		maybe a shallow indicator if it happens in the atmosphere?
			# 128 = Stream error				not an indicator

	def envelope_locator(self,mass,steep_limit=None,shallow_limit=None):
	#Locate a point of the envelope (a mass/angle input where the ship orbits)
		if mass in self.steep_envelope and mass in self.shallow_envelope:
			self.reference_point[mass] = ( steep_envelope + shallow_envelope ) / 2
			return ( steep_envelope + shallow_envelope ) / 2

		if steep_limit == None:
			steep_limit = self.analysis_steep_limit
		if shallow_limit == None:
			shallow_limit = self.analysis_shallow_limit

		test_points = [(steep_limit,shallow_limit)]

		while test_points != []:
			#print test_points
			steep_limit = test_points[0][0]
			shallow_limit = test_points[0][1]
			angle = ( steep_limit + shallow_limit ) / 2

			#print steep_limit,angle,shallow_limit

			if self.orbits(mass,angle):
				#We've got a point, hurray!
				self.envelope_reference_point[mass] = angle
				return angle

			test_points = test_points[1:]	

			vessel_state = self.data_recorder.read(mass,angle)[2]	
			apoapsis = self.data_recorder.read(mass,angle)[4]
			periapsis = self.data_recorder.read(mass,angle)[3]
			print vessel_state,periapsis,apoapsis

			if vessel_state & 6 != 0 or ( apoapsis > 70000 and periapsis < 70000 and vessel_state & 64):		#Steep indicators
				print "Steep result"
				if shallow_limit - angle > 3:
					test_points.append((angle,shallow_limit))
				for i in test_points:
					if i[1] < angle:
						test_points.remove[i]

			if vessel_state & 56 != 0 or ( vessel_state & 64 and apoapsis < 70000):		#shallow indicators
				print "Shallow result"
				if angle - steep_limit > 3:
	 				test_points.append((steep_limit,angle))
				for i in test_points:
					if i[0] > angle:
						test_points.remove[i]

			#Trap if we reach an unusual condition, we'll have to fix it in this case
			#print vessel_state, apoapsis
			assert(vessel_state & 56 != 0 or ( vessel_state & 64 and apoapsis < 70000) or vessel_state & 6 != 0 or ( apoapsis > 70000 and periapsis < 70000 and vessel_state & 64) )
		return None

	def shallow_envelope_bs(self,mass,steep_limit=None,shallow_limit=None,start_point=None,test_criterion=None):
		if steep_limit == None:
			try:
				steep_limit = self.envelope_reference_point[mass]
			except KeyError:
				self.envelope_locator(mass)
				steep_limit = self.envelope_reference_point[mass]
				if steep_limit == None:
					return None

		if shallow_limit == None:
			shallow_limit = self.analysis_shallow_limit

		angle = ( steep_limit + shallow_limit ) / 2

		#print "Shallow BS Try: ",mass, steep_limit,angle,shallow_limit

		if shallow_limit - steep_limit < 4:		#With 3 or less, it's cheaper to do the linear search
			return self.fine_search_shallow_envelope(mass,steep_limit,shallow_limit,angle,test_criterion)		

		if test_criterion(mass,angle):
			return self.shallow_envelope_bs(mass,angle,shallow_limit,test_criterion=test_criterion)
		else:
			return self.shallow_envelope_bs(mass,steep_limit,angle,test_criterion=test_criterion)



	def steep_envelope_bs(self,mass,steep_limit=None,shallow_limit=None,start_point=None,test_criterion=None):
		if shallow_limit == None:
			try:
				shallow_limit = self.envelope_reference_point[mass]
			except KeyError:
				if self.envelope_locator(mass) == None:
					return None

				shallow_limit = self.envelope_reference_point[mass]


		if steep_limit == None:
			steep_limit = self.analysis_steep_limit

		angle = ( steep_limit + shallow_limit ) / 2

		#print "Steep BS Try: ",mass, steep_limit,angle,shallow_limit


		if shallow_limit - steep_limit < 4:		#With 3 or less, it's cheaper to do the linear search
			return self.fine_search_steep_envelope(mass,steep_limit,shallow_limit,angle,test_criterion)		

		if test_criterion(mass,angle):
			return self.steep_envelope_bs(mass,steep_limit,angle,test_criterion=test_criterion)
		else:
			return self.steep_envelope_bs(mass,angle,shallow_limit,test_criterion=test_criterion)


	def fine_search_shallow_envelope(self,mass,steep_limit=None,shallow_limit=None,start_point=None,test_criterion=None):
		#Do a fine search of the lower end of an envelope content
		#Takes a criterion, which decides what is being tested and at least one of the starting point, shallow and steep bracket
		#Use the start point only for differential searches, and bracket only for fine search
		#Object contains default bracket size
	
		#Check all parameters
		if test_criterion == None:		#We're testing....nothing
			return None
		if shallow_limit == None and \
		steep_limit == None and \
		start_point == None:			#Not a fine search, if there is no bracketing....
			return None

		if shallow_limit == None and steep_limit == None:	#We've got just a start point
			steep_limit = start_point - (self.default_fine_bracket_size / 2)	#fill the steep limit, the shallow will be filled below

		if steep_limit != None and shallow_limit == None:
			shallow_limit = steep_limit + self.default_fine_bracket_size
			#And ensure the bracket includes the start point, if present
			if start_point != None:
				shallow_limit == min(start_point,shallow_limit)

		if shallow_limit != None and steep_limit == None:
			steep_limit = shallow_limit - self.default_fine_bracket_size
			#And ensure the bracket includes the start point, if present
			if start_point != None:
				steep_limit == max(start_point,steep_limit)

		if start_point == None:
			start_point = ( steep_limit + shallow_limit ) / 2

		#At this point, we should have all 3 values calculated
		assert(steep_limit != None and shallow_limit != None and start_point != None)

		#Make sure everything falls within the analysis limits
		shallow_limit = min(max(shallow_limit,self.analysis_steep_limit),self.analysis_shallow_limit)
		steep_limit = min(max(steep_limit,self.analysis_steep_limit),self.analysis_shallow_limit)
		start_point = min(max(start_point,self.analysis_steep_limit),self.analysis_shallow_limit)
	
		angle = start_point

		#While we're in the envelope, move outwards (we might already be outside and then this is skipped)
		while angle <= shallow_limit and test_criterion(mass,angle):
			angle += 1

		#If we go out of bounds, the fine search fails, unless we're at the very limit
		if angle > shallow_limit:
			if shallow_limit == self.analysis_shallow_limit:
				return self.analysis_shallow_limit
			else:
				return None

		#Then, while we're outside of the envelope, search inwards
		while angle >= steep_limit and not test_criterion(mass,angle) :
			angle -= 1

		#If we go out of bounds, the fine search end in a similar way as the out-of-bounds above
		if angle < steep_limit:
			if steep_limit == self.analysis_steep_limit:
				return self.analysis_steep_limit
			else:
				return None

		#When we're in the envelope, we found the envelope limit
		return angle


	def fine_search_steep_envelope(self,mass,steep_limit=None,shallow_limit=None,start_point=None,test_criterion=None):
		#Do a fine search of the upper end of an envelope content
		#Takes a criterion, which decides what is being tested and at least one of the starting point, shallow and steep bracket
		#Use the start point only for differential searches, and bracket only for fine search
		#Object contains default bracket size

		#Check all parameters
		if test_criterion == None:		#We're testing....nothing
			return None
		if shallow_limit == None and \
		steep_limit == None and \
		start_point == None:			#Not a fine search, if there is no bracketing....
			return None

		if shallow_limit == None and steep_limit == None:	#We've got just a start point
			steep_limit = start_point - (self.default_fine_bracket_size / 2)	#fill the steep limit, the shallow will be filled below

		if steep_limit != None and shallow_limit == None:
			shallow_limit = steep_limit + self.default_fine_bracket_size
			#And ensure the bracket includes the start point, if present
			if start_point != None:
				shallow_limit == min(start_point,shallow_limit)

		if shallow_limit != None and steep_limit == None:
			steep_limit = shallow_limit - self.default_fine_bracket_size
			#And ensure the bracket includes the start point, if present
			if start_point != None:
				steep_limit == max(start_point,steep_limit)

		if start_point == None:
			start_point = ( steep_limit + shallow_limit ) / 2

		#At this point, we should have all 3 values calculated
		assert(steep_limit != None and shallow_limit != None and start_point != None)

		#Make sure everything falls within the analysis limits
		shallow_limit = min(max(shallow_limit,self.analysis_steep_limit),self.analysis_shallow_limit)
		steep_limit = min(max(steep_limit,self.analysis_steep_limit),self.analysis_shallow_limit)
		start_point = min(max(start_point,self.analysis_steep_limit),self.analysis_shallow_limit)

		angle = start_point		

		#While we're in the envelope, move outwards (we might already be outside and then this is skipped)
		while angle >= steep_limit and test_criterion(mass,angle):
			#print "Steep fine O: ", mass, angle
			angle -= 1

		#If we go out of bounds, the fine search fails, unless we're at the very limit
		if angle < steep_limit:
			if steep_limit == self.analysis_steep_limit:
				return self.analysis_steep_limit
			else:
				return None

		#Then, while we're outside of the envelope, search inwards
		while angle <= shallow_limit and not test_criterion(mass,angle):
			#print "Steep fine I: ", mass, angle
			angle += 1

		#If we go out of bounds, the fine search end in a similar way as the out-of-bounds above
		if angle > shallow_limit:
			if shallow_limit == self.analysis_shallow_limit:
				return self.analysis_shallow_limit
			else:
				return None

		#When we're in the envelope, we found the envelope limit
		return angle

	def locate_envelope(self,mass,steep=None,shallow=None):
		steep = self.fine_search_steep_envelope(mass,start_point=steep,test_criterion=self.orbits)
		shallow = self.fine_search_shallow_envelope(mass,start_point=shallow,test_criterion=self.orbits)
		if steep != None and shallow != None:
			return (steep,shallow)

		#Fall back to full search if not found
		steep = self.steep_envelope_bs(mass,test_criterion=self.orbits)
		if steep == None:
			return (None,None)
		shallow = self.shallow_envelope_bs(mass,test_criterion=self.orbits)
		return (steep,shallow)	

	def locate_corridor(self,mass,steep=None,shallow=None):
		steep = self.fine_search_steep_envelope(mass,start_point=steep,test_criterion=self.dv_at_98)
		shallow = self.fine_search_shallow_envelope(mass,start_point=shallow,test_criterion=self.dv_at_98)
		#print (mass,steep,shallow)
		if steep != None and shallow != None:
			return (steep,shallow)

		#Fall back to full search if not found
		if steep == None:
			steep = self.steep_envelope_bs(mass,test_criterion=self.dv_at_98,steep_limit=self.steep_envelope[mass]-1,shallow_limit=self.max_dv_line[mass]+1)
		if shallow == None:
			shallow = self.shallow_envelope_bs(mass,test_criterion=self.dv_at_98,steep_limit=self.max_dv_line[mass]-1,shallow_limit=self.shallow_envelope[mass]+1)	
		#print (mass,steep,shallow)	
		return (steep,shallow)	


#Plotting function: calculate the envelope components, interpolate and graph them

	def plot_flight_envelope(self):

		#Plot envelope in 100Kg increments
		#Use secant approximation to calculate the slope and predict future values
		x2 = 100
		(y2_steep, y2_shallow) = self.locate_envelope(x2)
		self.steep_envelope[x2] = y2_steep
		self.shallow_envelope[x2] = y2_shallow

		x3 = 200
		(y3_steep, y3_shallow) = self.locate_envelope(x3,steep=y2_steep,shallow=y2_shallow)
		self.steep_envelope[x3] = y3_steep
		self.shallow_envelope[x3] = y3_shallow

		while True:
			x1 = x2
			y1_steep = y2_steep
			y1_shallow = y2_shallow

			x2 = x3
			y2_steep = y3_steep
			y2_shallow = y3_shallow

			x3 = x2 + 100
			y3_steep_est = y2_steep + ( ( y2_steep - y1_steep ) * ( x3 - x2 ) / ( x2 - x1 ) ) 
			y3_shallow_est = y2_shallow + ( ( y2_shallow - y1_shallow ) * ( x3 - x2 ) / ( x2 - x1 ) ) 

			(y3_steep,y3_shallow) = self.locate_envelope(x3,steep=y3_steep_est,shallow=y3_shallow_est)

			#print (x1,y1_steep,y1_shallow)
			#print (x2,y2_steep,y2_shallow)
			#print (x3,y3_steep,y3_shallow,y3_steep_est,y3_shallow_est)

			if y3_steep == None:
				break

			size = y3_shallow - y3_steep
			self.steep_envelope[x3] = y3_steep
			self.shallow_envelope[x3] = y3_shallow
			self.envelope_size[x3] = size


		#Detailed plot of heavies part of the envelope
		masses = list(self.steep_envelope)
		masses.sort()

		x2 = masses[-2]
		y2_steep = self.steep_envelope[x2]
		y2_shallow = self.shallow_envelope[x2]

		x3 = masses[-1]
		y3_steep = self.steep_envelope[x3]
		y3_shallow = self.shallow_envelope[x3]

		while True:
			x1 = x2
			y1_steep = y2_steep
			y1_shallow = y2_shallow

			x2 = x3
			y2_steep = y3_steep
			y2_shallow = y3_shallow

			x3 = x2 + 10
			y3_steep_est = y2_steep + ( ( y2_steep - y1_steep ) * ( x3 - x2 ) / ( x2 - x1 ) ) 
			y3_shallow_est = y2_shallow + ( ( y2_shallow - y1_shallow ) * ( x3 - x2 ) / ( x2 - x1 ) ) 

			(y3_steep,y3_shallow) = self.locate_envelope(x3,steep=y3_steep_est,shallow=y3_shallow_est)

			#print (x1,y1_steep,y1_shallow)
			#print (x2,y2_steep,y2_shallow)
			#print (x3,y3_steep,y3_shallow,y3_steep_est,y3_shallow_est)

			if y3_steep == None:
				break

			size = y3_shallow - y3_steep
			self.steep_envelope[x3] = y3_steep
			self.shallow_envelope[x3] = y3_shallow
			self.envelope_size[x3] = size


		#Detailed plot of ultralight values

		x2 = 200
		y2_steep = self.steep_envelope[x2]
		y2_shallow = self.shallow_envelope[x2]

		x3 = 100
		y3_steep = self.steep_envelope[x3]
		y3_shallow = self.shallow_envelope[x3]		

		while x3 > 30:
			x1 = x2
			y1_steep = y2_steep
			y1_shallow = y2_shallow

			x2 = x3
			y2_steep = y3_steep
			y2_shallow = y3_shallow

			x3 = x2 - 10
			y3_steep_est = y2_steep + ( ( y2_steep - y1_steep ) * ( x3 - x2 ) / ( x2 - x1 ) ) 
			y3_shallow_est = y2_shallow + ( ( y2_shallow - y1_shallow ) * ( x3 - x2 ) / ( x2 - x1 ) ) 

			(y3_steep,y3_shallow) = self.locate_envelope(x3,steep=y3_steep_est,shallow=y3_shallow_est)

			#print (x1,y1_steep,y1_shallow)
			#print (x2,y2_steep,y2_shallow)
			#print (x3,y3_steep,y3_shallow,y3_steep_est,y3_shallow_est)

			if y3_steep == None:
				break

			size = y3_shallow - y3_steep
			self.steep_envelope[x3] = y3_steep
			self.shallow_envelope[x3] = y3_shallow
			self.envelope_size[x3] = size

		#Calculate maximum dv and angle
		#Do not use secant approximation as it usually remains constant
		masses = list(self.steep_envelope)
		masses.sort(reverse=True)

		mass = masses[0]
		start_point = self.locate_max_dv(mass)
		self.max_dv_line[mass] = start_point
		self.max_dv[mass] = self.data_recorder.read(mass,start_point)[1]


		for mass in masses[1:]:

			start_point = self.locate_max_dv(mass,start_point=start_point)

			self.max_dv_line[mass] = start_point
			self.max_dv[mass] = self.data_recorder.read(mass,start_point)[1]

		#Reassign reference point to maximum delta v angle
		self.envelope_reference_point = self.max_dv_line

		#Using the new reference points, calculate the launch corridor

		x2 = masses[0]
		y2_steep = self.steep_envelope[x2]
		y2_shallow = self.shallow_envelope[x2]

		(y2_steep, y2_shallow) = self.locate_corridor(x2)
		self.steep_corridor[x2] = y2_steep
		self.shallow_corridor[x2] = y2_shallow

		x3 = masses[1]
		(y3_steep, y3_shallow) = self.locate_corridor(x3,steep=y2_steep,shallow=y2_shallow)
		self.steep_corridor[x3] = y3_steep
		self.shallow_corridor[x3] = y3_shallow

		for mass in masses[2:]:

			x1 = x2
			y1_steep = y2_steep
			y1_shallow = y2_shallow

			x2 = x3
			y2_steep = y3_steep
			y2_shallow = y3_shallow

			x3 = mass
			y3_steep_est = y2_steep + ( ( y2_steep - y1_steep ) * ( x3 - x2 ) / ( x2 - x1 ) ) 
			y3_shallow_est = y2_shallow + ( ( y2_shallow - y1_shallow ) * ( x3 - x2 ) / ( x2 - x1 ) ) 

			(y3_steep,y3_shallow) = self.locate_corridor(mass,steep=y3_steep_est,shallow=y3_shallow_est)
			self.steep_corridor[mass] = y3_steep
			self.shallow_corridor[mass] = y3_shallow


		self.grapher.add_dictionary(self.max_dv_line,"Optimal angle")
		self.grapher.add_dictionary(self.shallow_corridor,"Shallow launch corridor")
		self.grapher.add_dictionary(self.steep_corridor,"Steep launch corridor")
		self.grapher.add_dictionary(self.shallow_envelope,"Shallow limit")
		self.grapher.add_dictionary(self.steep_envelope,"Steep limit")

		self.grapher.add_deltav(self.max_dv)

		self.grapher.graph_envelopes()


from scipy.interpolate import interp1d
import matplotlib.pyplot as plt
import numpy as np

class grapher:
	def __init__(self,type):
		self.functions = []
		self.limits = []
		self.dicts = []
		self.labels = []
		self.rocket_type = type
		self.delta_v = None

	def add_deltav(self,dictionary):

		x = []
		y = []
		for i in dictionary:
			x.append(i)

		x.sort()

		for i in x:
			y.append(dictionary[i])
		
		self.delta_v = interp1d(x,y,kind='cubic')

	def add_dictionary(self,dictionary,description=None):
		x = []
		y = []

		for i in dictionary:
			x.append(i)

		x.sort()

		for i in x:
			y.append(dictionary[i])

		self.dicts.append((x,y))
		f = interp1d(x,y,kind='linear')
		self.functions.append(f)
		self.limits.append((x[0],x[-1]))
		self.labels.append(description)

	def graph_envelopes(self):
		plt.subplot(1,2,1)
		for i in range(len(self.functions)):
			x = np.arange(self.limits[i][0],self.limits[i][1],1)
			f = self.functions[i]
			y = f(x)
			label = self.labels[i]
			if label == None:
				plt.plot(x,y)
			else:
				plt.plot(x,y,label=label)				

		plt.legend(loc='lower right')
		plt.title("Ascent envelope", fontsize=12)
		plt.suptitle(self.rocket_type, fontsize=16, fontweight='bold')
		plt.xlabel("Payload mass")
		plt.ylabel("Gravity turn angle")

		plt.subplot(1,2,2)
		x = np.arange(self.limits[i][0],self.limits[i][1],1)
		y = self.delta_v(x)
		plt.plot(x,y,label='Remaining delta V after launch')
		plt.xlabel("Payload mass")
		plt.ylabel("Delta V")

		plt.show()



connection = krpc.connect()
mp=mission_planner(connection,'../../../GOG Games/Kerbal Space Program/game/saves/rocket tests')

mp.load_template('../templates/R3-1200L-S1-H01N1X.sfs')
flight_recorder = flight_data_recorder(mp,50,"R3-1200L-S1-H01N1X",0,log_file="../test-data/r3-test-data.fd")
envelope = flight_envelope(flight_recorder)
envelope.plot_flight_envelope()

print "R3-1200L-S1-H01N1X Max Payload (0 deg): ", max(list(envelope.max_dv_line)), " Kg."


#print "Steep", envelope.steep_envelope
#print "Shallow", envelope.shallow_envelope
#print "Size", envelope.envelope_size
#print "Max Delta V angle", envelope.max_dv_line
#print "Max Delta V", envelope.max_dv
#print "DV 95 steep", envelope.steep_corridor
#print "DV 95 shallow", envelope.shallow_corridor

time.sleep(1)
