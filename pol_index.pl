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

my %d = ();
my $dir = 'lists/';
opendir(DIR, $dir) or die $!;
while (my $file = readdir(DIR)) {
	next unless $file =~ /(\w\w)-top-(\w+)/;
	say $file;
	my $country = $1;
	my $pf = $2;
	my ($gen, $incl, $excl) = qw/0 0 0/;
	if ($pf =~ /general/) { $gen = 1; }
	if ($pf =~ /exclude/) { $excl = 1; }
	if ($pf =~ /include/) { $incl = 1; }
#	say "$country\t$gen\t$excl\t$incl";

	open(FIN, "<$dir$file") or die $!;
	while (my $p = <FIN>) {
		chomp $p;
		$p =~ /^(.*?)(\t|$)/;
		$p = $1;
		$p =~ s/\s+/+/g;
#		say $p;
		$d{$country}{$p}{g} += $gen;
		$d{$country}{$p}{i} += $incl;
		$d{$country}{$p}{e} += $excl;
	}	
	close(FIN);
}
close(DIR);

my $dbh = connect_to_DB();

say "Inserting into the database...";
	
foreach my $c (keys %d) {
	say $c;
	my $query = "INSERT IGNORE INTO politician_dummies(name,lang,exclude_keywords,no_keywords,include_keywords) VALUES ";
	foreach my $p (keys %{$d{$c}}) {
#		say "\t$p";
		my ($gen, $incl, $excl) = qw/0 0 0/;
		$gen = $d{$c}{$p}{g} if exists $d{$c}{$p}{g};
		$excl = $d{$c}{$p}{e} if exists $d{$c}{$p}{e};
		$incl = $d{$c}{$p}{i} if exists $d{$c}{$p}{i};
		$query .= "(".$dbh->quote($p).",'$c',$excl,$gen,$incl),";
	}
	chop $query;
	my $sth=$dbh->do($query) or die "Error: " . $dbh->errstr . "\n";	
}

$dbh->disconnect();

__END__
After that, add the dummies into the main tables

create table bl like gblogs_counts_lr_all;

REPLACE INTO bl(name_id,week,lang,count,ctime,exclude_keywords,no_keywords,include_keywords) SELECT b.name_id, b.week, b.lang, b.count, b.ctime, c.exclude_keywords, c.no_keywords, c.include_keywords FROM gblogs_counts_lr_all AS b, people_names_all AS a, politician_dummies AS c WHERE b.name_id=a.id and a.name=c.name and b.lang=c.lang;

drop table gblogs_counts_lr_all;

rename table bl to gblogs_counts_lr_all;

create table bl like gnews_counts_lr_all;

REPLACE INTO bl(name_id,week,lang,count,ctime,exclude_keywords,no_keywords,include_keywords) SELECT b.name_id, b.week, b.lang, b.count, b.ctime, c.exclude_keywords, c.no_keywords, c.include_keywords FROM gnews_counts_lr_all AS b, people_names_all AS a, politician_dummies AS c WHERE b.name_id=a.id and a.name=c.name and b.lang=c.lang;

drop table gnews_counts_lr_all;

rename table bl to gnews_counts_lr_all;




