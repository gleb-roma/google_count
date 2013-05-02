#!/bin/bash

# uses .gz files with dump tables to add them into the MySQL database
# just that, no merging
# next step is to merge, use mergetable.sh

n=$1


gunzip google_counts_$n.gz
mysql -uroot -pchairman google_counts < google_counts_$n

