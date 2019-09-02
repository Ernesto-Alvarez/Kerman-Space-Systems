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


		while self.thread_run:
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
		self.coarse_grid_size = 5
		self.coarse_grid = coarse_grid(self.analysis_steep_limit,self.analysis_shallow_limit,self.coarse_grid_size)
		self.max_dv = {}
		self.steep_envelope = {}
		self.shallow_envelope = {}
		self.envelope_size = {}
		self.max_dv_line = {}
		self.steep_corridor = {}
		self.shallow_corridor = {}


	def dv_rises_to_steep(self,mass,angle):
		return self.data_recorder.read(mass,angle)[1] <= self.data_recorder.read(mass,angle-1)[1] and self.orbits(mass,angle-1)

	def dv_rises_to_shallow(self,mass,angle):
		return self.data_recorder.read(mass,angle)[1] <= self.data_recorder.read(mass,angle+1)[1] and self.orbits(mass,angle+1)

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


	def dv_at_95(self,mass,angle):
		return self.orbits(mass,angle) and ( self.data_recorder.read(mass,angle)[1] >= 0.95 * self.max_dv[mass] )


	def orbits(self,mass,angle):
		(met,delta_v,state,periapsis,apoapsis) = self.data_recorder.read(mass,angle)
		return (state & 62) == 0 and apoapsis > 78000 and periapsis > 70000
		#No resource exhaustion or ship damage, apoapsis close to 80Km, periapsis above kerman line

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

	def coarse_search_steep_envelope(self,mass,test_criterion=None):
		#Return a possible range for the upper part of the envelope, as (shallow,steep) tuple
		for i in self.coarse_grid.list():
			#print "Steep Coarse: ",i
			if test_criterion(mass,i):
				return (self.coarse_grid.angle(max(0,self.coarse_grid.index(i) - 1)),i)
		return None

	def coarse_search_shallow_envelope(self,mass,test_criterion=None):
		start_bracket = self.coarse_search_steep_envelope(mass,test_criterion)
		if start_bracket == None:
			return None
		else:
			start = start_bracket[1]
		grid = self.coarse_grid.tail(start)

		for i in grid:
			if not test_criterion(mass,i):
				return (self.coarse_grid.angle(self.coarse_grid.index(i) - 1),i)
		return grid[-1]

	def locate_steep_envelope(self,mass,hint=None):
		#Differential search first
		result = self.fine_search_steep_envelope(mass,start_point=hint,test_criterion=self.orbits)
		if result != None:
			return result

		#If we cannot find via differential search, we try to bracket the envelope
		bracket = self.coarse_search_steep_envelope(mass,test_criterion=self.orbits)
		if bracket == None:		#There is no envelope at this mass
			return None

		#Fine search within bracket
		steep = bracket[0]
		shallow = bracket[1]
		return self.fine_search_steep_envelope(mass,test_criterion=self.orbits,steep_limit=steep,shallow_limit=shallow)

	def locate_shallow_envelope(self,mass,hint=None):
		#Differential search first
		result = self.fine_search_shallow_envelope(mass,start_point=hint,test_criterion=self.orbits)
		if result != None:
			return result

		#If we cannot find via differential search, we try to bracket the envelope
		bracket = self.coarse_search_shallow_envelope(mass,test_criterion=self.orbits)
		if bracket == None:		#There is no envelope at this mass
			return None

		#Fine search within bracket
		steep = bracket[0]
		shallow = bracket[1]
		return self.fine_search_shallow_envelope(mass,test_criterion=self.orbits,steep_limit=steep,shallow_limit=shallow)


	def plot_flight_envelope(self):
		#Plot 100Kg starting envelope
		steep = self.locate_steep_envelope(100)
		shallow = self.locate_shallow_envelope(100)
		size = shallow - steep

		#We are assuming that 100KG always works, beware!
		self.steep_envelope[100] = steep
		self.shallow_envelope[100] = shallow
		self.envelope_size[100] = size
		mass = 100

		#Try to use diff search for the rest
		while steep != None:
			mass += 100
			steep = self.locate_steep_envelope(mass,hint=steep)
			if steep != None:
				self.steep_envelope[mass] = steep
			shallow = self.locate_shallow_envelope(mass,hint=shallow)
			if shallow != None:
				self.shallow_envelope[mass] = shallow
			if steep != None and shallow != None:
				self.envelope_size[mass] = shallow - steep

		#Detailed plot of max payload envelope
		mass = min(max(self.shallow_envelope),max(self.steep_envelope))
		steep = self.steep_envelope[mass]
		shallow = self.shallow_envelope[mass]

		while steep != None:
			mass += 10
			steep = self.locate_steep_envelope(mass,hint=steep)
			if steep != None:
				self.steep_envelope[mass] = steep
			shallow = self.locate_shallow_envelope(mass,hint=shallow)
			if shallow != None:
				self.shallow_envelope[mass] = shallow
			if steep != None and shallow != None:
				self.envelope_size[mass] = shallow - steep

		#Detailed plot of ultralight values
		for mass in range(100,30,-10):		#Minimum test value is 25Kg, and we start with 30 as it is the first one aligned to the high res grid

			steep = self.steep_envelope[mass]
			shallow = self.shallow_envelope[mass]

			self.steep_envelope[mass-10] = self.locate_steep_envelope(mass-10,hint=steep)
			self.shallow_envelope[mass-10] = self.locate_shallow_envelope(mass-10,hint=shallow)
			self.envelope_size[mass-10] = shallow - steep	

		for mass in self.steep_envelope:
			self.max_dv_line[mass] = self.locate_max_dv_bs(mass)
			self.max_dv[mass] = self.data_recorder.read(mass,self.max_dv_line[mass])[1]
			start_point = self.max_dv_line[mass]

		for mass in self.steep_envelope:
			#print "Corridor search", mass
			max_dv_point = self.max_dv_line[mass]
			self.steep_corridor[mass]  = self.fine_search_steep_envelope(mass,start_point=max_dv_point,test_criterion=self.dv_at_95,steep_limit=self.steep_envelope[mass]-1,shallow_limit=self.shallow_envelope[mass]+1)
			self.shallow_corridor[mass]  = self.fine_search_shallow_envelope(mass,start_point=max_dv_point,test_criterion=self.dv_at_95,steep_limit=self.steep_envelope[mass]-1,shallow_limit=self.shallow_envelope[mass]+1)


