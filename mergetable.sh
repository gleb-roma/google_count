#!/bin/bash

tbl1=gblogs_counts_lr
tbl2=gnews_counts_lr
tbl3=people_names
n="1"
tbl1new=$tbl1""_$n
tbl2new=$tbl2""_$n
tbl3new=$tbl3""_$n

#mysql -uroot -pchairman google_counts -e "
#	INSERT IGNORE INTO people_names_all(name) SELECT name FROM people_names_$n"

mysql -uroot -pchairman google_counts -e "
	REPLACE INTO gblogs_counts_lr_all(name_id,week,lang,count,ctime) SELECT name_id,week,lang,count,ctime FROM gblogs_counts_lr_$n"

