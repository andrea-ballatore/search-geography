# title: "Gtrends Tourism"
# output: 
# html_document:
# self_contained: false

rm(list = ls())

# setup ----

library(pacman)

#devtools::install_github("PMassicotte/gtrendsR") # not working
#devtools::install_github('diplodata/gtrendsR') # fix that also doesn't work
pacman::p_load(readr,rvest,urltools,uuid,RSQLite,rjson,rgdal,curl,gtrendsR,rmarkdown)

# https://cran.r-project.org/web/packages/gtrendsR/gtrendsR.pdf

RANDOM_PAUSE_MIN_S = 1
RANDOM_PAUSE_MAX_S = 3
CUR_DATE = substr(as.character(Sys.time()),0,10)

load_res_table <- function( fn, quot="" ){
  df <- read.table(file=fn, header=TRUE, sep="\t", stringsAsFactors=T, #fileEncoding="UTF-8",
                   fill = TRUE, quote = quot, comment.char = "", na.strings = "<NA>" )
  print(paste("Loaded",fn,"> rows=",nrow(df)))
  return(df)
}

sort_df <- function( df, col, asc=T ){
  sdf = df[ with(df, order(df[,c(col)], decreasing = !asc)), ]
  return(sdf)
}

save_obj_bin <- function( obj, obj_name ){
  #print(paste("save_obj_bin",get_bin_file_name(obj_name)))
  saveRDS( obj, file = get_bin_file_name(obj_name), compress=T )
  print(paste("save_obj_bin:",obj_name))
}

load_obj_bin <- function( obj_name ){
  print(paste("load_obj_bin:",obj_name))
  return( readRDS( get_bin_file_name(obj_name) ) )
}

get_bin_file_name <- function( obj_name ){
  print("get_bin_file_name")
  fn = file.path(BIN_DIR_, paste( obj_name, ".rds", sep=""))
  print(fn)
  return(fn)
}

random_pause <- function( min_seconds, max_seconds ){
  stopifnot(min_seconds <= max_seconds)
  secs = runif(1, min_seconds, max_seconds)
  print(paste("random_pause seconds =",round(secs,1)))
  Sys.sleep(secs)
}

write_text_file <- function( contents, fn ){
  print(paste("write_text_file",nchar(contents)))
  #sink(fn)
  write(contents,file = fn)
  #sink()
}

# Datasets ---------

# load and prep NL datasets

# L1 (gm) (municipalities)  = 33
# L2 wijken (wk) (quarters) = 352
# L3 buurten (bu) (neighborhoods) = 1517, with other level codes for joins

# Fields:
# AANT_INW = tot pop
# BEV = density

cols = c("CODE","NAME")
gm_sdf = readOGR(dsn="geodata/MetropolregionA.shp") # level 1
names(gm_sdf)[1:2]=cols
wk_sdf = readOGR(dsn="geodata/MetrAWijk.shp") # level 2
names(wk_sdf)[1:2]=cols
bu_sdf = readOGR(dsn="geodata/MetrABuurt.shp") # level 3
names(bu_sdf)[1:2]=cols

if (F){
  # transform to latlon 
  epsg4326 = CRS("+init=epsg:4326")
  gm_llsdf = spTransform(gm_sdf,epsg4326)
  writeOGR(gm_llsdf,'geodata/NL_admin_boundaries/netherlands_L1_gm_latlon_sdf.geojson','netherlands_L1_gm',driver = 'GeoJSON')
  gm_llsdf = spTransform(wk_sdf,epsg4326)
  writeOGR(gm_llsdf,'geodata/NL_admin_boundaries/netherlands_L2_wk_latlon_sdf.geojson','netherlands_L3_bu',driver = 'GeoJSON')
  gm_llsdf = spTransform(bu_sdf,epsg4326)
  writeOGR(gm_llsdf,'geodata/NL_admin_boundaries/netherlands_L3_bu_latlon_sdf.geojson','netherlands_L3_bu',driver = 'GeoJSON')
  rm(gm_llsdf)
}

# save geodata as R data
saveRDS( gm_sdf, file = 'geodata/netherlands_L1_gm_sdf.rds', compress=T )
saveRDS( wk_sdf, file = 'geodata/netherlands_L2_wk_sdf.rds', compress=T )
saveRDS( bu_sdf, file = 'geodata/netherlands_L3_bu_sdf.rds', compress=T )

# GTrends Scraper ---------------------------------

get_url = function( url ){
  library(httr)
  r = GET(url)
  status = status_code(r)
  if (status == 200) return( content(r,encoding = 'utf8') )
  return(r)
}

