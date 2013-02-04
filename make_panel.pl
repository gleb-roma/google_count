#!/usr/bin/perl -w

use strict;
use feature 'say';
#use Data::Dumper;
use DBD::mysql;
use DBI;
use mediaSubs qw(connect_to_DB);
use Getopt::Std;
use POSIX qw/mktime ceil/;

############### VARS ##########################


############### SUBS ##########################


############# BEGIN ######################

my %opt=();
getopts('l:',\%opt);
#getopts('l:rcz',\%opt);
die unless defined $opt{l};
my $lang = $opt{l};

my $tmpfile = "".int(rand(1000000));
#my $query = "SELECT * FROM gnews_counts";
#my $query = "SELECT * FROM gblogs_counts";
my $query = "SELECT * FROM gblogs_counts_as where lang='$lang'";
#my $query = "SELECT * FROM gblogs_counts where lang='en_uk'";
#my $query = "SELECT * FROM gblogs_counts_lr where lang='my'";
my $dbh=connect_to_DB();
my $sth=$dbh->prepare($query) or die;
$sth->execute() or die;
my %data = ();
while (my @row = $sth->fetchrow_array()) {
	$data{$row[2]}{$row[0]}{$row[1]} = $row[3];
}
$sth->finish();
$dbh->disconnect();

say "Country\tName_id\t".join("\t",1..52);
foreach my $lang (keys %data) {
	foreach my $id (keys %{$data{$lang}}) {
		my @a = '.' x 52;
		foreach my $w (keys %{$data{$lang}{$id}}) {
			$a[$w-1] = $data{$lang}{$id}{$w};
		}
		say "$lang\t$id\t".join("\t", @a);
	}
}	
