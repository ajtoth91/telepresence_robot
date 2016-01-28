/* Motor
  This Arduino sketch called works in conjuction with my Processing sketch called Gamepad. 
  It reads five bytes to determine the motor speed and directions. This first byte is 
  the checkbyte chosen arbitrarily to indicate to the Arduino that the next two bytes are 
  motor bytes. The motor byte is split into two parts. The most significant bit tells the 
  Arduino which direction the H-Bridge should be. The next seven bits tell the Arduino what 
  the magnitude of speed (or the pulse width) should be. The next two bytes are for two Servo
  outputs. They should be mounted in a pan/tilt configuration. It takes four outputs to run two 
  motors. Two pins for the directions in which to control the H-Bridge and two pins to send 
  the PWM data to the left and right motors. Two pins control the two servos.
  
  This newest version contains a loss of signal function. This sketch has a timer which will 
  set the output of the motors to zero if there is no data present after about half a second.
  I chose one half second arbitrarily. The design for our robot has to work over a network
  connection. Hence, this will reduce the amount of traffic being sent serially between the 
  control and base stations. (since the majority of the time the robot is just idling) The 
  concept is similar to that of a watchdog timer. When there is no data, the motor controller
  starts a half second timer. As soon as data is recieved, the timer is reset. Should the timer 
  ever reach it's full one-half second, the motors will be set to zero and the the Loss of Signal
  LED will begin blinking. (It is solid otherwise) Since the Processing sends data at least
  once every 300 ms, you have about a 200 ms second window available. Of course, if any of the
  joystick inputs change, the data will be sent at full speed. Once again, the majority of the
  time our robot is just sitting. You can observe this action by watching the transmit light on
  your USB-to-Serial converter or X-Bee or whatever you have. When idle, it will return to it's
  state of blinking once every 300 ms
  
  The half second value is given by the variable called "timeout". The interrupt timer runs from
  the same frequency as the motors i.e. Timer2. Timer2 in this case, is set to a frequency of 
  about 30 Hz. Every interrupt adds one to the variable "counter". When the variable counter reaches
  the value of timeout the motor reset occurs. Since there are about 30 interrupts per second, the 
  variable timeout will need to be set to a value of 15 to give us one the half second value that
  we desire.
   
  The MegaServo library (playground.arduino.cc/Code/MegaServo) was chosen due to the target
  Arduino Mega, and the library uses Timer 5 for [the first 12] servo pulse timing, which
  will not interfere with the Timer2 discussed above. MegaServo has been integrated with Arduino
  since release 0017. Additional info on the Servo library can be found on the MegaServo library's
  page. **Depreciated MegaServo library in new release.
*/
#include <Servo.h>
//pins 5,6,9,11 are PWM pins
//Right: A3,B4,p5.
//Aft: A7, B8, p6
//Left: A2,B10, p9
//Front: A12, B13, p11 

const boolean DEBUG = false;
const boolean VERBOSE = false;

const int lAnalogOutPin = 9; //left
const int rAnalogOutPin = 5; //right
const int fAnalogOutPin = 11; //front
const int aAnalogOutPin = 6; //aft

const int lDirOutPinA = 2;
const int lDirOutPinB = 10;
const int rDirOutPinA = 3;
const int rDirOutPinB = 4;
const int fDirOutPinA = 12;
const int fDirOutPinB = 13;
const int aDirOutPinA = 7;
const int aDirOutPinB = 8;

const int panPin = 22; //top two pins on the right column
const int tiltPin = 23;


byte checkByte = 0;         // incoming serial byte
byte lMotorSpeed = 0;
byte rMotorSpeed = 0;
byte lMotorDir = 0;
byte rMotorDir = 0;
byte panPos = 0;
byte tiltPos= 0;

int ledPin = 24;
int counter = 0;
int timeout = 15; // about half a second
int second = 0;

Servo panServo;
Servo tiltServo;

const byte messageLength = 4;
char message[messageLength];