# get URL from random VPN node. Linked to AB's PIA account.
get_url_piavpn = function( url ){
  library(RCurl)
  #print(paste('get_url_piavpn',url))
  pia_socks5 = 'socks5h://XXXXX@proxy-nl.privateinternetaccess.com:1080'
  #pia_socks5 = 'socks5://XXXXX@proxy-nl.privateinternetaccess.com:1080'
  options(RCurlOptions = list(proxy = pia_socks5,
                              #useragent = "Mozilla",
                              followlocation = TRUE,
                              verbose = F,
                              referer = "",
                              cookiejar = "tmp/_piavpn.cookies.txt"
  ))
  html <- RCurl::getURL(url=url, curl=RCurl::getCurlHandle())
  return(html)
}

# Google Search utils ---------

load_google_domains <- function(){
  google_domains = scan('data/google/google_supported_domains.txt',sep = '\n',what = "character")
  stopifnot(length(google_domains)==193)
  google_domains = data.frame(DOMAIN = google_domains)
  google_domains$DOMAIN = as.character(google_domains$DOMAIN)
  google_domains$TOPDOMAIN = substr( google_domains$DOMAIN, nchar(google_domains$DOMAIN)-2, nchar(google_domains$DOMAIN) )
  google_domains$TOPDOMAIN = gsub('\\.','',google_domains$TOPDOMAIN)
  return(google_domains)
}

get_google_languages_for_country <- function(country_code){
  stopifnot(nchar(country_code)==2)
  print(paste('get_google_languages_for_country',country_code))
  langs = strsplit( subset(google_country_langs, google_country_langs$COUNTRY==country_code)$LANGS, ',')[[1]]
  return(langs)
}

# Google Trends ------

# Based on https://cran.r-project.org/web/packages/gtrendsR/gtrendsR.pdf

# load Google Trends categories
data("categories") 
nrow(categories)
summary(categories)

get_gtrends_results <- function( base_term, terms ){
  print(paste("get_gtrends_results", base_term, terms))
  all_terms = c( base_term, terms )
  #print(all_terms)
  trial_i = 0
  found = F
  while(!found){
    tryCatch( {
      
      #options(RCurlOptions = list(proxy = pia_socks5,
                                  #useragent = "Mozilla",
      #                            followlocation = TRUE,
       #                           verbose = F,
        #                          referer = "",
         #                         cookiejar = "tmp/_piavpn.cookies.txt"
      #))
      res = gtrends(all_terms)
      found = T
      print('> Gtrends data found <')
    },
    error = function(e) {
      trial_i=trial_i+1
      print(e)
      traceback(e)
      #stop("Problem detected") # DEBUG
      #found=T # debug
      print(paste("Problem detected. Trying again, i =", trial_i));
      found = F
      random_pause(RANDOM_PAUSE_MIN_S,RANDOM_PAUSE_MAX_S)
    },
    finally = {})
  }
  
  return(res)
}

tag_results <- function(df, query_str, query_uid, geounit_code, geounit_name, geo_type ){
  df$GTREND_QUERY = query_str
  df$GEOUNIT_TYPE = geo_type
  df$GEOUNIT_CODE = geounit_code
  df$QUERY_UID = query_uid
  df$QUERY_BASETERM = df$keyword != geounit_name
  return(df)
}

save_results <- function( df, filename ){
  fdir = paste0('tmp/NL_gtrends_',CUR_DATE,'/')
  dir.create(fdir, showWarnings = FALSE)
  fn = paste0(fdir,filename,'.tsv')
  fnbin = paste0(fdir,filename,'.rds')
  saveRDS( df, file = fnbin, compress=T )
  print(paste('save_results',fn))
  write_tsv( df, fn, append = F, na = '')
}

# Main ------

#get_url_piavpn('https://github.com/curl/curl/issues/944')

# create outfolders
dir.create('tmp',showWarnings = F)
#dir.create('tmp/pages',showWarnings = F)

# Run GTrends queries

#res = get_gtrends_results('Amsterdam', c('Leiden','Rotterdam'))

#res$interest_by_city
#res$related_queries


# TODO
# check how to retrieve concepts
# gtrends data from 2004
# new adventurism - off the beaten track

# 1) go for the "city", "town" or "capital", "municipality", "village", "neighborhood" search instead of pure text search
# 2)  Use term + containing municipality term,

# if municipality, the  always  option 1
# if not, then:
#    if not in list of difficult cases (Zuid, Noord, :
#                                         first 1), the  2)

# Get NL flows ==========

if (F){
  interest_by_country_df = data.frame()
  
  kws = c('Amsterdam','Netherlands')
  for (keyword in kws){
  for (year in seq(2007,2017)){
  for (low_search_volume in c(T,F)){
      print(paste("--",keyword,year,low_search_volume))
      time_span = paste0(year,"-01-01 ",year,"-12-31")
      #print(time_span)
      res = gtrends(keyword = keyword, geo = '', time = time_span,
              #gprop = c("web", "news", "images", "froogle", "youtube"),
              category = 0, hl = "en-US",
              low_search_volume = low_search_volume )
              #cookie_url = "http://trends.google.com/Cookies/NID")
      df = res$interest_by_country
      df$low_search_volume = low_search_volume
      df$year = year
      interest_by_country_df <- rbind( interest_by_country_df, df )
      rm(res,df,time_span)
    }
  }}
  
  save_results(interest_by_country_df,'nl_amsterdam_countries_over_time_df')
  #View(interest_by_country_df)
  rm(interest_by_country_df)
}

