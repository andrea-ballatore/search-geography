#-------------------------------------------------------------------------------
# Name:        module1
# Purpose:
#
# Author:      Schei008
#
# Created:     29/10/2018
# Copyright:   (c) Schei008 2018
# Licence:     <your licence>
#-------------------------------------------------------------------------------
import geopandas
import json


def main():
    data =  'geodata/MetrAFull.shp'
    store='geodata/MetrAFull.json'

    regions = geopandas.GeoDataFrame.from_file(data)

    buurten = regions.groupby(['BU_CODE']) ['BU_CODE','BU_NAAM', 'AANT_INW'].first()
    wijken=   regions.groupby(['WK_CODE']) ['WK_CODE','WK_NAAM', 'AANT_INW_1'].first() #row['BU_NAAM']   row['WK_CODE']
    municipalities =   regions.groupby(['GM_CODE']) ['GM_CODE', 'GM_NAAM', 'AANT_INW_2'].first() #row['BU_NAAM']   row['WK_CODE']

    dict={}


    for index, row in municipalities.iterrows():
        name = row['GM_NAAM']
        number = int(row['AANT_INW_2']) ##
        dict[row['GM_CODE']]= {'name':name ,'noinhabitants':number}
    for index, row in wijken.iterrows():
        name = row['WK_NAAM']
        number = int(row['AANT_INW_1'])
        dict[row['WK_CODE']]= {'name':name ,'noinhabitants':number}
    for index, row in buurten.iterrows():
        print row['BU_NAAM']
        name = row['BU_NAAM']
        number = int(row['AANT_INW'])
        dict[row['BU_CODE']]= {'name':name ,'noinhabitants':number}

    with open(store, 'w') as fp:
            json.dump(dict, fp)
    fp.close

if __name__ == '__main__':
    main()
