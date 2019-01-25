#
# MAKEFILE
# GTrends for Tourism
#
# Andrea Ballatore
# 2018
#

SHELL := /bin/bash

DATE=`date +"%Y%m%d_%H"`

all:
	@echo "Select an option.";
	@cat Makefile;
	@echo "\n";

scrape:
	Rscript gtrends_tourism_scraper.R  > tmp/rscript_log_$(DATE).txt 2>&1
	
running:
	-@ps auxw | grep '[s]crape';
	#-@ps auxw | grep '[t]or';
	#-@netstat -ant | grep 9050;

clean_tmp: check_clean
	rm -rf tmp/*;

check_clean:
	@echo "Are you sure? [y/N] " && read ans && [ $${ans:-N} == y ]


wait:
	sleep 3;