# Avular.GPIO Python library

The Avular.GPIO Python library, based on the [Jetson GPIO library](https://github.com/NVIDIA/jetson-gpio/tree/master), allows control of GPIO pins. This library has the same API as the popular RPi.GPIO library for Raspberry Pi.

This document covers what is in the Avular GPIO library package, how to configure the system and run sample applications, and the library API.

## Installation

The Avular GPIO library is pre-installed on the Vertex One Jetson module images, so no installation is necessary.

## Complete library API

The Avular GPIO library provides all public APIs provided by the RPi.GPIO
library. The following discusses the use of each API:

### 1. Importing the library

To import the Avular.GPIO module use:
```python
import Avular.GPIO as GPIO
```

This way, you can refer to the module as GPIO throughout the rest of the
application.

### 2. Pin numbering
While the standard Jetson GPIO library provides multiple ways of numbering I/O pins, the only sensible way to access GPIO pins on the Vertex One platform is to use the payload pin names.


To specify which mode you are using (mandatory), use the following function
call:
```python
GPIO.setmode(GPIO.CVM)
```

To check which mode has been set, you can call:
```python
mode = GPIO.getmode()
```

### 3. Warnings

If a GPIO you are trying to use is already being used outside the current application, 
the Avular GPIO library will warn you if the GPIO is configured to anything other than the default direction (input). 
It will also warn you if you try cleaning up before setting up the mode and channels. 
To disable warnings, call:

```python
GPIO.setwarnings(False)
```

Additionally, Avular.GPIO uses the **warnings** module to issue warnings. 
You can control the warning message using [Python Standard Library - warnings](https://docs.python.org/3/library/warnings.html#the-warnings-filter)

### 4. Set up a channel

The GPIO channel must be set up before use as input or output. To configure
the channel as input, call:
```python
# (where channel is based on the pin name as discussed above)
GPIO.setup(channel, GPIO.IN)
```

To set up a channel as output, call:
```python
GPIO.setup(channel, GPIO.OUT)
```

It is also possible to specify an initial value for the output channel:
```python
GPIO.setup(channel, GPIO.OUT, initial=GPIO.HIGH)
```

### 5. Input

To read the value of a channel, use:

```python
GPIO.input(channel)
```

This will return either GPIO.LOW or GPIO.HIGH.

### 6. Output

To set the value of a pin configured as output, use:

```python
GPIO.output(channel, state)
```

where state can be GPIO.LOW or GPIO.HIGH.

### 7. Clean up

At the end of the program, clean up the channels to reset all pins to their default state. To clean up all channels, call:

```python
GPIO.cleanup()
```

### 8. Jetson Board Information and library version

To get information about the Jetson module, use/read:

```python
GPIO.JETSON_INFO
```

This provides a Python dictionary with the following keys: P1_REVISION, RAM,
REVISION, TYPE, MANUFACTURER and PROCESSOR. All values in the dictionary are
strings with the exception of P1_REVISION which is an integer.

To get information about the library version, use/read:

```python
GPIO.VERSION
```

This provides a string with the X.Y.Z version format.

### 9. Interrupts

Aside from busy-polling, the library provides three additional ways of
monitoring an input event:

#### The wait_for_edge() function

This function blocks the calling thread until the specified edge is  
detected. The function can be called as follows:  

```python
GPIO.wait_for_edge(channel, GPIO.RISING)
```

The second parameter specifies the edge to detect and can be GPIO.RISING, GPIO.FALLING, or GPIO.BOTH. 
To limit the wait to a specified amount of time, optionally set a timeout:  

```python
# timeout is in seconds
GPIO.wait_for_edge(channel, GPIO.RISING, timeout=500)
```

The function returns the channel for which the edge was detected or None if a
timeout occurred.

#### The event_detected() function

This function periodically checks if an event occurred since the last call. 
The function can be set up and called as follows:

```python
# set rising edge detection on the channel
GPIO.add_event_detect(channel, GPIO.RISING)
run_other_code()
if GPIO.event_detected(channel):
    do_something()
```

As before, you can detect events for GPIO.RISING, GPIO.FALLING or GPIO.BOTH.

#### A callback function run when an edge is detected

This feature runs a separate thread for callback functions, 
allowing the callback to execute concurrently with your main program in response to an edge. 
This feature can be used as follows:

```python
# define callback function
def callback_fn(channel):
    print("Callback called from channel %s" % channel)

# add rising edge detection
GPIO.add_event_detect(channel, GPIO.RISING, callback=callback_fn)
```

You can also add multiple callbacks if required, as follows:

```python
def callback_one(channel):
    print("First Callback")

def callback_two(channel):
    print("Second Callback")

GPIO.add_event_detect(channel, GPIO.RISING)
GPIO.add_event_callback(channel, callback_one)
GPIO.add_event_callback(channel, callback_two)
```

The callbacks run sequentially, not concurrently, since only one thread runs all callback functions.

To prevent triggering the callback function multiple times, an optional debounce time can be set. 
This collapses multiple events into a single event.

```python
# bouncetime set in milliseconds
GPIO.add_event_detect(channel, GPIO.RISING, callback=callback_fn,
bouncetime=200)
```
The thread running in the background will be idle waiting for an event until
timeout, which can be optionally set as the following. The default polling
timeout is 0.2 sec. When the poll time times out, the thread will wake up and
check the thread status. If the thread is in the running state, it will go back
to the idle state waiting for another event, otherwise, the thread will exit
(event detection removal). This process will go on until the thread is in the
exit state.

```python
# polltime set in seconds
GPIO.add_event_detect(channel, GPIO.RISING, callback=callback_fn,
polltime=1)
```

If the edge detection is no longer required it can be removed as follows:

```python
GPIO.remove_event_detect(channel)
```

A timeout option can be set to wait for an event detection
to be removed, or else it is 0.5 seconds by default. It is
recommended that the timeout for removal should be at
least twice as much as the poll time.

```python
GPIO.remove_event_detect(channel, timeout=0.5)
```

### 10. Check function of GPIO channels

This feature allows you to check the function of the provided GPIO channel:

```python
GPIO.gpio_function(channel)
```

The function returns either GPIO.IN or GPIO.OUT.


## Using the Avular GPIO library from a docker container
The following describes how to use the Avular GPIO library from a docker container.

### Running the container
#### Basic options 
You should map `/dev` into the container to access to the GPIO pins.
So you need to add these options to `docker container run` command.

```shell
--device /dev/gpiochip0 \
```

and if you want to use GPU from the container you also need to add these options:
```shell
--runtime=nvidia --gpus all
```


#### Running the container in privileged mode
The library determines the jetson model by checking `/proc/device-tree/compatible` and `/proc/device-tree/chosen` by default.
These paths only can be mapped into the container in privileged mode.

The following example will run `/bin/bash` from the container in privileged mode. 
```shell
sudo docker container run -it --rm \
--runtime=nvidia --gpus all \
--privileged \
-v /proc/device-tree/compatible:/proc/device-tree/compatible \
-v /proc/device-tree/chosen:/proc/device-tree/chosen \
--device /dev/gpiochip0 \
testimg /bin/bash
```

#### Running the container in non-privileged mode
If you don't want to run the container in privileged mode, you can directly provide your jetson model name to the library through the environment variable `JETSON_MODEL_NAME`:  
 
```shell
# ex> -e JETSON_MODEL_NAME=JETSON_NANO
-e JETSON_MODEL_NAME=[PUT_YOUR_JETSON_MODEL_NAME_HERE]
``` 

The following model names are supported:

- VERTEX_1_3
- VERTEX_1_4 

The following example will run `/bin/bash` from the container in non-privileged mode. 

```shell
sudo docker container run -it --rm \
--runtime=nvidia --gpus all \
--device /dev/gpiochip0 \
-e JETSON_MODEL_NAME=[PUT_YOUR_JETSON_MODEL_NAME_HERE] \
testimg /bin/bash
```


## Creating a release
To create a new release of the Avular.GPIO library, follow these steps:

1. Update the version number in `setup.py`
2. Setup your name and email environment variables: `export EMAIL="<email>" NAME="<name>"`
3. Update the changelog in `debian/changelog` by using the `dch -v "<version>-<debian_revision>" "<msg>" -D jammy` command
4. Create a git commit with the changes made in the previous steps. i.e. `git add --all && git commit -m "chore: release <version>"`
5. Create a git tag for the new release. i.e. `git tag -a v<version> -m "<msg>"`
6. Push the changes and the tag to the remote repository. i.e. `git push && git push --tags`
