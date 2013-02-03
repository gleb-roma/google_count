#!/usr/bin/perl -w
# на входе строчки с людьми, аргумент l - язык, r - перезаписывать ли счётчики в gnews_counts при повторах, c - указать, чтобы продолжить после остановки. В этом случае со входа ничего не читается. 
# На выходе строчки Имя+Фамилия и упоминания через таб в хронологическом порядке. Также всё пишется в таблицы people_names и gnews_counts
# NB Еще на STDOUT выводиться какая-то хрень от openvpn
# Результаты из Google News Archive

use strict;
use feature 'say';
#use Data::Dumper;
use DBD::mysql;
use DBI;
use mediaSubs qw(fetchUrl retrieve_all_mech connect_to_DB close_proxies format_date exists_person);
use Getopt::Std;
use POSIX qw/mktime ceil/;

############### VARS ##########################
my $DB_TABLE = 'gnews_counts'; # name of the table where the results are going to be stored


############### SUBS ##########################
END {
	close_proxies(); 
}

sub getFreq_us
{
	my ($text,$d0,$m0,$y0,$d1,$m1,$y1,$l) = @_;
	my $url = "http://www.google.com/search?hl=en&gl=us&tbm=nws&q=$text&sa=X&source=lnt&tbs=sbd:1,nsd:1,cd_min:$m0/$d0/$y0,cd_max:$m1/$d1/$y1";
	print STDERR $url."\n";
	my $html = fetchUrl($url);

	$html =~ /id=resultStats>\s*(About)?\s*([\d,]+)\s+result/i;
	return 0 unless defined $2;
	my $n=$2;
	$n =~ s/,//g;   # udalit zapyatuyu kak razdelitel razryadov
	if (not defined $n) {
		open(FOUT, ">dump.html");
		print FOUT $html;
		close(FOUT);
		return -1;
	}
	return $n;
}

sub getFreq
{
	my ($text,$d0,$m0,$y0,$d1,$m1,$y1,$l) = @_;
	my ($cdmin, $cdmax);
	my $date_from = format_date($d0,$m0,$y0,$l);
	if (not $date_from) {
		say STDERR "ERROR: Country $l is not in the list";
		return -1;
	}
	my $date_to = format_date($d1,$m1,$y1,$l);
	my ($hl,$gl) = split '_',$l;
	$gl = $hl unless defined $gl;
	my $url = "http://www.google.com/search?hl=$hl&gl=$gl&tbm=nws&q=$text&sa=X&source=lnt&tbs=cdr:1,cd_min:$date_from,cd_max:$date_to";  # cdr:1 - sorted by relevance
#	print STDERR $url."\n";
	print STDERR "$0\t$url\n";   # name of the running script + url
	my $html = fetchUrl($url);

	$html =~ /id=resultStats>\D*([\d,.]+)\D*<nobr>/i;
	return 0 unless defined $1;
	my $n=$1;
	$n =~ s/[,\.]//g;   # udalit zapyatuyu i tochku kak razdelitel razryadov
	if (not defined $n) {
		open(FOUT, ">dump.html");
		print FOUT $html;
		close(FOUT);
		return -1;
	}
	return $n;
}

sub generate_link_us
{
	my ($lang,$name,$i) = @_;

	my $period = 7*24*60*60;  # in secs - a week
	my $today = mktime(59,59,23,1,0,111);  # Jan, 1, 2011
	my @from = (localtime($today+$period*$i))[3..5]; 
	my @to = (localtime($today+$period*($i+1)))[3..5];
	$from[1]++; $to[1]++;
	$from[2]+=1900; $to[2]+=1900;
	my $url = "http://www.google.com/search?hl=en&gl=us&tbm=nws&q=$name&sa=X&source=lnt&tbs=cdr:1,cd_min:$from[1]/$from[0]/$from[2],cd_max:$to[1]/$to[0]/$to[2]";
	return $url;
}

sub store_in_DB
{
	my ($p, $counts, $lang) = @_;
	
	my $dbh = connect_to_DB();
	my $query = "INSERT IGNORE INTO people_names(name) VALUES (".$dbh->quote($p).")";
	my $sth;
	$sth=$dbh->do($query)
		or die "Error: ". $dbh->errstr."\n" ;
	$sth=$dbh->prepare("SELECT * FROM people_names where name=".$dbh->quote($p)) or die;
	$sth->execute() or die;
	my @row = $sth->fetchrow_array();
	$sth->finish();
	my $id = $row[0];
	say STDERR "id==$id";
		
	$query = "REPLACE INTO $DB_TABLE(name_id,week,lang,count,ctime) VALUES ";
	my $i=1;
	foreach my $c (@$counts) {
		$query .= "($id,$i,'$lang',$c,NOW()),";
		$i++;
	}
	chop $query;
	$sth=$dbh->do($query) or die "Error: " . $dbh->errstr . "\n";	
	$dbh->disconnect();
}

sub exists_record  ## return the person's id if it exists in the names table AND if there is a record in gnews_counts table
{
	my $p = shift;
	my $lang = shift;
	my $id = exists_person($p); # id=0 if the person does not exist in the data base
	return 0 unless $id;

	my $dbh = connect_to_DB();
	my $sth=$dbh->prepare("SELECT * FROM $DB_TABLE WHERE name_id=$id AND lang=".$dbh->quote($lang)) or die;
	$sth->execute() or die;
	my $row = $sth->fetchrow_arrayref();
	$sth->finish();
	$dbh->disconnect();
	if (defined $row) { return $id } 
		else { return 0 }
}

############# BEGIN ######################

my %opt=();
getopts('l:rcz',\%opt);
die unless defined $opt{l};
# if option r is set, will download counts and stores in the DB, replacing older entries if necessary. Otherwise, if the name is in people_names tableAND there is a record in gnews_counts table with the person from this country, skips downloading counts
# if option c is set, goes to the temp file, if not, starts from the scratch
# if z is set, the person is added into the db even he has all zero counts. It is to track the people who were processed
$SIG{INT} = sub { close_proxies(); exit 0 };
retrieve_all_mech(\%opt, ".".$opt{l}."_people.tmp",\&getFreq,\&store_in_DB,\&exists_record);

#my $week = 2;   
#say generate_link($opt{l},'Алексей+Навальный',$week);