// In our experience, the motors accelerate much more
// smoothly with lower frequencies.
// Arduino runs at 16Mhz
// Phase correct PWM with prescale = 1024 
// 16000000 / 64 / 1024 / 255 / 2 = 30.637 Hz
// About 30 overflows per second
ISR(TIMER2_OVF_vect) 
{ 
  counter += 1;
  
  if (counter == timeout) {
    
    // If we don't recive any data after a few seconds set outputs to zero
    analogWrite(lAnalogOutPin, 0);
    analogWrite(rAnalogOutPin, 0);
    panServo.write(90);
    tiltServo.write(90);
    
    // for testing with the serial monitor
    if (DEBUG && VERBOSE) { 
      second++;
      Serial.println(second);
    }

    // toggle LED pin
    digitalWrite(ledPin, digitalRead(ledPin) ^ 1);
    
    // reset counter
    counter = 0;
  }
}  

void setup()
{
  // start serial port at 9600 bps:
  Serial.begin(9600);
  
  pinMode(rDirOutPinA, OUTPUT);
  pinMode(rDirOutPinB, OUTPUT);
  pinMode(lDirOutPinA, OUTPUT);
  pinMode(lDirOutPinB, OUTPUT);
  pinMode(fDirOutPinA, OUTPUT);
  pinMode(fDirOutPinB, OUTPUT);
  pinMode(aDirOutPinA, OUTPUT);
  pinMode(aDirOutPinB, OUTPUT);
  pinMode(ledPin, OUTPUT);
  
  panServo.attach(panPin);
  tiltServo.attach(tiltPin);

  // pins 3 and 11 use Timer2
  // Set Timer2 prescale 1024 for PWM frequency of about 30Hz
  // We will be using this same frequency for generating the 
  // loss of signal interrupt.
  TCCR2B |= (1<<CS22) | (1<<CS21) | (1<<CS20); // Set bits 
  
  analogWrite(lAnalogOutPin, 0);
  analogWrite(rAnalogOutPin, 0);
  analogWrite(fAnalogOutPin, 0);
  analogWrite(aAnalogOutPin, 0);
  
  panServo.write(90); //neutral position
  tiltServo.write(90);

//-------------Serial Handshake with Processing----------------
//  stay here until Processing sketch asks if we're connected
//  tell Processing we're connected
//  wait until processing says "Good to have you"
//  first wait for a @, then send a $, then receive a &. Send a % and begin.
  while (!Serial.available()) {} //wait indefinitely until there's a message on the serial line
  if (Serial.available() > 0) { //once something has appeared on the serial port
    char response = Serial.read();
    if ('@' == response) { 
      Serial.print('$');  //if we receive a @ character, send a $.
    } else { //We had an error receiving Processing's first @ character
      Serial.println("Error receiving handshake from Processing. Expected '@'. Received ");
      Serial.println(response);
      Serial.println("FATAL ERROR");
    }
  }
  delay(100); //wait 100ms for Processing to receive the handshake and send a response
  while (!Serial.available()) {} //possibly wait longer if nothing has appeared on the serial port
  if (Serial.available() > 0) {
    char response = Serial.read();
    if ('&' == response) {
      Serial.print('%');
    } else {
      Serial.print("Error receiving handshake from Processing. Expected '&'. Recieved '");
      Serial.print(response);
      Serial.println("'");
      Serial.println("FATAL ERROR");
    }
  }
//------------------------------------------------------------------- 
} //end setup()

