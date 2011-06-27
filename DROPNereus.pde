// DROP Nereus - developed my James Coxon M6JCX (jacoxon@googlemail.com)
// Sleep code from http://www.arduino.cc/playground/Learning/arduinoSleepCode
// Lots of help from Phil Heron (fsphil)
// Adapted NewSoftSerial lib - increased rx buffer to 128 rather than 64 to allow for the long $PUBX responses 

//ATmega168/328
//              reset 1 ---- 28  analog 5
//      0         rx  2 |  | 27  analog 4
//      1         tx  3 |  | 26  analog 3
//      2 interrupt0  4 |  | 25  analog 2
//      3 interrupt1  5 |  | 24  analog 1
//      4        pwm  6 |  | 23  analog 0
//               vcc  7 |  | 22  gnd
//               gnd  8 |  | 21  nc
//           crystal  9 |  | 20  vcc
//           crystal 10 |  | 19         13
//      5        pwm 11 |  | 18         12
//      6        pwm 12 |  | 17  pwm    11
//      7            13 |  | 16  pwm    10
//      8            14 ---- 15  pwm    9

#include <TinyGPS.h>
#include <NewSoftSerial.h>
#include <avr/sleep.h>
#include <Wire.h>
#include <SPI.h>
#include <RTClib.h>
#include <RTC_DS3234.h>


int gpspower = 6;
int gsmpower = 5;
// Create an RTC instance, using the chip select pin it's connected to
RTC_DS3234 RTC(10);

DateTime now;

TinyGPS gps;
NewSoftSerial nss(7, 8);

int year, numbersats = -1, battV;
byte month, day, hour, minute, second, hundredths;
unsigned long fix_age;
long lat, lon, alt;
unsigned long speed, course;


//----------SETUP---------------//
void setup () {
  pinMode(gpspower, OUTPUT);
  pinMode(gsmpower, OUTPUT);
  digitalWrite(gsmpower, LOW);
  Serial.begin(9600);
  SPI.begin();
  
  //Start up the RTC
  RTC.begin();  
  
  //Set up alarms
  RTC.set_alarm(2, DateTime(2011,6,23,12,0,0), 0x06);
  
  RTC.setup(0,1);
  
  sendsms();
  }

//----------LOOP---------------//
void loop()
{
  now = RTC.now();
  
  //Check battery voltage
  battV = analogRead(5);
  
  //Check if we are charging via solar
  
  //If okay to procede power up GPS module
  
  digitalWrite(gpspower, HIGH);
  delay(5000);
  nss.begin(9600);
  setupGPS();
  readgps();
  nss.end();
  digitalWrite(gpspower, LOW);
  
  //Once lock has occured turn on GSM module
  
  sendsms();


  //Go to sleep after checking the time
  sleepNow();     // sleep function called here
  delay(1000);
}

//----------FUNCTIONS---------------//

void sendsms() {
  digitalWrite(gsmpower, HIGH);
  delay(3000);
  digitalWrite(gsmpower, LOW);
  //Send GPS and sensor data via SMS

  delay(20000);
  Serial.println("AT+CMGF=1\r\n");
  delay(1000);
  Serial.print("AT+CMGS=************\r\n");
  delay(1000);
 
  delay(1000);
  Serial.print("Nereus:");
  Serial.print(battV);
  Serial.print(",");
  Serial.print(lat);
  Serial.print(",");
  Serial.print(lon);
  Serial.print(",");
  Serial.print(alt);
  Serial.println("\r\n");
  delay(1000);
  Serial.print(0x1A,BYTE);
  delay(1000);
  
  //Check for commands
  
  //Power down GSM module
    
  digitalWrite(gsmpower, HIGH);
  delay(3000);
  digitalWrite(gsmpower, LOW);
}
void setupGPS() {
  //Turning off all GPS NMEA strings apart on the uBlox module
  nss.println("$PUBX,40,GLL,0,0,0,0*5C");
  nss.println("$PUBX,40,GGA,0,0,0,0*5A");
  nss.println("$PUBX,40,GSA,0,0,0,0*4E");
  nss.println("$PUBX,40,RMC,0,0,0,0*47");
  nss.println("$PUBX,40,GSV,0,0,0,0*59");
  nss.println("$PUBX,40,VTG,0,0,0,0*5E");
  
  delay(3000); // Wait for the GPS to process all the previous commands
}

void readgps()
{
    int gps_count = 0;
    while(gps_count < 5) {
      numbersats = -1;
      while(numbersats < 3) {
        nss.println("$PUBX,00*33"); //Poll GPS
        
        while (nss.available())
        {
          int c = nss.read();
          if (gps.encode(c))
          {
            //Get Data from GPS library
            //Get Time and split it
            gps.crack_datetime(&year, &month, &day, &hour, &minute, &second, &hundredths, &fix_age);
            
            
            numbersats = gps.sats();
    
          }
        }
        
        delay(5000);
      }
      
      //Sets the RTC with up to date GPS time
      RTC.adjust(DateTime(year,month,day,hour,minute,second));
      
      // retrieves +/- lat/long in 100000ths of a degree
      gps.get_position(&lat, &lon, &fix_age);
      // returns altitude
      alt = gps.altitude();
     // returns speed in 100ths of a knot
     speed = gps.speed(); 
     // course in 100ths of a degree
     course = gps.course();
     
     gps_count++;
  }
}

void wakeUpNow()        // here the interrupt is handled after wakeup
{  
  RTC.reset_alarm(); //Need to reset the alarm otherwise it'll keep triggering
}

void sleepNow()         // here we put the arduino to sleep
{
    /* The 5 different modes are:
     *     SLEEP_MODE_IDLE         -the least power savings 
     *     SLEEP_MODE_ADC
     *     SLEEP_MODE_PWR_SAVE
     *     SLEEP_MODE_STANDBY
     *     SLEEP_MODE_PWR_DOWN     -the most power savings
     * In all but the IDLE sleep modes only LOW can be used.
     */  
    set_sleep_mode(SLEEP_MODE_PWR_DOWN);   // sleep mode is set here

    sleep_enable();          // enables the sleep bit in the mcucr register
                             // so sleep is possible. just a safety pin 

    attachInterrupt(1,wakeUpNow, LOW); // use interrupt 0 (pin 2) and run function
                                       // wakeUpNow when pin 2 gets LOW 

    sleep_mode();            // here the device is actually put to sleep!!
                             // THE PROGRAM CONTINUES FROM HERE AFTER WAKING UP

    sleep_disable();         // first thing after waking from sleep:
                             // disable sleep...
    detachInterrupt(1);      // disables interrupt 0 on pin 2 so the 
                             // wakeUpNow code will not be executed 
                             // during normal running time.
}
