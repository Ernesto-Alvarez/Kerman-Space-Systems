import argparse
import sys

def read_parameters():
	parser = argparse.ArgumentParser(description='Creates profile data of a planet, for use by other applications')
	operation = parser.add_mutually_exclusive_group()
	operation.add_argument('--add',help='add planet to database, overwriting if already present',action='store_true')
	operation.add_argument('--read',help='display data from a planet in the database',action='store_true')
#	operation.add_argument('--change',help='change a parameter of a planet in the planet database, use any parameters not taken from the database',action='store_true')
#	operation.add_argument('--delete',help='delete entry from database',action='store_true')
	parser.add_argument('-p','--planet',help='planet name')
	parser.add_argument('-r','--radius',help='planet radius, im metres',type=int)
	parser.add_argument('-m','--mass',help='planet mass, in kilograms',type=float)
	parser.add_argument('-s','--surface-accel',help='surface acceleration due to gravity, in metres per second squared',type=float)
	parser.add_argument('--sample-point-altitude',help='altitude of sample point, in metres',type=int)
	parser.add_argument('--sample-point-accel',help='acceleration due to gravity at sample point, in metres per second squared',type=float)
	parser.add_argument('--sample-point-over-centre',help='consider sample point altitude over planet centre, default is over surface',action='store_true')

	args = parser.parse_args()

	if not args.add and not args.read:
		sys.stderr.write("one of --add or --read must be selected\n\n")
		parser.print_help(sys.stderr)
		exit(1)

	if args.planet == None:
		sys.stderr.write("planet name must be entered\n\n")
		parser.print_help(sys.stderr)
		exit(1)		

	if args.radius == None and args.add:
		sys.stderr.write("planet radius must be entered\n\n")
		parser.print_help(sys.stderr)
		exit(1)		

	if args.mass == None and args.add:
		#We don't have the mass, can we calculate it?
		if args.surface_accel == None:		#Nor we have the surface acceleration, maybe we are testing at a different altitude?
			if args.sample_point_altitude == None or args.sample_point_accel == None:	#We're out of options....
				sys.stderr.write("when preparing a profile, either enter the planet's mass(--mass), the surface acceleration due to gravity(--surface-accel)\nor the acceleration at a certain point(--sample-point-altitude and --sample-point-accel)\nto properly calculate its mass for the profile.\n\n")
				parser.print_help(sys.stderr)
				exit(1)	
	print args.add,args.read,args.planet,args.radius,args.mass,args.surface_accel,args.sample_point_altitude,args.sample_point_accel,args.sample_point_over_centre

	if args.add:
		cmd = 'add'
	fi args.read:
		cmd = 'read'

	if args.sample_point_over_centre:
		tp_alt = args.sample_point_over_centre + radius

	


cmd,name,radius,mass,surf_accel,tp_alt,tp_accel = read_parameters()