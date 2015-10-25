# SLSF Random Generation

## Introduction

 - TODO

## Current Work

 - In a loop, we can generate random C code using csmith, then use a hard-
coded S-function to call the `main` function generated by csmith.

 - We build the code using mex and run a model which uses the s-function.

## Issues/TODO

 - Refactor to run the loop outside Matlab [later]
 - Try out different compilers and optimization flags to eventually check 
"Wrong Code" (as mentioned at csmith - when run time output of same source 
file is different changing compilers and optimization levels due to 
compiler bug). Will try to do have this feature in our script.
 - Figure out how to calculate "checksum" (this is how csmith checks "wrong
code") for our case. This requires careful consideration and I'll address
it later.

## How to run

 - Call `testrun` module from Matlab

### Building and installing csmith

 - Follow official doc at https://embed.cs.utah.edu/csmith/.
 - We have to ensure csmith executable and include directory is in path.

### Set up environment variables

In linux, we can set up this way:

    export CSMITH_PATH=/path/to/csmith
    export PATH=$PATH:/$CSMITH_PATH/src
    export C_INCLUDE_PATH=$CSMITH_PATH/runtime
    export CSMITH_HOME=$CSMITH_PATH # Needed for running csmith test driver

## Fixed Issues

 - Unsafe math operation at runtime: For some reason, I can not build the 
file `runtime/safe_math.h` with `mex` command. I've put a log in the logs 
folder. To get around this, I commented out line 100 of 
`csmith/runtime/random_inc.h`. So, run-time unsafe math operation (i.e. 
division by 0) leads to crash. Also "tuned" csmith to NOT include the safe
math operation wrappers (passing --no-safe-math argument). (FIXED)

- Handle aparantly non-terminating code (csmith uses timeout in their 
test suit). This is fixed, but killed processes are somehow leaking and 
processor usage is very high. Need to fix this. (FIXED)

