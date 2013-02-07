package mediaSubs;
use strict;
use vars qw(@ISA @EXPORT);
use Exporter;
#use LWP::UserAgent;
use Data::Dumper;
use WWW::Mechanize;
use Encode;
use DBD::mysql;
use DBI;
use feature 'say';
use Term::ANSIColor;
use Term::ANSIColor qw(:constants);
use POSIX qw/mktime ceil/;
use Fcntl qw(:flock :DEFAULT);
use Switch;
use Config::General;
#use File::Temp qw/ tempfile tempdir /;
@ISA = qw(Exporter);
@EXPORT = qw(fetchUrl retrieve_all fetchUrl_mech fetchUrl_mech_1 retrieve_all_mech next_proxy is_under_proxy exists_person connect_to_DB close_proxies %tags);

########### CONSTANTS ##########

# Default values for URL request constants, will be substituted from the config file request.conf
#my $SECS_BETWEEN_REQUESTS = 3;
#my $SECONDS_BETWEEN_FAILED_GET_ATTEMTS = 5;
#my $SECS_AFTER_PROXY_SWITCH = 15;
#my $NO_PROXY_FREQ = 4;   # entry 'no_proxy' appears in the proxy list every $NO_PROXY_FREQ entries


############## VARS ##############
my $mech;
my %conf;  # URL requests configs
my $under_proxy = 0;

################## SUBS #############

sub download_proxies_list
{
	`rm -f .proxies`;
	if ($conf{NO_PROXY_FREQ}) {
		`curl -s "http://vpn.hidemyass.com/vpnconfig/countries.php" >.proxies`;
		# now I will insert no_proxy after every two entries in the file
		open(FIN, "<.proxies") or die "Could not open .proxies!";
		my @pp = <FIN>;
		close(FIN);
		open(FIN, ">.proxies") or die "Could not open .proxies!";
		my $i = 0;
		foreach my $p (@pp) {
			if ($i>=$conf{NO_PROXY_FREQ}) {
				print FIN "no_proxy\n";
				$i=0;
			}
			$i++;
			print FIN $p;	
		}
		close(FIN);
	} else {
		`echo 'no_proxy' >.proxies`	
	}
}
sub download_proxies_list_old
{
	`rm -f .proxies`;
	`curl -s "http://vpn.hidemyass.com/vpnconfig/countries.php" >>.proxies`;
	`sed 's/\$/\\nno_proxy/g' .proxies >/tmp/.proxies.tmp`;  # insert 'no_proxy' after every proxy server because it seems like Google recovers fast
	`cp /tmp/.proxies.tmp .proxies; rm /tmp/.proxies.tmp`;
}

sub set_proxy
{
	my $country = shift;
	system("cd ../hma; curl -s 'http://vpn.hidemyass.com/vpnconfig/client_config.php?win=1&loc=$country' | sed 's/auth-user-pass/auth-user-pass password.txt/g' > client.cfg");
##	system("cd ../hma; curl -s 'http://vpn.hidemyass.com/vpnconfig/client_config.php?win=1&loc=$country' | sed 's/auth-user-pass/auth-user-pass password.txt/g' | sed 's/;user nobody/user gleb/g' > client.cfg");

	my $pid = fork();
	die "Fork failed" unless defined $pid;
	if ($pid == 0) {   # child
	    exec("cd ../hma; sudo openvpn client.cfg");  # sudo is ok: the parent does sudo before so the password is entered
		exit;
	}
	print STDERR "New child's pid is $pid\n";

}

sub close_proxies
{
#	`pkill openvpn`; # terminate previous connection to proxy
	`sudo pkill openvpn`; # terminate previous connection to proxy
	# will ask for the root password even if there is no proxy run. Need to be fixed...
}