## Get NL municip data =====

if (T){
  nl_gm_search_terms_df = read_csv("geodata/GMsearchterms.csv")
  nl_gm_search_terms_df = nl_gm_search_terms_df[nl_gm_search_terms_df$QUERY_BASETERM==F &
     nl_gm_search_terms_df$GEOUNIT_TYPE=='municipality', ]
  nl_gm_search_terms_df$X7=NULL
  nl_gm_search_terms_df$X8=NULL
  nl_gm_search_terms_df$X9=NULL
  nl_gm_search_terms_df$QUERY_BASETERM=NULL
  nrow(nl_gm_search_terms_df)
  #View(nl_gm_search_terms_df)
  stopifnot(nrow(nl_gm_search_terms_df)==33)
  
  gm_interest_time_df = data.frame()
  
  # get data for all municipalities
  j = 0
  geoscopes = c('','NL')
  for(mode in c('concept','string')){
  for (low_search_volume in c(T,F)){
  for (geoscope in geoscopes){
  for(i in seq(nrow(nl_gm_search_terms_df))){
    j = j + 1
    code = nl_gm_search_terms_df[i,]$GEOUNIT_CODE
    kw = nl_gm_search_terms_df[i,]$safe_keyword
    concept = URLdecode(nl_gm_search_terms_df[i,]$GT_concept)
    uid = UUIDgenerate()
    
    if (mode == 'concept') inkw = concept
    else inkw = kw
    print(paste('j =',j,'--',mode,code,kw,concept,geoscope,low_search_volume))
    # CALL Google Trends API
    res = gtrends(inkw, time = paste0(2007,"-01-01 ",2017,"-12-31"), 
                  geo = geoscope)
    df = res$interest_over_time
    df$UID = uid
    df$GEOUNIT_CODE = code
    df$GEOUNIT_NAME = kw
    df$GTRENDS_CONCEPT = concept
    df$GTRENDS_MODE = mode
    df$low_search_volume = low_search_volume
    gm_interest_time_df = rbind(gm_interest_time_df, df)
    random_pause(RANDOM_PAUSE_MIN_S,RANDOM_PAUSE_MAX_S)
    rm(res,df)
  }}}}
  
  save_results(gm_interest_time_df,'nl_gm_over_time_df')
  #View(gm_interest_time_df)
}

# TODO
# rm(gm_interest_time_df)
# 
# print(paste('>> get_gtrends_NL N=',nrow(shpdf),'geo_type=',geo_type))
# shpdf$NAME = as.character(shpdf$NAME)
# for( i in seq(nrow(shpdf)) ){
#   print(paste('i =',i))
#   code = as.character(shpdf@data[i,c("CODE")])
#   name = as.character(shpdf@data[i,c("NAME")])
#   
#   print(paste("get_gtrends_NL",uid,code,name))
#   query_str = paste(base_term, name, sep = ';')
#   #stopifnot(nchar(name)>2)
#   gres = get_gtrends_results(base_term, name)
#   
#   # "interest_over_time"  "interest_by_country" "interest_by_region"  
#   # "interest_by_dma"     "interest_by_city"    "related_topics"     
#   # "related_queries"
#   # --- interest_over_time ---
#   df = gres$interest_over_time
#   df = tag_results(df, query_str, uid, code, name, geo_type)
#   interest_over_time_df <<- rbind( interest_over_time_df, df )
#   #View(interest_over_time_df)
#   
#   # --- interest_by_country ---
#   #df = gres$interest_by_country
#   #df = tag_results(df, query_str, uid, code, name, geo_type)
#   #interest_by_country_df <<- rbind( interest_by_country_df, df )
#   #View(interest_by_country_df)
#   
#   # --- interest_by_country ---
#   #df = gres$interest_by_city
#   #df = tag_results(df, query_str, uid, code, name, geo_type)
#   #interest_by_city_df <<- rbind( interest_by_city_df, df )
#   #View(interest_by_city_df)
#   
#   rm(df)
# }
# 
# # init data
# interest_over_time_df = data.frame()
# interest_by_country_df = data.frame()
# interest_by_city_df = data.frame()
# 
# base_term = "Amsterdam"
# 
# #get_gtrends_amsterdam(base_term, gm_sdf, 'gm')
# #get_gtrends_amsterdam(base_term, wk_sdf, 'wk')
# #get_gtrends_amsterdam(base_term, nei, 'neighbourhood')
# 
# # save datasets
# save_results(interest_over_time_df,'interest_over_time_df')
# save_results(interest_by_country_df,'interest_by_country_df')
# save_results(interest_by_city_df,'interest_by_city_df')

print("OK")