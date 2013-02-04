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

#my %opt=();
#getopts('l:rcz',\%opt);
#die unless defined $opt{l};

my $outfile = shift @ARGV;
die "The first argument is the name of the output file" unless defined $outfile;

my @people = <>;
chomp @people;
my $dbh=connect_to_DB();
my $tmpfile = "".int(rand(1000000));
my $query = "SELECT * into outfile '/tmp/$tmpfile' FROM people_names where ";
for my $p (@people) {
#	say "'$p'";
	$p =~ /^(.*?)(\t|$)/;   # The name is in the first column (maybe the only one but who knows) [*? is a non-greedy match]
	$p = $1;
	$p =~ s/\s+/+/g;   # заменить пробелы на плюсы
	$query .= " name=".$dbh->quote($p)." or";
}
chop $query; #
chop $query; # delete 'or' at the end
say $query;
my $sth=$dbh->prepare($query) or die;
$sth->execute() or die;
my @row = $sth->fetchrow_array();
$sth->finish();
$dbh->disconnect();
`cp /tmp/$tmpfile ./$outfile`
