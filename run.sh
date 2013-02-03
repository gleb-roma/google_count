#!/bin/bash

bt=de
gt=de

rm n.0 n.1 n.2 n.3
touch n.0
./gnews.pl -l$gt -zr <lists/$bt-top-exclude-keywords
echo 'Press Ctrl+C within 5 secs to stop the bash script'
sleep 5
touch n.1
echo "n.1 created"
cat lists/$bt-top-include-keywords | ./gnews.pl -l$gt -zr
echo 'Press Ctrl+C within 5 secs to stop the bash script'
sleep 5
touch n.2
echo "n.2 created"
cat lists/$bt-top-general          | ./gnews.pl -l$gt -zr
touch n.3
echo "n.3 created"


