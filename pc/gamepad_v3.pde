/* Gamepad
   In my experience ReadMe files tend to become lost after passing the code around a lot
   so I put everything here. Sorry if the amount of comments offends you.
    
   This is a little sketch written by me, Matthew Spinks, for Mercury Robotics
   at Oklahoma State University. It takes values from the Xbox controller and 
   outputs to an Arduino or other device using the serial port. I've commented out
   the sections for serial communication for testing purposes. Don't forget to 
   uncomment them later. I would like to thank Christian Riekoff for making his
   wrapper class available and saving me the headache of mapping all the buttons on 
   the controller. If you want to use a different controller, I would suggest having 
   a look at the wrapper class available here: http://code.compartmental.net/dualanalog/
   
   This sketch is designed to be used with my Arduino motor sketch. It outputs five
   bytes: a header or start byte, a byte for the left motor, and a byte for the right
   motor. Two more bytes for the pan and tilt servos respectively have been added to the 
   end. The magnitude of the motor speed is determined by the lower seven bits of
   each motor byte going from 0 - 127. The Arduino will determine the motor direction 
   from the MSB of each motor byte. 0 is forward and 1 is backwards in this case. The 
   last two bytes will be between 0 and 255, for use in a Servo library function.
   
   Updates:
     The code now has Single Stick Mode. This mode computes the speeds for the
   motors using the magnitude and angle of the left joystick. You can switch modes by
   pressing the select button on the controller. It has a zero turn radius, meaning that
   pushing the joystick fully left will run the left motor backwards at full speed and 
   the right motor forwards at full speed. Moving only one motor while leaving the other
   stationary will require the joystick angle to be at 45 degrees. Experiment with it a
   little. I guarantee that, with a little practice, this will become your preferred 
   method of control.
   
   Even More Updates!
     Due to the nature of the single joystick control I've added even more features
   to the code. In testing, we've discovered that a majority of the time, the operater
   will be driving at low speeds. Because of the linear nature of the map function,
   it becomes hard to barely press forward on the joystick to maintain a low speed.
   I've add a modified the fscale function by Paul Badger to adjust the response 
   of the joystick logarithmically. For more info on fscale go here: 
   http://arduino.cc/playground/Main/Fscale The curve value is adjusted by using the
   left and right directions of the D-Pad. Negative numbers will give more weight to 
   the lower numbers on the scale and vice versa. By default I've left it -4.00. You 
   can adjust to whatever is most comfortable for you. A value of zero will make it 
   behave like the normal Arduino map function.
     
     Also, I added a max speed setting with indicators on the graphical sliders. You can
   modify this value by using the up and down directions of the D-Pad.
   
     Version 2.0 now has a loss of signal feature. As such it is only compatible with v2.0
   of the motor code. The sketch only transmits once every 300 milliseconds when idle. 
   This reduces the amount of traffic over the serial ports, since our design has to be
   controlled through an internet connection. The motor controller will the outputs to
   zero in about half a second if there is no signal. It works in a manner similar to 
   a watchdog timer. IT WILL NOT RESET IF THE CONTROLLER IS UNPLUGGED! We're still
   working on this part.
   
   If you haven't figured this out already, don't forget to add the ProControll library 
   to your Processing folder. Try making a folder called "libraries" and putting in
   Processing folder. (It should be in your Documents) Then add the ProControll folder
   within that one. For more info on ProControll and useful examples go here:
   http://creativecomputing.cc/p5libs/procontroll/

   Yet more Updates (A. Toth)
   Add to the single-joystick mode: Not-so-single joystick. Left joystick uses a left/right
   motor pair. Right joystick is for two servos mounted in a pan/tilt configuration, for 
   a webcam. Defaults starting in single-joystick mode. Build with Processing 2.2.1
  *Now requires a handshake with the Arduino. First, send a '@', wait until you receive '$'. Send a '&' as a response, then wait until a '%'. 
  
   Controls: 
   
     Select       - switch between modes
     L/R Bumpers  - brake in skid steer mode only
     A            - brake in single stick mode only
     Y            - Display debugging info
     Right stick  - Center view (in relative mode only)
   
   As with all good Arduino/Processing sketches this code should be freely shared. But
   please, if you do decide to use all or some of it, at least give me a little credit.
   Or if you want, feel free to bake a cake and send it to me. I like red velvet.
   Here is my youtube account name if you feel like stalking me:
   mspinksosu
   mspinksosu@gmail.com
   
   created 2011-2012 by Matthew Spinks
   based on examples by Christian Riekoff
   Updated upon by Andrew Toth

*/
import processing.serial.*;
import procontroll.*;
import net.java.games.input.*;

