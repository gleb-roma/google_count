#!/bin/bash

# merges tables from machine $1 to the general tables *_all. 
# makes sure that the people's ids are unique in the final table and match the associated names in people_names_all

# the input argument is a number: 1 Acer, 2 Morgan's, 3 Jing's old, 4 Jing's Sony Vaio

tbl1=gblogs_counts_lr
tbl2=gnews_counts_lr
tbl3=people_names
n=$1
tbl1new=$tbl1""_$n
tbl2new=$tbl2""_$n
tbl3new=$tbl3""_$n

echo "Inserting into people_names_all..."
mysql -uroot -pchairman google_counts -e "INSERT IGNORE INTO people_names_all(name) SELECT name from people_names_$n"

echo "Inserting into gblogs_counts_lr_all..."
mysql -uroot -pchairman google_counts -e "REPLACE INTO gblogs_counts_lr_all(name_id,week,lang,count,ctime) SELECT c.id, b.week, b.lang, b.count, b.ctime FROM gblogs_counts_lr_$n AS b, people_names_$n AS a, people_names_all AS c WHERE b.name_id=a.id and a.name=c.name"

echo "Inserting into gnews_counts_lr_all..."
mysql -uroot -pchairman google_counts -e "REPLACE INTO gnews_counts_lr_all(name_id,week,lang,count,ctime) SELECT c.id, b.week, b.lang, b.count, b.ctime FROM gnews_counts_lr_$n AS b, people_names_$n AS a, people_names_all AS c WHERE b.name_id=a.id and a.name=c.name"