sub next_proxy
{
	close_proxies(); # terminate previous connection to proxy
	sleep 5;  # give time to terminate openvpn
	if (not -e ".proxies" or -z ".proxies") { 
#	if (not -e ".proxies" or -z ".proxies" or -A ".proxies" > .4) { 
	# update proxies list if the file doesn't exist or is empty or is old (try to use no_proxy as often as possible
		open(FIL,">.lock1") or die $!; 
		flock(FIL,LOCK_EX) or die 'flock: ';
		download_proxies_list();
		close(FIL);
	}
	open(FIN, "<.proxies") or die "Could not open .proxies!";
	my $proxy = <FIN>;
	chomp $proxy;
	close(FIN);
	# Set up a new connection: 
	if ($proxy eq 'no_proxy') {
		print STDERR "Switched to ", BOLD, YELLOW, "no proxy", RESET, "\n";
		$under_proxy = 0;
	} else {
		print STDERR "Switching to proxy ", BOLD, YELLOW, "$proxy", RESET, "\n";
		$proxy =~ s/ /+/g;
		$proxy =~ s/\+$//g;
		set_proxy($proxy);
		$under_proxy = 1;
	}
	open(FIL,">.lock2") or die $!; 
	flock(FIL,LOCK_EX) or die 'flock: ';
	`sed -n 2,100p .proxies >.tmpproxies; cat .tmpproxies >.proxies; rm .tmpproxies`;
	close(FIL);
	# give time to switch the proxy for the child and possible wait until Google calms down
	my $full_minutes = int($conf{SECS_AFTER_PROXY_SWITCH}/60);
	say STDERR "Waiting $full_minutes minutes+";
	for my $i (1..$full_minutes) {
		say STDERR "Waiting minute $i...";
		sleep 60;
	}
	sleep $conf{SECS_AFTER_PROXY_SWITCH}-60*$full_minutes;
}

sub is_under_proxy
{
	return $under_proxy;
}

sub connect_to_DB   ## do not forget to disconnect afterwards
{
	my $dbh = DBI->connect('dbi:mysql:google_counts:localhost','root','chairman',{mysql_auto_reconnect=>1})
		or die "can't connect to the DB: $DBI::errstr\n";
	$dbh->prepare("SET NAMES utf8")->execute();   # fixes non-latin encoding issues
	return $dbh;
}

sub exists_person    ## return the person's id if it exists in the table; otherwise, returns 0
{
	my $p = shift;
	my $dbh = connect_to_DB();
	my $sth=$dbh->prepare("SELECT * FROM people_names where name=".$dbh->quote($p)) or die;
	$sth->execute() or die;
	my $row = $sth->fetchrow_arrayref();
	$sth->finish();
	$dbh->disconnect();
	if (defined $row) { return $row->[0] } 
		else { return 0 }
}

sub fetchUrl
{
	my ($url) = @_;
	my $minfilesize=7000;
			
	my $att=0;
	while (1) {
		if ($att >= 3) {
			say STDERR "IP banned, $url. Changing proxy\a";
			next_proxy();
			$att=0;
		}
		$mech->get($url);
		my $err=0;
		print STDERR color 'bold blue';
		if ( not $mech->success ) {
			say STDERR "not \$mech->success"; $err++;
		} else {
			if ($mech->content=~/Our systems have detected unusual traffic from your computer network/i) {
				say STDERR "Unusual traffic"; $err++;
			}
			if (length($mech->content)<$minfilesize) {
				say STDERR "Too short file"; $err++;
				open(FOUT,">t.html") or die "Cannot open t.html";  # for debug
				print FOUT $mech->content;
				close(FOUT);
			}
		}
		print STDERR color 'reset';
		last if not $err;
		$att++;
		sleep $conf{SECONDS_BETWEEN_FAILED_GET_ATTEMTS};
		say STDERR "\a$att attempts failed! ".$mech->res->status_line." $url";
	}

	return $mech->content;
}

