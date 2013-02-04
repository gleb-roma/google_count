#!/bin/bash
bt=pe    # Bing (from Imil)

if [ ! -e b.0 ]; then
	echo "Starting from b.0"
	./gblogs.pl -l$bt -zc <lists/$bt-top-exclude-keywords
	if [ $? -ne 0 ]; then echo "Error in the script"; exit; fi
	echo 'Press Ctrl+C within 5 secs to stop the bash script'
	sleep 5
	touch b.0; chown gleb b.0
fi
if [ ! -e b.1 ]; then
	echo "Starting from b.1"
	cat lists/$bt-top-include-keywords | ./gblogs.pl -l$bt -z
	if [ $? -ne 0 ]; then echo "Error in the script"; exit; fi
	echo 'Press Ctrl+C within 5 secs to stop the bash script'
	sleep 5
	touch b.1; chown gleb b.1
fi
if [ ! -e b.2 ]; then
	echo "Starting from b.2"
	./gblogs.pl -l$bt -z <lists/$bt-top-general
	if [ $? -ne 0 ]; then echo "Error in the script"; exit; fi
	echo 'Press Ctrl+C within 5 secs to stop the bash script'
	sleep 5
	touch b.2; chown gleb b.2
fi
echo "THE END"