Serial myPort;
PFont f, b;
char HEADER ='#';

ControllIO controll;
ControllDevice gamepad;
ControllStick leftStick;
ControllStick rightStick;
ControllCoolieHat DPad;
ControllSlider XBOXTrig;
ControllSlider RTrig;

float leftTriggerMultiplier, leftTriggerTolerance, leftTriggerTotalValue;
float rightTriggerMultiplier, rightTriggerTolerance, rightTriggerTotalValue;

float leftX = 0;
float leftY = 0;
float rightY = 0;
float rightX = 0;
byte lOutput = 0;
byte rOutput = 0;
byte lDir = 0;
byte rDir = 0;
byte panOutput = 90;
byte tiltOutput = 90;

// Used for timing since Processing has no real timers.
int previousMillis = 0;
int interval = 300; // 300 milliseconds

// Save previous states. If there is no change from the input
// just use the previous values.
float lPrevious;
float rPrevious;
byte panPrevious;
byte tiltPrevious;

float angle;
float magnitude;
float output;
float tolerance = 0.17;  // set tolerance value for joysticks
float maxSpeed = 127;

int mode = 1; //single stick default
boolean selectSet = false; // for reading the state of the select button
boolean startSet = false; // for reading the state of the start button
boolean ySet = false;
boolean xSet = false;
boolean DEBUG = true;
boolean LISTEN = false; //verbose listening to Arduino DEBUG

// This is used for the fscale function to adjust the joystick feel and
// give a more logarithmic response rather than a linear one. This should
// make it easier for the operator to control the robot at low speeds
// because they won't have to concentrate on barely moving the joystick.
// Acceptable values are between -10 and 10. Negative numbers are what we
// want in this case, since we want the lower speed range to be distributed
// more across the lower end of the joystick. (near the center of the stick)
// A value of zero makes it behave like the normal map function
float curveValue = -4;

ControllButton A;
ControllButton B;
ControllButton Y; 
ControllButton X;
ControllButton L1; //left bumper
ControllButton L2;
ControllButton L3; //left stick button
ControllButton R1; //right bumper
ControllButton R2;
ControllButton R3; //Right stick button
ControllButton Select;
ControllButton Start; 
ControllButton XBOX;
ControllButton Up;
ControllButton Down;
ControllButton Left;
ControllButton Right;
//DPad right is x=-1, left is x=+1
//DPad down is y=-1, up is y=+1
//DPad diagonals exist as float +/- 0.70710677 to increments of 0, 30, 45, 60, 90 degrees.
float coolie = 0;
static boolean ARDUINO = true;