void loop()
{  
  
  if(Serial.available()) {
    
  if (Serial.available() > messageLength) {
    
    // get incoming byte:
    checkByte = Serial.read();
   
    // the checkbyte is '#'
    if(checkByte == '#') 
    {
      
      // reset the counter back to zero
      // If there is a loss of signal, the interrupt
      // will take over and set the outputs to zero
      counter = 0;
      
      // This led will flash to indicate loss of signal
      // Otherwise it will stay high to indicate good signal
      digitalWrite(ledPin, HIGH);
 
      // This section is for debugging purposes only
      // It allows you to enter bytes using the Serial Monitor
      // and converts the decimal chars to a binary value. It expects 
      // a checkbyte '#' followed by two, three digit decimal 
      // values to be entered. The motor values are from 0-127.
      // So for example to make a PWM with 50% duty cycle on both
      // motors type this: "#064064
      
      if (DEBUG) {
        char dmsg[3*messageLength];
        Serial.println("checkByte OK!");
        Serial.readBytes(dmsg,3*messageLength);
        
        lMotorSpeed = (dmsg[0]-'0')*100;
        lMotorSpeed += (dmsg[1]-'0')*10;
        lMotorSpeed += (dmsg[2]-'0');
        
        Serial.print("L Value Read: ");
        Serial.print(lMotorSpeed);
        Serial.print("\t");
        Serial.println(lMotorSpeed, BIN);
        
        rMotorSpeed = (dmsg[3]-'0')*100;
        rMotorSpeed += (dmsg[4]-'0')*10;
        rMotorSpeed += (dmsg[5]-'0');
        
        Serial.print("R Value Read: ");
        Serial.print(rMotorSpeed);
        Serial.print("\t");
        Serial.println(rMotorSpeed, BIN);

        panPos = (dmsg[6]-'0')*100;
        panPos += (dmsg[7]-'0')*10;
        panPos += (dmsg[8]-'0');

        Serial.print("Pan Servo: ");
        Serial.println(panPos);

        tiltPos = (dmsg[9]-'0')*100;
        tiltPos += (dmsg[10]-'0')*10;
        tiltPos += (dmsg[11]-'0');
        
        Serial.print("Tilt Servo: ");
        Serial.println(tiltPos);
      } else {    //no DEBUG  
      
        //checkByte OK! Read the message.
        Serial.readBytes(message,messageLength);
        
        lMotorSpeed = message[0];
        rMotorSpeed = message[1]; 
        panPos = message[2];
        tiltPos= message[3];
      }

    
     
    
      lMotorDir = bitRead(lMotorSpeed, 7);
      rMotorDir = bitRead(rMotorSpeed, 7);
      
      //More debugging stuff
      if (DEBUG){    
        Serial.print("L Motor Dir: ");
        Serial.println(lMotorDir, BIN);
        Serial.print("R Motor Dir: ");
        Serial.println(rMotorDir, BIN);
      
        if(lMotorDir) {
          Serial.println("L Motor Dir: Backwards");
        }  
        else {
          Serial.println("L Motor Dir: Forwards");
        }
        
        if(rMotorDir) {
          Serial.println("R Motor Dir: Backwards");
        }  
        else {
          Serial.println("R Motor Dir: Forwards"); 
        }
      }
 
      digitalWrite(lDirOutPinA, lMotorDir);
      digitalWrite(rDirOutPinA, rMotorDir);
      digitalWrite(lDirOutPinB,!lMotorDir);
      digitalWrite(rDirOutPinB,!rMotorDir);

      
      lMotorSpeed &= 127;
      rMotorSpeed &= 127;
      
      // Still more debugging stuff
      if (DEBUG) {    
        Serial.print("L Motor Speed: ");
        Serial.println(lMotorSpeed, BIN);
        Serial.print("R Motor Speed: ");
        Serial.println(rMotorSpeed, BIN);
      }
 
      // PWM on the Arduino wants an 8 bit value so 
      // we will remap it.     
      lMotorSpeed = map(lMotorSpeed, 0, 127, 0, 255);
      rMotorSpeed = map(rMotorSpeed, 0, 127, 0, 255);
      
      analogWrite(lAnalogOutPin, lMotorSpeed);
      analogWrite(rAnalogOutPin, rMotorSpeed);
      
      //turn the servos to position
      panServo.write(panPos);
      tiltServo.write(tiltPos);
      
      Serial.print('!'); //received successfully
    }
  }
  }
  else // If there is no serial data
  {
    
    // Enable Timer2 Overlow Interrupt
    TIMSK2 |= (1<<TOIE2);
  }  
}



