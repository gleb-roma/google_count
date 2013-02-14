#!/bin/bash

bt=us    # Bing (from Imil)

if [ ! -e n.0 ]; then
	echo "Starting from n.0"
	./gnews.pl -l$bt -zc <lists/$bt-top-exclude-keywords
	if [ $? -ne 0 ]; then echo "Error in the script"; exit; fi
	echo 'Press Ctrl+C within 5 secs to stop the bash script'
	sleep 5
	touch n.0; chown gleb n.0
fi
if [ ! -e n.1 ]; then
	echo "Starting from n.1"
	cat lists/$bt-top-include-keywords | ./gnews.pl -l$bt -zc
	if [ $? -ne 0 ]; then echo "Error in the script"; exit; fi
	echo 'Press Ctrl+C within 5 secs to stop the bash script'
	sleep 5
	touch n.1; chown gleb n.1
fi
if [ ! -e n.2 ]; then
	echo "Starting from n.2"
	./gblogs.pl -l$bt -zc <lists/$bt-top-general
	if [ $? -ne 0 ]; then echo "Error in the script"; exit; fi
	echo 'Press Ctrl+C within 5 secs to stop the bash script'
	sleep 5
	touch n.2; chown gleb n.2
fi
echo "THE END"

rm n.*
bt=gb    # Bing (from Imil)

if [ ! -e n.0 ]; then
	echo "Starting from n.0"
	./gnews.pl -l$bt -zc <lists/$bt-top-exclude-keywords
	if [ $? -ne 0 ]; then echo "Error in the script"; exit; fi
	echo 'Press Ctrl+C within 5 secs to stop the bash script'
	sleep 5
	touch n.0; chown gleb n.0
fi
if [ ! -e n.1 ]; then
	echo "Starting from n.1"
	cat lists/$bt-top-include-keywords | ./gnews.pl -l$bt -zc
	if [ $? -ne 0 ]; then echo "Error in the script"; exit; fi
	echo 'Press Ctrl+C within 5 secs to stop the bash script'
	sleep 5
	touch n.1; chown gleb n.1
fi
if [ ! -e n.2 ]; then
	echo "Starting from n.2"
	./gblogs.pl -l$bt -zc <lists/$bt-top-general
	if [ $? -ne 0 ]; then echo "Error in the script"; exit; fi
	echo 'Press Ctrl+C within 5 secs to stop the bash script'
	sleep 5
	touch n.2; chown gleb n.2
fi
echo "THE END"