void setup(){
  size(400,400);
  f = loadFont("ArialMT-48.vlw");
  b = loadFont("Arial-BoldMT-48.vlw");
  
  // The microcontroller will connect on the first port listed
  // with a baud rate of 9600
  // Don't forget to change the static boolean ARDUINO = TRUE once you're ready to start
  // using the microcontroller
  println("Begin Serial list");
  println(Serial.list());
  println("end Serial list");
  if (ARDUINO){
    myPort = new Serial(this, Serial.list()[0], 9600);
  }
  
  controll = ControllIO.getInstance(this);
  controll.printDevices(); //debug
  gamepad = controll.getDevice("Microsoft X-Box 360 pad");
  
  gamepad.printSliders();
  gamepad.printButtons();
    
  // This is the section of the wrapper class I used
  leftStick = new ControllStick(gamepad.getSlider(0), gamepad.getSlider(1));
  rightStick = new ControllStick(gamepad.getSlider(3), gamepad.getSlider(4));
  
  XBOXTrig = gamepad.getSlider(2);
  RTrig = gamepad.getSlider(5);
  leftTriggerTolerance = rightTriggerTolerance = XBOXTrig.getTolerance();
  leftTriggerMultiplier = rightTriggerMultiplier = XBOXTrig.getMultiplier();
  
  RTrig = gamepad.getSlider(5);
  
    
  Y = gamepad.getButton(4);
  B = gamepad.getButton(2);
  A = gamepad.getButton(1);
  X = gamepad.getButton(3);
  R1 = gamepad.getButton(6);
  R3 = gamepad.getButton(10);
  L1 = gamepad.getButton(5);
  L3 = gamepad.getButton(9);
  DPad = gamepad.getCoolieHat(11); //changed 10 to 11
  DPad.setMultiplier(-1);
  Select = gamepad.getButton(0);
  Start = gamepad.getButton(7); 
  XBOX = gamepad.getButton(8);

 //-------------------handshake with the Arduino, now that the controller is connected.
//First, send a '@', wait until you receive '$'. Send a '&' as a response, then wait until a '%'. 
 
 if (ARDUINO){
   println("Writing '@' to Arduino.");
   myPort.write('@');
   if (DEBUG) { println("Sent '@' to Arduino. Waiting for response..."); }
   //wait for response from the Arduino. Expect '$'
//   while (myPort.available() <=0) { print(". "); } //just wait until we get a response
delay(500);
   if (DEBUG) { println(myPort.available());}
   if (DEBUG) { println("Received response from Arduino. Let's check it out."); }
   if (myPort.available() > 0) {
     char response = char(myPort.read());
     if (DEBUG) { println("Read from Arduino"); }
     if ('$' == response) {
        //we have the proper handshake, let's continue.
        if (DEBUG) { println("We have properly received '$'. Now to send '&'"); }
        myPort.write('&');
        if (DEBUG) { println("Sent '&'. Awaiting response...");}
          while (myPort.available() <= 0) {} //wait for another response
          if (myPort.available() > 0) { //we got a response!
            if (DEBUG) { println("Got our second response from the Arduino. Let's see what it is.");}
            response = char(myPort.read());
            if ('%' == response) {
              if (DEBUG) { println("Handshake successful"); }
            } else {
              if (DEBUG) { println("Handshake failed. Expecting '%'. Received '" + response + "'");}
              exit();
            }               
          }//end second response
      } else { //our first response failed
            if (DEBUG){ println("Handshake failed. Expecting '$'. Received '" + response + "'"); }
            exit();
      }  
    } //end myport.available >0
  }//end handshake (if ARDUINO) block
}

