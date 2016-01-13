/* Motor
  This Arduino sketch is made to spin all the motors at max speed
  a single direction, for one second. Meanwhile, the servos are to
  move through their full range of motion.
*/
#include <Servo.h>

const int lAnalogOutPin = 3;
const int rAnalogOutPin = 11;
const int lDirOutPin = 12;
const int rDirOutPin = 13;
const int panPin = 22; //top two pins on the right column
const int tiltPin = 23;


byte checkByte = 0;         // incoming serial byte
byte lMotorSpeed = 0;
byte rMotorSpeed = 0;
byte lMotorDir = 0;
byte rMotorDir = 0;
byte panPos = 0;
byte tiltPos= 0;

int ledPin = 4;
int counter = 0;
int timeout = 15; // about half a second
int second = 0;

Servo panServo;
Servo tiltServo;

// In our experience, the motors accelerate much more
// smoothly with lower frequencies.
// Arduino runs at 16Mhz
// Phase correct PWM with prescale = 1024 
// 16000000 / 64 / 1024 / 255 / 2 = 30.637 Hz
// About 30 overflows per second


void setup()
{
  // start serial port at 9600 bps:
  Serial.begin(9600);
  
  pinMode(lDirOutPin, OUTPUT);
  pinMode(rDirOutPin, OUTPUT);
  pinMode(ledPin, OUTPUT);
  
  panServo.attach(panPin);
  tiltServo.attach(tiltPin);


  
  analogWrite(lAnalogOutPin, 0);
  analogWrite(rAnalogOutPin, 0);
  panServo.write(90); //neutral position
  tiltServo.write(90);
}

void loop()
{  
  for (int i=0; i<180; i++){
    panServo.write(i);
    tiltServo.write(i);
    Serial.println("Servo has updated");
    delay(15);
  }
}
