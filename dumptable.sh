#!/bin/bash


# DO NOT RUN WHEN NEW ROWS ARE BEING ADDED INTO THE TABLES!!!

# the input argument is a number: 1 Acer, 2 Morgan's, 3 Jing's old, 4 Jing's Sony Vaio

tbl1=gblogs_counts_lr
tbl2=gnews_counts_lr
tbl3=people_names
n=$1
tbl1new=$tbl1""_$n
tbl2new=$tbl2""_$n
tbl3new=$tbl3""_$n

mysql -uroot -pchairman google_counts -e "ALTER TABLE $tbl1 RENAME TO $tbl1new; ALTER TABLE $tbl2 RENAME TO $tbl2new; ALTER TABLE $tbl3 RENAME TO $tbl3new"
mysqldump --quick -uroot -pchairman google_counts $tbl1new $tbl2new $tbl3new | gzip > google_counts_$n.gz
mysql -uroot -pchairman google_counts -e "ALTER TABLE $tbl1new RENAME TO $tbl1; ALTER TABLE $tbl2new RENAME TO $tbl2; ALTER TABLE $tbl3new RENAME TO $tbl3"

