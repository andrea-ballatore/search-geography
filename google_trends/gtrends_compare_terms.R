# title: "Google Trends comparison of terms"
# self_contained: false
# author: Andrea Ballatore
# date: Dec 2018

# setup ----

library(pacman)

#devtools::install_github("PMassicotte/gtrendsR") # alt version #1
#devtools::install_github('diplodata/gtrendsR') # alt version #2
pacman::p_load( gtrendsR, foreach, iterators )

# https://cran.r-project.org/web/packages/gtrendsR/gtrendsR.pdf

RANDOM_PAUSE_MIN_S = 1
RANDOM_PAUSE_MAX_S = 3
CUR_DATE = substr(as.character(Sys.time()),0,10)

sort_df <- function( df, col, asc=T ){
  sdf = df[ with(df, order(df[,c(col)], decreasing = !asc)), ]
  return(sdf)
}

random_pause <- function( min_seconds, max_seconds ){
  stopifnot(min_seconds <= max_seconds)
  secs = runif(1, min_seconds, max_seconds)
  print(paste("random_pause seconds =",round(secs,1)))
  Sys.sleep(secs)
}

# execute funct on each row of the data frame df
# and then calls rbind on results
foreach_row_in_df = function(df, funct){
  foreach(d=iter(df, by='row'), .combine=rbind, .errorhandling="stop") %dopar% funct(d)
}

foreach_group_in_df <- function( df, splitcols, funct ){
  stopifnot(nrow(df)>0)
  resdf <- foreach(block=split(df, df[,splitcols]), 
                   .combine='rbind', .errorhandling="stop") %do% {
                     if (nrow(block) == 0) return(NULL)
                     return( funct(block) )
                   }
  return(resdf)
}

# return a data frame with unique pairs of the input terms.
# for example, it returns <a,b> but not <b,a>.
get_all_pairs <- function( terms ){
  term_pairs = merge(terms, terms, all=TRUE)
  term_pairs = unique(subset(term_pairs, term_pairs$x != term_pairs$y ))
  term_pairs$xy = ifelse( as.character(term_pairs$x) < as.character(term_pairs$y),
                          paste0(term_pairs$x,'<>',term_pairs$y),
                          paste0(term_pairs$y,'<>',term_pairs$x))
  term_pairs = term_pairs[!duplicated(term_pairs$xy),]
  # swap x,y
  term_pairs$z = term_pairs$x
  term_pairs$x = term_pairs$y
  term_pairs$y = term_pairs$z
  # clear temp cols
  term_pairs$xy = NULL
  term_pairs$z = NULL
  return(term_pairs)
}

# GTrends Scraper ---------------------------------

get_url = function( url ){
  library(httr)
  r = GET(url)
  status = status_code(r)
  if (status == 200) return( content(r,encoding = 'utf8') )
  return(r)
}

# Based on https://cran.r-project.org/web/packages/gtrendsR/gtrendsR.pdf

# load Google Trends categories
data("categories") 
nrow(categories)
summary(categories)

parse_gt_hits <- function( hits ){
  hits = replace(hits, hits=='<1', .5) # <1 ----> 0.5
  h = as.numeric(hits)
  h[is.na(h)] = 0 # replace NAs with 0
  return(h)
}

# Main ------

# create output folder
dir.create('tmp',showWarnings = F)

# select terms
search_terms = c('big data','big data analytics','data science','gis',
                 'giscience','geographic information science','geoanalytics',
                 'spatial analytics','spatial data science','geoinformatics')

# cross join
term_pairs = get_all_pairs(search_terms)

# get google trends for each pair
resdf = foreach_row_in_df(term_pairs, function(r){
  x = as.character(r$x)
  y = as.character(r$y)
  time = "today 12-m"
  print(paste(x,' <> ',y))
  Sys.sleep(1) # pause in secs
  # call Google Trends API
  df = gtrends(c(x,y), geo='', time=time)
  res = df$interest_over_time
  res$term1 = x
  res$term2 = y
  res$term1b = res$keyword == res$term1
  res$term2b = res$keyword == res$term2
  res$query = paste0(x,';',y)
  res$query_time = time
  return(res)
})
resdf$hits = parse_gt_hits(resdf$hits)
bin_df_fn = 'tmp/gtrends_results_df.rds'
saveRDS(resdf,bin_df_fn)

# summarise results
gtrendsdf = readRDS(bin_df_fn)

termsummarydf = foreach_group_in_df(gtrendsdf,c('query','keyword'),function(block){
    row = data.frame(
      query = unique(block$query),
      keyword = unique(block$keyword),
      term = ifelse( unique(block$term1b), 'a', 'b'),
      hits_mean = round(mean(block$hits,na.rm = T),3),
      hits_sd = round(sd(block$hits,na.rm = T),3),
      hits_median = median(block$hits,na.rm = T),
      date_range = paste(min(block$date),max(block$date))
    )
    row
})
termsummarydf = sort_df(termsummarydf,'query')
#saveRDS(resdf,bin_df_fn)
View(termsummarydf)

print("OK")