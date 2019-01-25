#-------------------------------------------------------------------------------
# Name:        module1
# Purpose:
#
# Author:      Schei008
#
# Created:     20-11-2018
# Copyright:   (c) Schei008 2018
# Licence:     <your licence>
#-------------------------------------------------------------------------------

import pytrends
import pandas
import numpy as np

from pytrends.request import TrendReq

import csv

import json
import re

"""This class is used to gather Googe Trends for an arbitrary list of keywords (about tools). It is inititalized with a reference keyword to compare relative popularity against"""
class GatherInterest():
    def __init__(self, referencekeyword, referenceid, unsaferun=False):
         self.results = {}
         self.kw = referencekeyword
         self.referenceid = referenceid
         self.kwvalues = {}
         self.results['reference']=referencekeyword
         self.currentkw= [referencekeyword]
         self.currentregionids = [referenceid]
         self.unsaferun =unsaferun


    def reset(self):
        self.currentkw= [self.kw]
        self.currentregionids = [self.referenceid]

    def add(self,kw, region):
        if kw not in self.currentkw and kw != 'NaN' and kw != None and type(kw) is str:
            print str(kw) +':'+ str(type(kw))
            self.currentkw.append(kw)
            self.currentregionids.append(region)
        if len(self.currentkw)>=5:
            print 'querying for 5 keywords!'
            res = self.queryGTrends(self.currentkw)[self.currentkw]
            #print list(res)
            self.kwvalues = res[self.kw]
            sortedvalues = res.max().sort_values()
            sortedkw = sortedvalues.keys().tolist()
            print sortedkw
            print sortedvalues
            #print sortedvalues.iloc[-1]
            for id in range(1,sortedvalues.size):
                last =-id
                secondlast = -(id+1)
                if sortedvalues.iloc[last]- sortedvalues.iloc[secondlast]>80:
                    newvalues = self.queryGTrends(sortedkw[0:last])[sortedkw[0:last]]
                    #.astype(float)
                    newmax = newvalues.max().sort_values().keys()[-1]
                    #print newmax
                    newreferencevalue =float(sortedvalues.get_value(newmax))
                    #print str(newreferencevalue)
                    print 'Re-queried with higher resolution! reference '+newmax + " "+str(newreferencevalue)
                    newvalues = newvalues*newreferencevalue/100
                    #print newvalues
                    res = res[sortedkw[last:]].join(newvalues)
                    break
            #print res
            self.store(res)
            self.reset()

    def store(self,res):
        for id,t in enumerate(self.currentkw):
            if not t == self.kw:
                #make sure trends are within plausible limits
                #B = res[t] < res[self.kw] and res[t] >0
                #if self.unsaferun: B = True
                self.results[t]=[self.currentregionids[id],res[t]]



    def dump(self, res = 'data\\targetqueries\\GTresults.csv'):
        self.results[self.kw]=[self.referenceid,self.kwvalues]
        with open(res, 'wb') as out:
            writer = csv.writer(out, delimiter=',', quotechar='|', quoting=csv.QUOTE_MINIMAL)
            writer.writerow(['id', 'name', 'datetime', 'GTvalue', 'reference'])
            for k,v in self.results.items():
                if type(v) is list:
                    for index, row in v[1].iteritems():
                        #print ' '.join([v[0], k, str(index), str(row), self.kw])
                        writer.writerow([v[0], k, str(index), str(row), self.kw])

        print "dumped items: "+str(len(self.results))
        out.close

    def queryGTrends(self,kw_list):
        google_username = "simonscheider@web.de"
        google_password = "5z4cxCbN"
        pytrends = TrendReq(hl='en-US')

        pytrends.build_payload(kw_list, timeframe='all')
        #pytrends.build_payload(kw_list)

        # Interest over time
        time = pytrends.interest_over_time()
        #time.mean()
        #print(time.mean())


        # Related Queries, returns a dictionary of dataframes
        #related_queries_dict = pytrends.related_queries()
        #print(related_queries_dict)

        #related_topics_dict = pytrends.related_topics()
        #print(related_topics_dict)

        # Get Google Hot Trends data
        # trending_searches_df = pytrends.trending_searches()
        # print(trending_searches_df.head())


        # Get Google Keyword Suggestions
        #suggestions_dict = pytrends.suggestions(keyword='GIS')
        # print(suggestions_dict)
        return time#.mean()

"""Trends for regions"""
def getTrends4Regions(regioncsv, referencekeyword, referenceid):
    count = 0
    keywordid = ''
    pd = pandas.read_csv(regioncsv)
    pd = pd[pd['QUERY_BASETERM'] == False & pandas.notnull(pd['safe_keyword'])]
    gt = GatherInterest(referencekeyword,referenceid)
    print "ready to query over "+str(len(pd.index)) + ' regions!'
    print list(pd)
    #print pd
    #kws = []
    for index, row in pd.iterrows():
        kw =  row['safe_keyword']
        region = row['\xef\xbb\xbfGEOUNIT_CODE']
        if kw == referencekeyword: keywordid= region
        if kw != 'nan':
            #kws.append(kw)
            count+=1
            gt.add(kw, region)
            #
        #if count == 10 :
            #break

    print 'Regions queried '+str(count)
    gt.dump('data\\targetqueries\\GT.csv')
    return gt.results

def analyse(results):
    for k,v in results.items():
        if k != 'reference':
            name = k
            region = v[0]
            data = v[1]
            print data.groupby(pandas.TimeGrouper('A')).mean()
            break







def main():
    results = getTrends4Regions('geodata\\GMsearchterms.csv', 'Amsterdam', 'GM0363')
    #orderregions(['Amsterdam',  'Almere','Aalsmeer','Amstelveen'])
    #analyse(results)


if __name__ == '__main__':
    main()
