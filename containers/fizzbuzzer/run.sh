#!/bin/bash

INDEX=${POD_NAME##*-}  # grab the last index of the string split on `-`

# via https://www.rosettacode.org/wiki/FizzBuzz#bash
((( $INDEX % 15 == 0 )) && echo 'FizzBuzz') ||
((( $INDEX % 5 == 0 )) && echo 'Buzz') ||
((( $INDEX % 3 == 0 )) && echo 'Fizz') ||
echo "$INDEX";

trap : TERM INT; sleep 9999999 & wait