sub retrieve_all_mech
{
	my ($opt, $tmpfile, $getFreq, $store_in_DB, $exists_record) = @_;
	my $lang = $opt->{l};
	my $replace = $opt->{r};   # if defined, collect counts again and update the counts in the db
	my $is_cont = $opt->{c};
	my $zero_counts = $opt->{z};  # if defined, insert zero count entries into both tables
	my $period = 7*24*60*60;  # in secs - a week
	my $nperiods = 52; # a year
#	my $nperiods = 4; # debugging
	my @periods_seq = (0, $nperiods-1, ceil($nperiods/2),ceil($nperiods/3), 1..($nperiods-2));
	my $today = mktime(59,59,23,1,0,111);  # Jan, 1, 2011

	my @people = ();
	if (not $is_cont) {
		@people = <>;
	} else {	
		say STDERR "Reading the list of people form $tmpfile";
		open(FIN, "<$tmpfile") or die "Cannot open $tmpfile";
		@people = <FIN>;
		close(FIN);
	}
	chomp @people;
	

	my $CG = new Config::General("request.conf");
	%conf = $CG->getall();
	say Dumper(%conf);

	$mech = WWW::Mechanize->new(onerror => undef);
	$mech->timeout(30);
	$mech->agent('Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:13.0) Gecko/20100101 Firefox/13.0');
	
	my %data = ();
	$|++;
	PERSON:
	while (my $p = shift @people) {
		%data = ();      # save memory and increase stability
		$p =~ /^(.*?)(\t|$)/;   # The name is in the first column (maybe the only one but who knows) [*? is a non-greedy match]
		$p = $1;
		$p =~ s/\s+/+/g;   # заменить пробелы на плюсы
		next if not $replace and &$exists_record($p,$lang);  # do not download counts for people already in the people_names table for given language
		my $counter = 0;
		my $small_count = 0;
		for my $i (@periods_seq) {
			my @from = (localtime($today+$period*$i))[3..5]; 
			my @to = (localtime($today+$period*($i+1)))[3..5];
			$from[1]++; $to[1]++;
			$from[2]+=1900; $to[2]+=1900;
			$data{$p}[$i] = &$getFreq($p,@from,@to,$lang);
#			last PERSON if $data{$p}[$i]<0;
#			say $data{$p}[$i];
			die "Couldn't parse the page\n" if $data{$p}[$i]<0;
			print STDERR "$p\tperiod ".($i+1)." from $nperiods\t" . $data{$p}[$i] . "\n";
			if (++$counter == 4) {   # получили для 4ёх проверочных в начале, середине и конце
				if ($data{$p}[$periods_seq[0]] +
					$data{$p}[$periods_seq[1]] +
					$data{$p}[$periods_seq[2]] +
					$data{$p}[$periods_seq[3]] < 5) {
					say STDERR "Numbers are too small. Next person...";
					$small_count=1;
					map {$data{$p}[$_]=0} 0..($nperiods-1);
					last;
				}
			}
			sleep $conf{SECS_BETWEEN_REQUESTS};
		}
		if (not $small_count or $zero_counts) {
			say join("\t",$p, @{$data{$p}}); # OUTPUT
			&$store_in_DB($p, $data{$p}, $lang); # OUTPUT
		}
		open(FOUT, ">$tmpfile") or die "Could not open $tmpfile for writing";
		say FOUT join("\n", @people);
		close(FOUT);
	}
	$|--;
	unlink $tmpfile or warn "Could not unlink $tmpfile";
	close_proxies();
}

#
#sub format_date
#{
#	my ($d,$m,$y,$lang) = @_;
#	
#	# Specify Bing's (Imil's) not Google's language tags below
#	my @ru  = qw/ru no cz at de fr/;
#	my @eur = qw/uk my it en_in gb ar cl es_co es/;
#	my @us  = qw/us/;
#	my @f = ();
#	my $delim = '/';
#	switch ($lang) {
#		case (\@ru)		{ @f = ($d,$m,$y); $delim='.' }
#		case (\@eur)	{ @f = ($d,$m,$y); $delim='/' }
#		case (\@us)		{ @f = ($m,$d,$y); $delim='/' }
#		else			{ return 0 }
#	}
#	if (defined $delim) {
#		return join($delim,@f);
#	} else {
#		return @f;
#	}
#}

our %tags = (  # Imil (Bing) => Google
		gb	=> 'en_uk',
		us	=> 'en_us',
		at	=> 'de_at',
		de	=> 'de',
		cz	=> 'cs_cz',
		dk	=> 'da',
		hr	=> 'hr',
		id	=> 'id',
		in	=> 'en_in',
		it	=> 'it',
		my	=> 'en_my',
		no	=> 'no_no',
		ru	=> 'ru_ru',
		ar	=> 'es_ar',
		cl	=> 'es_cl',
		co	=> 'es_co',
		es	=> 'es',
		fr	=> 'fr',

		za	=> 'en_za',
		ch	=> 'de_ch',
		bo	=> 'es_bo',
		ec	=> 'es_ec',
		mx	=> 'es_mx',
		pe	=> 'es_pe',
		py	=> 'es_py',
		uy	=> 'es_uy',
		se	=> 'sv_se',
		nl	=> 'nl',

		ve	=> 'es_ve',

		pt	=> 'pt-PT_pt',

		);


1;
