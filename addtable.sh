#!/bin/bash


gunzip google_counts_1.gz
mysql -uroot -pchairman google_counts < $filename 

