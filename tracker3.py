#Script written in python for the S60
# Written for the Nokia 6110 Navigator (with a slightly broken screen!)
# Aim is to have it turn on GPS, get a position, turn off the GPS and then send it by SMS

import sysinfo, positioning, e32, time, messaging


#Functions

def initialize_gps():
	'''This function initializes the GPS. The select_module(module_id) can be used to select the GPS module in this function. 
	In this case we are using the default GPS (integrated GPS) hence we do not need to select it.'''
	print "Intializing GPS"
	global gps_data
	global gpson
	#Intitialize the global dictionary with some initial dummy value (0.0 in this case)
	gps_data = {
	'satellites': {'horizontal_dop': 0.0, 'used_satellites': 0, 'vertical_dop': 0.0, 'time': 0.0,'satellites': 0, 'time_dop':0.0}, 
	'position': {'latitude': 0.0, 'altitude': 0.0, 'vertical_accuracy': 0.0, 'longitude': 0.0, 'horizontal_accuracy': 0.0}, 
	'course': {'speed': 0.0, 'heading': 0.0, 'heading_accuracy': 0.0, 'speed_accuracy': 0.0}
	}
	try:
		# Set requesters - it is mandatory to set at least one
		positioning.set_requestors([{"type":"service","format":"application","data":"gps_app"}])
		# Request for a fix every 0.5 seconds
		positioning.position(course=1,satellites=1,callback=cb_gps, interval=1000000,partial=0)
		# Sleep for 3 seconds for the intitial fix
		e32.ao_sleep(3)
		gpson = 1
	except:
		print "Problem with GPS"
		
def cb_gps(event):
	global gps_data
	gps_data = event
	
def cb(state): 
	if state==messaging.ESent: 
		print "**Message was sent**" 
	if state==messaging.ESendFailed: 
		print "**Something went wrong**" 

def stop_gps():
	global gpson
	'''Function to stop the GPS'''
	try:
		positioning.stop_position()
		gpson_off = 0
		print "GPS Stopped"
	except:
		print "Problem with GPS"


#Main Loop
global gpson
gpson = 0

print "Starting Tracker3 program"

while True:
	
	if (gpson == 0):
		#initialize GPS
		initialize_gps()
	
	sats = gps_data['satellites']['used_satellites'] 
	print sats
	
	if ( sats > 3):
		print gps_data['satellites']['used_satellites'], gps_data['position']['latitude'], gps_data['position']['longitude'], gps_data['course']['speed']
	
		#stop GPS
		stop_gps()
		#Get battery data
		battery = sysinfo.battery()
		#Get signal strength
		signal = sysinfo.signal_dbm()
	
		#Get time
		user_time = time.time()
	
		#Print data
		print user_time, battery, signal
		
		telem_string = "%d,%f,%f,%.2f,%d,%d" % (user_time, gps_data['position']['latitude'], gps_data['position']['longitude'], gps_data['course']['speed'], gps_data['course']['heading'], battery)
		
		print telem_string
		
		messaging.sms_send('+447748628528', telem_string,'8bit',cb)
		
		print "Sleeping"
		e32.ao_sleep(300)
	
	e32.ao_sleep(10)