void draw(){
  background(255);
  
  // Start timing. Normally this would be an unsigned long, but
  // Processing cannot use usigned long values. Eventually the
  // timer will roll over, but not for a few days if the program
  // is left running. So in normal cases, this won't be a problem.
  int currentMillis = millis();
  
  // set the coordinates for the left and right stick objects
  int leftLine = width*5/16, rightLine = width*11/16;

  // change mode if Select button is pressed
  // changes on button release (sort of like debouncing)
  if(Select.pressed())
    selectSet = true;
 
  if(ARDUINO) {
    sendPackage(lPrevious, rPrevious, 0xFF, 0xFF);
    Serial.println("Changed Mode. Sent the package 0x'#' xx xx FF FF");
   
  }
 
  if(selectSet && !Select.pressed()){
    mode++;
  
    if(mode > 1)
      mode = 0;
      
    selectSet = false;
  }
  
  if(Y.pressed())
    ySet = true;
  
  if(ySet && !Y.pressed()){
    DEBUG = (!DEBUG);
    
    ySet = false;
  }
  
  // Adjust the max and curve values using the DPad
  curveValue += DPad.getX() * 0.05;
  
  if(curveValue > 10)
    curveValue = 10;
  else if(curveValue < -10)
    curveValue = -10;
    
  maxSpeed += int(DPad.getY());
  
  if(maxSpeed > 127)
    maxSpeed = 127;
  else if(maxSpeed < 32)
    maxSpeed = 32;
//-----------------------------------------------------------------------------
  if (ARDUINO && DEBUG && LISTEN) {
    print("now the Arduino has a chance to speak");
    while (myPort.available() > 0){
      print(myPort.read());
    }
    println();
  }
 
//-------------------------------------------------------------------------------

// begin computing and map values for joysticks
// .get() and map() both need float values
  
  // if you want to use X-axis declare them here.
  leftX = leftStick.getX();
  leftY = leftStick.getY();
  rightY = rightStick.getY();
  rightX = rightStick.getX(); //these are floats between -1.0 and +1.0
 
  // trig functions use RADIANS by default
  angle = atan2(leftY, leftX);
  magnitude = sqrt(pow(leftX,2) + pow(leftY,2));
  output = cos(2 * angle);
  
  // remap the magnitude eliminating any slack in the joystick
  magnitude = map(magnitude, sqrt(2 * pow(tolerance,2)), 1, 0, 1 );
  
  // joystick is not a perfect circle, therefore ignore anything
  // greater than 1.0 or less than zero
  if(magnitude > 1.0)
    magnitude = 1.0; 

  if(magnitude < 0)
    magnitude = 0;

  if(DEBUG == true) {
    textFont(f,16);
    text("leftX: " + leftX, 200, 15);
    text("leftY: " + leftY, 200, 35);
    text("rightX: " + rightX, 200, 55);
    text("rightY: " + rightY, 200, 75);
    //include ternary because Processing uses signed Byte. 
    //These calculations turn it into an int, so it displays correctly
    text("panOutput: " + (panOutput < 0 ? panOutput+256 : panOutput), 200, 95);
    text("tiltOutput: " + (tiltOutput < 0 ? tiltOutput+256 : tiltOutput), 200, 105);
  }
  
//-------------------- Single Joystick Mode ---------------------------------------
  
  // for mode 1 we will use the direction of the right stick to directly correlate
  // with where the camera is pointing
  // mode 0 will be more like FPS-style controls, R3 (stick button) will center the view.
  if(mode == 1) 
  {
    //-----------------Pan/Tilt Camera Right Stick functionality---------
    //map from -1 to +1 on joystick to 0 to 180 for Servo library calls
    panOutput = byte(map(rightX, -1,1,180,0)); 
    tiltOutput = byte(map(rightY,-1,1,0,180));
  } //end Mode 1
  else if (mode == 0) {
    //Right stick position indicates how fast we want to move
    panOutput = byte(fscale(rightX, -1,1,180,0,curveValue)); 
    tiltOutput = byte(fscale(rightY,-1,1,0,180,curveValue)); 

    if (R3.pressed()) { //center the view
      panOutput  = 90;
      tiltOutput = 90;
    }
  }

  if(angle < 0 && angle > -PI/2) // Quadrant I 
  {
    leftY = -1 * magnitude;
    rightY = output * magnitude; 
  }
  else if(angle < -PI/2 && angle > -PI) // Quadrant II
  {
    rightY = -1 * magnitude;
    leftY = output * magnitude;
  }  
  else if(angle < PI && angle > PI/2) // Quadrant III
  {
    leftY = magnitude;
    rightY = -1 * output * magnitude;
  }
  else if(angle < PI/2 && angle > 0) // Quadrant IV
  {
    rightY = magnitude;
    leftY = -1* output * magnitude;
  }
  
  // set output to zero if A is pressed of magnitude is zero
  if(A.pressed() || magnitude == 0) {
    leftY = 0;
    rightY = 0;
  }

    
  
  
  if (DEBUG) {
    if(Y.pressed()) {  println("Y pressed"); }
    if(B.pressed()) {  println("B pressed"); }
    if(A.pressed()) {  println("A pressed"); }
    if(X.pressed()) {  println("X pressed"); }
    if(R1.pressed()) { println("R1 pressed"); }
    if(L1.pressed()) { println("L1 pressed"); }
    if(R3.pressed()) { println("R3 pressed"); }
    if(L3.pressed()) { println("L3 pressed"); }
    if(Start.pressed()) { println("Start pressed"); }
    if(Select.pressed()){ println("Select pressed"); }
    if(DPad.pressed()){
      println("DPad X: " + DPad.getX());
      println("DPad Y: " + DPad.getY());
    }
  } //end controller keypress debug block


  // remap left and right Y axis
  // invert if negative so that the magnitude always goes from 0-127
  // leftY is remapped from -128 to 127. This purely for cosmetic reasons
  // Mapping the output the way I had previously done it left a little 
  // flicker or shutter when switching between positive and negative values
  if(leftY < -tolerance) {
    lOutput = byte(fscale(leftY, -tolerance, -1, 0, maxSpeed, curveValue));
    //leftY = byte(map(leftY, -1, -tolerance, 127, 0));
    leftY = lOutput;
    
  }  
  else if(leftY > tolerance) {
    lOutput = byte(fscale(leftY, tolerance, 1, 129, 128+maxSpeed, curveValue));
    leftY = byte(fscale(leftY, tolerance, 1, 0, -maxSpeed-1, curveValue));
  }  
  else {
    lOutput = 0;
    leftY = 0;
  }
  
  if(rightY < -tolerance) {
    rOutput = byte(fscale(rightY, -tolerance, -1, 0, maxSpeed, curveValue));
    //rightY =  byte(fscale(rightY, -tolerance, -1, 0, 127, curveValue));
    rightY = rOutput;
  }  
  else if(rightY > tolerance) {
    rOutput = byte(fscale(rightY, tolerance, 1, 129, 128+maxSpeed, curveValue));
    rightY =  byte(fscale(rightY, tolerance, 1, 0, -maxSpeed-1, curveValue));
  }  
  else {
    rOutput = 0;  
    rightY = 0; 
  }
  
//---------------------------------------------------------------------------------
  
  // If the input doesn't change, output will only be sent once every 300 milliseconds or the
  // time specified by "interval". This reduces the amount of traffic over the TX/RX pins.
  // The arduino is configured to set the motor speeds to zero after about half a second if 
  // there is no serial input. This acts sort of like a watch dog timer, with Processing 
  // resetting the Arduino's timer before it can declare a loss of signal.  
  if(lOutput != lPrevious || rOutput != rPrevious || currentMillis - previousMillis > interval || panOutput != panPrevious || tiltOutput != tiltPrevious)
  {
    // reset timer
    previousMillis = currentMillis;
  
    sendPackage(lOutput, rOutput, panOutput, tiltOutput);
    
    // Update new values
    lPrevious = lOutput;
    rPrevious = rOutput;
    panPrevious = panOutput;
    tiltPrevious = tiltOutput;
  }
  
//-------------------- Draw Stuff Here --------------------------------------------
  
  rectMode(CENTER);

  stroke(0);
  fill(154, 154, 154); // light grey
  
  // draw sliders
  rect(leftLine, height/2, 20, 256);
  rect(rightLine, height/2, 20, 256); 
  
  // draw center lines
  line(leftLine - 40, height/2, leftLine + 40, height/2);
  line(rightLine - 40, height/2, rightLine + 40, height/2);
  
  // draw maxSpeed stops
  line(leftLine-20, height/2-maxSpeed-1, leftLine+20, height/2-maxSpeed-1);
  line(leftLine -20, height/2+maxSpeed+1, leftLine+20, height/2+maxSpeed+1);
  line(rightLine-20, height/2-maxSpeed-1, rightLine+20, height/2-maxSpeed-1);
  line(rightLine -20, height/2+maxSpeed+1, rightLine+20, height/2+maxSpeed+1);
  
  // draw rectangles for sticks
  if((mode == 0 && L1.pressed()) || (mode == 1 && A.pressed())) {
    fill(255,0,0); // red
    rect(leftLine, height/2 - leftY, 40, 20);
  }
  else {
    fill(0);
    rect(leftLine, height/2 - leftY, 40, 20);
  }

  if((mode == 0 && R1.pressed()) || (mode == 1 && A.pressed())) {
    fill(255,0,0); // red
    rect(rightLine, height/2 - rightY, 40, 20);
  }
  else {
    fill(0);
    rect(rightLine, height/2 - rightY, 40, 20);
  }

  //draw a dot for the right stick
  line(width/2-20, height/2, width/2 +20, height/2);
  arc(width/2, height/2, 40, 40, PI, -PI);
  line(width/2, height/2-20, width/2, height/2+20);
  ellipse(width/4 + (panOutput < 0 ? panOutput+256 : panOutput), height/4 + (tiltOutput < 0 ? tiltOutput+256 : tiltOutput),10,10); //Draw dot based on Servo Output
  //ellipse(width/2, height/2, 40,40);
  
  textFont(f,16);               
  fill(0);
  
  textAlign(RIGHT, CENTER);
  text(int(leftY), leftLine - 50, height/2);
  textAlign(LEFT, CENTER);
  text(int(rightY), rightLine + 50, height/2);
  
  textAlign(CENTER, BASELINE);
  textFont(f,14);
  text("Output: " + binary(lOutput,8),leftLine, height/2 - 150);
  text("Output: " + binary(rOutput,8),rightLine, height/2 - 150);
 
  textAlign(CENTER, TOP);
  textFont(f,18);
  text("L", leftLine, height/2 + 140);
  text("R", rightLine, height/2 + 140); 
  
  textAlign(CENTER, BASELINE);
  textFont(f,14);
  text("Pan: " + binary(panOutput,8),width/2, height/2 - 30);
  text("Tilt: " + binary(tiltOutput,8),width/2, height/2 + 30);
  
  if(DEBUG == false)
  {
  textAlign(CENTER, BASELINE);
  textFont(b,14);
  if(mode == 0)
    text("Skid Steer", width/2, 20);
  else if (mode == 1)
    text("Single Stick Mode", width/2, 20);
    
  textAlign(LEFT);
  text("curve: " + nf(curveValue,0,2), width - 100, 20);
  }
  
  textAlign(LEFT);
  textFont(b,14);
  text("mode: " + mode, 20, 20);
  
  // display extra info
  if(DEBUG == true) {
    textAlign(LEFT, BASELINE);
    textFont(f,14);
    text("Angle: " + degrees(angle), 20, height/2 + 170);
    text("Magnitude: " + magnitude, 200, height/2 + 170);
    text("Output: " + output, 20, height/2 + 190);
    text("MaxSpeed: " + nf(maxSpeed,0,2), 200, height/2 + 190);
  }
   
}

