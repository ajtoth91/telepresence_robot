/* Motor
  This Arduino sketch is made to spin all the motors at max speed
  a single direction, for one second. Meanwhile, the servos are to
  move through their full range of motion.
*/
#include <Servo.h>
//pins 5,6,9,11 are PWM pins
//Motor 1: A3,B4,p5.
//Motor 2: A7, B8, p6
//Motor 3: A2,B10, p9
//Motor 4: A12, B13, p11 //none of these pins have been applied.

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
 while(Serial.available()<1){} //wait until Serial Console
  /*for (int i=0; i<180; i++){
    panServo.write(i);
    tiltServo.write(i);
    Serial.println("Servo has updated");
    delay(15);
  }*/
  
  Serial.println("Moving Motor1");
  int fwd = LOW;
  digitalWrite(3, fwd); //A
  digitalWrite(4, !fwd);  //B
  analogWrite(5, 255);
  delay(500); //let it go for half a second.
  analogWrite(5,0);
  Serial.println("Stopped Motor1");
delay(2000);
  Serial.println("Moving Motor 2");
  digitalWrite(7, fwd); //A
  digitalWrite(8, !fwd);  //B
  analogWrite(6, 255);
  delay(500); //let it go for half a second.
  analogWrite(6,0);
  Serial.println("Stopped Motor2");
delay(2000);
  Serial.println("Moving Motor3");
  digitalWrite(2, fwd); //A
  digitalWrite(10, !fwd);  //B
  analogWrite(9, 255);
  delay(500); //let it go for half a second.
  analogWrite(9,0);
  Serial.println("Stopped Motor3");
delay(2000);
  Serial.println("Moving Motor4");
  digitalWrite(12, fwd); //A
  digitalWrite(13, !fwd);  //B
  analogWrite(11, 255);
  delay(500); //let it go for half a second.
  analogWrite(11,0);
  Serial.println("Stopped Motor4");
delay(2000);
}

/*FINDINGS
Motor 1 is right side.
Motor 2 is aft
Motor 3 is left
Motor 4 is front */
