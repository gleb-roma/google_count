Requirements:
	perl
	mySQL
	openvpn
	HMA files in ../hma

To start the scraping, say

sudo ./brun.sh

or alike. To get data in text format of the form Country\tName_id\t1..52, use 

./make_panel.pl -l ru >output_file

(requires in-text editing). 

File request.conf should contain configuration variables. NO_PROXY_FREQ equals zero if you do not want to use proxy servers.

The lists with people names are taken from ./lists/