class coarse_grid:
	def __init__(self,steep,shallow,size):
		temp_grid = range(0,91,size)
		self.grid = [steep]
		for i in temp_grid:
			if i > steep and i < shallow:
				self.grid.append(i)
		self.grid.append(shallow)

	def tail(self,index):
		return self.grid[index:]
	def list(self):
		return self.grid
	def angle(self,index):
		return self.grid[index]
	def index(self,angle):
		i=0
		while self.grid[i] != angle:
			i += 1
		return i
	


connection = krpc.connect()
mp=mission_planner(connection,'../../../GOG Games/Kerbal Space Program/game/saves/rocket tests')
mp.load_template('../templates/R3-400-S1-H01N1X.sfs')
flight_recorder = flight_data_recorder(mp,50,"R3-400-H01N1X",0,log_file="../test-data/r3-test-data.fd")
envelope = flight_envelope(flight_recorder)

envelope.plot_flight_envelope()

print "Steep", envelope.steep_envelope
print "Shallow", envelope.shallow_envelope
print "Size", envelope.envelope_size
print "Max Delta V angle", envelope.max_dv_line
print "Max Delta V", envelope.max_dv
print "DV 95 steep", envelope.steep_corridor
print "DV 95 shallow", envelope.shallow_corridor

time.sleep(2)


#R3-400 max payload = 670 EQ, 470 polar
#R3-800 max payload = ?? eq, ?? polzr