//-------------------- End Main ----------------------------------------------------

void sendPackage(byte leftMotor, byte rightMotor, byte panMotor, byte tiltMotor) 
{
    if (ARDUINO) {
      myPort.write(HEADER);
      myPort.write(leftMotor);
      myPort.write(rightMotor);  
      myPort.write(panMotor);
      myPort.write(tiltMotor);
    }
    if (DEBUG) { //now we can debug package independently from attached Arduino
      println("Package sent:\t" + HEADER + "\t"+leftMotor +"\t"+ rightMotor +"\t"+ int(panMotor) +"\t"+ int(tiltMotor));
      println(hex(HEADER,2) + " " + hex(leftMotor,2) + " " + hex(rightMotor,2) + " " + hex(panMotor,2) + " " + hex(tiltMotor,2));
   }
}

/* fscale
 Floating Point Autoscale Function V0.1
 Paul Badger 2007
 Modified from code by Greg Shakar
 Modified slightly by Matthew Spinks 2012
 
 The original is here: http://arduino.cc/playground/Main/Fscale
 
 This replaced the map function with one that includes logarithmic scaling.
 I modified it a little so I could call it like the regular map function
 I stripped it down and removed input checking because, in order for my
 joystick to work properly, I needed the originalMin to be greater than 
 the originalMax. This way it would use the same function even if the joystick
 was inverted. As a consequence I had to reverse my call function from what it
 originally was. Also, "curve" is keyword in Processing. The curve value should
 be between -10 and 10. In this case we are using negative numbers to give 
 more weight to the numbers at the low end of the joystick. This will make the 
 joystick travel a longer distance for low speeds.
*/
float fscale( float inputValue, float originalMin, float originalMax, float newBegin, float
newEnd, float curveValue){

  float OriginalRange = 0;
  float NewRange = 0;
  float zeroRefCurVal = 0;
  float normalizedCurVal = 0;
  float rangedValue = 0;
  boolean invFlag = false;

  // condition curve parameter
  // limit range
  if (curveValue > 10) curveValue = 10;
  if (curveValue < -10) curveValue = -10;

  // invert and scale - this seems more intuitive
  // postive numbers give more weight to high end on output
  curveValue = (curveValue * -.1) ;  
  curveValue = pow(10, curveValue); // convert linear scale into lograthimic exponent for other pow function

  /*
   Serial.println(curve * 100, DEC);   // multiply by 100 to preserve resolution  
   Serial.println(); 
   */
   
  // Check for out of range inputValues
  //if (inputValue < originalMin) {
  //  inputValue = originalMin;
  //}
  //if (inputValue > originalMax) {
  //  inputValue = originalMax;
  //}

  // Zero Reference the values
  OriginalRange = originalMax - originalMin;

  if (newEnd > newBegin){ 
    NewRange = newEnd - newBegin;
  }
  else
  {
    NewRange = newBegin - newEnd; 
    invFlag = true;
  }

  zeroRefCurVal = inputValue - originalMin;
  normalizedCurVal  =  zeroRefCurVal / OriginalRange;   // normalize to 0 - 1 float

  /*
  Serial.print(OriginalRange, DEC);  
   Serial.print("   ");  
   Serial.print(NewRange, DEC);  
   Serial.print("   ");  
   Serial.println(zeroRefCurVal, DEC);  
   Serial.println();  
   */

  // Check for originalMin > originalMax  - the math for all other cases i.e. negative numbers seems to work out fine 
  //if (originalMin > originalMax ) {
  //  return 0;
  //}

  if (invFlag == false){
    rangedValue =  (pow(normalizedCurVal, curveValue) * NewRange) + newBegin;

  }
  else     // invert the ranges
  {
    rangedValue =  newBegin - (pow(normalizedCurVal, curveValue) * NewRange); 
  }

  return rangedValue;
}


