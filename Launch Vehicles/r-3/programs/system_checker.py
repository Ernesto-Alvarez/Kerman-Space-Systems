import krpc

#Pad system checker for R-3 series of rockets

def fairing_type(vessel):
	print "Fairing check"
	fairing_types = { 412.95428466796875 : 1 }
	root = vessel.parts.root
	if (root.title != "AE-FF1 Airstream Protective Shell (1.25m)"):
		print "Error: root part is not a fairing"
		return None
	fairing_mass = root.mass
	try:
		type = fairing_types[fairing_mass]
	except:
		print "Error: unknown fairing type"
		return None
	print "Fairing detected: type " + str(type)
	return type

def cargo_bay_type(vessel):
	bay_types = { 1 : "S", 2 : "D" }
	fairing = fairing_type(vessel)
	if fairing == None:
		return None
	payload_bays = 0
	for i in vessel.parts.root.children:
		if (i.title == "TD-12 Decoupler" or i.title == "TD-06 Decoupler"):
			payload_bays = payload_bays + 1
	if (payload_bays == 1 and len(vessel.parts.root.children) == 2):		#1 payload, no avionics = service module
		type = "C" + str(fairing)
	else:
		try:
			type = bay_types[payload_bays] + str(fairing)
		except:
			print "Error: unable to determine cargo bay type"
			return None
	print "Payload bay type: " + type
	return type

def get_stage_pointers(vessel):
	payload_bays = []
	for i in vessel.parts.root.children:
		if (i.title == "TD-12 Decoupler" or i.title == "TD-06 Decoupler"):
			payload_bays.append(i)
		if (i.title == "FL-T400 Fuel Tank"):
			upper_stage = i

class rocket:
	def __init__(self,vessel):
		payload_section = []
		upper_stage = []
		avionics_bay = []
		avionics_hp = []
		lower_sustainer = []	
		boosters = []

		#Payload section is formed by the fairing and the payload decouplers
		fairing = vessel.parts.root

		#Sanity check: ensure that root part is the R-3 fairing
		if (fairing.title != "AE-FF1 Airstream Protective Shell (1.25m)"):
			raise RocketError("Root part is not the fairing. Ensure the R-3 fairing is the rocket root part.")	
		if (fairing.shielded == True):
			raise RocketError("Root fairing appears to be within another fairing. Ensure the R-3 fairing is the rocket root part.")

		#Now, we're sure the root part is the fairing
		payload_section.append(fairing)
		for i in fairing.children:
			#print i.title + " " + str(i.radially_attached) + " " + str(i.axially_attached)
			if i.radially_attached == True:
				raise RocketError("Foreign object attached to fairing. This is not an R-3 rocket or recheck tank/decoupler attachment.")
			if (i.title == "TD-12 Decoupler"):		#It's a payload decoupler
				payload_section.append(i)
			elif (i.title == "FL-T400 Fuel Tank"):		#The upper stage rocket
				upper_stage.append(i)
			else:						#Must be in avionics bay, then
				avionics_bay.append(i)

		#Enumerate contents of avionics bay
		if (len(avionics_bay) != 0):		#empty bay
			current = avionics_bay[0]
			while (len(current.children) != 0):
				if (len_current.children > 1):
					raise RocketError("Multiple attachment in avionics bay")
				if current.children[0].radially_attached
					raise RocketError("Radial attachment in avionics bay")
				avionics_bay.append(current.children[0])
				current = current.children[0]

		print "Tests passed (for now)"
		print "Payload bay contents"
		for i in payload_section:
			print i.title
		print "-------------------------"
		print "Upper stage"
		for i in upper_stage:
			print i.title	
		print "-------------------------"
		print "Avionics bay"
		for i in avionics_bay:
			print i.title
		print "-------------------------"


class RocketError(Exception):
	pass


connection = krpc.connect()
vessel = connection.space_center.active_vessel

r = rocket(vessel)

#print cargo_bay_type(vessel)
