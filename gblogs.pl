#!/usr/bin/perl -w
# на входе строчки с людьми, аргумент l - язык, r - перезаписывать ли счётчики в gblogs_counts при повторах, c - указать, чтобы продолжить после остановки. В этом случае со входа ничего не читается. 
# На выходе строчки Имя+Фамилия и упоминания через таб в хронологическом порядке. Также всё пишется в таблицы MySQL
# NB Еще на STDOUT выводиться какая-то хрень от openvpn
# Результаты из Google Blogs Archive

use strict;
use feature 'say';
#use Data::Dumper;
use DBD::mysql;
use DBI;
use mediaSubs qw(fetchUrl retrieve_all_mech connect_to_DB close_proxies exists_person %tags);
use Getopt::Std;
use POSIX qw/mktime ceil/;
use Switch;
use Term::ANSIColor;
use Term::ANSIColor qw(:constants);

############### VARS ##########################
#my $DB_TABLE = 'gblogs_counts_as'; # name of the table where the results are going to be stored
my $DB_TABLE = 'gblogs_counts_lr'; # name of the table where the results are going to be stored
#my $DB_TABLE = 'gblogs_counts'; # name of the table where the results are going to be stored

############### SUBS ##########################
END {
	my $ec = $?;
	close_proxies(); 
	$? = $ec;
}

sub format_date   ## in Google Blogs. The reason is that Google expects American format for all English speaking regions
{
	my ($d,$m,$y,$lang) = @_;
	
	# Specify Bing's (Imil's) not Google's language tags below
	my @ru  = qw/ru no cz at de fr hr id ch/;
	my @eur = qw/it ar cl co es dk bo ec mx pe py uy ve pt br ro/; 
	my @us  = qw/us gb in my/;
	my @za	= qw/za jp/;
	my @sv	= qw/se/;
	my @nl	= qw/nl/;
	my @tr	= qw/tr/;
	my @f = ();
	my $delim = '/';
	switch ($lang) {
		case (\@ru)		{ @f = ($d,$m,$y); $delim='.' }
		case (\@eur)	{ @f = ($d,$m,$y); $delim='/' }
		case (\@us)		{ @f = ($m,$d,$y); $delim='/' }
		case (\@za)		{ @f = ($y,$m,$d); $delim='/' }
		case (\@sv)		{ @f = ($y,$m,$d); $delim='-' }
		case (\@nl)		{ @f = ($d,$m,$y); $delim='-' }
		case (\@tr)		{ @f = ($d,$m,$y); $delim='+' }
		else			{ return 0 }
	}
	if (defined $delim) {
		return join($delim,@f);
	} else {
		return @f;
	}
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
	my ($hl,$gl) = split '_',$tags{$l};
	$gl = $hl unless defined $gl;
#	my $url = "http://www.google.com/search?tbm=blg&hl=$hl&gl=$gl&q=$text&tbs=cdr:1,cd_min:$date_from,cd_max:$date_to";  # cdr:1 - sorted by relevance
	my $url = "http://www.google.com/search?tbm=blg&hl=$hl&gl=$gl&q=$text&tbs=cdr:1,cd_min:$date_from,cd_max:$date_to&lr=lang_$hl";  # LR cdr:1 - sorted by relevance, lr - results in language $hl
#	my $url = "http://www.google.com/search?tbm=blg&hl=$hl&as_q=$text&lr=lang_$hl&cr=country".uc($gl)."&as_qdr=all&as_occt=any&safe=images&tbs=cdr:1,cd_min:$date_from,cd_max:$date_to";   # AS
#EXAMPLE:	https://www.google.com/search?hl=en&as_q=denise+dumas&as_epq=&as_oq=&as_eq=&as_nlo=&as_nhi=&lr=lang_es&cr=countryAR&as_qdr=all&as_sitesearch=&as_occt=any&safe=images&tbs=lr:lang_1es,ctr:countryAR,cdr:1,cd_min:11/12/2012,cd_max:11/19/2012&as_filetype=&as_rights=
	#EXAMPLE: https://www.google.com/search?hl=en&as_q=Rihanna&as_epq=&as_oq=&as_eq=&as_nlo=&as_nhi=&lr=lang_es&cr=countryAR&as_qdr=all&as_sitesearch=&as_occt=any&safe=images&tbs=&as_filetype=&as_rights=
	#EXAMPLE: http://www.google.com/search?hl=es&as_q=Rihanna&lr=lang_es&cr=countryAR&as_qdr=all&as_occt=any&safe=images&tbs=cdr:1,cd_min:5/5/2012,cd_max:12/5/2012&as_rights=
	print STDERR "$0\t", GREEN, "$l\t", RESET, "$url\n";   # name of the running script + url
	my $html = fetchUrl($url);
	print STDERR "", GREEN, "URL fetched\n", RESET;

	if (not $html =~ /input\s+id=gbqfq/i) {  # there is a query input field
		open(FOUT, ">dump.html");
		print FOUT $html;
		close(FOUT);
		return -1;
	}
	if (not $html =~ /id=resultStats>(.+?)<nobr>/i) { 
		open(FOUT, ">dump.html");
		print FOUT $html;
		close(FOUT);
		return 0;
	}

	my $chunk = $1;
	$chunk =~ s/&#160;//g;
	$chunk =~ /\D*([\d,.]+)\D*/i;
	if (not defined $1) {
		open(FOUT, ">dump.html");
		print FOUT $html;
		close(FOUT);
		return 0;
	}
	my $n=$1;
	$n =~ s/[,\.]//g;   # udalit zapyatuyu i tochku kak razdelitel razryadov
	if (not defined $n or not ($n =~ /^\d+$/)) {
		open(FOUT, ">dump.html");
		print FOUT $html;
		close(FOUT);
		return -1;
	}
	return $n;
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

sub exists_record  ## return the person's id if it exists in the names table AND if there is a record in gblogs_counts table
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
# if option r is set, will download counts and stores in the DB, replacing older entries if necessary. Otherwise, if the name is in people_names table, skips downloading counts
# if option c is set, goes to the temp file, if not, starts from the scratch
# if z is set, the person is added into the db even he has all zero counts. It is to track the people who were processed
$SIG{INT} = sub { close_proxies(); exit 0 };
retrieve_all_mech(\%opt, ".blogs.".$opt{l}."_people.tmp",\&getFreq,\&store_in_DB,\&exists_record);
