#
# title: "Google Trends comparison of terms"
#
# author: Andrea Ballatore (with input from Simon Scheider <simonscheider@web.de>)
# date: Dec 2018
#
# using https://cran.r-project.org/web/packages/gtrendsR/gtrendsR.pdf
#

# setup ----
rm(list=ls())

library(pacman)

pacman::p_load( gtrendsR, foreach, iterators, scales )
#devtools::install_github("PMassicotte/gtrendsR") # alt version #1
#devtools::install_github('diplodata/gtrendsR') # alt version #2

# create output folder
dir.create('output',showWarnings = F)

# input term file
INPUT_TERMS = "input/search_terms.txt"
# current date
CUR_DATE = substr(as.character(Sys.time()),0,16)
# last 12 months
TIME_SPAN = "today 12-m"
# precision of Google Trends index
DIGITS = 4
# weak signal threshold
MIN_INDEX = 1

# utils ----
sort_df <- function( df, col, asc=T ){
  sdf = df[ with(df, order(df[,c(col)], decreasing = !asc)), ]
  return(sdf)
}

# execute funct on each row of the data frame df
# and then calls rbind on results
foreach_row_in_df = function(df, funct){
  foreach(d=iter(df, by='row'), .combine=rbind, .errorhandling="stop") %do% funct(d)
}

# split data frame in sub-groups and apply function to each group
# returns a data frame
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
  stopifnot(length(terms)>1)
  term_pairs = as.data.frame(t(combn(terms,2)))
  names(term_pairs)=c('x','y')
  return(term_pairs)
}

# Google Trends comparator ----
# Based on https://cran.r-project.org/web/packages/gtrendsR/gtrendsR.pdf

# load Google Trends categories
data("categories") 
nrow(categories)
summary(categories)

# parse Google Trends index
parse_gt_hits <- function( hits ){
  hits = replace(hits, hits=='<1', .5) # <1 ----> 0.5
  h = as.numeric(hits)
  h[is.na(h)] = 0 # replace NAs with 0
  return(h)
}

# Util: extract Google Trends data for single term
get_gt_for_term = function(df, term){
  dfa = subset( df, df$term_a == term )
  dfa = data.frame(
    query = dfa$query,
    term = dfa$term_a,
    hits = dfa$hits_a,
    hits_ab_sum = dfa$hits_ab_sum
  )
  dfb = subset( df, df$term_b == term )
  dfb = data.frame(
    query = dfb$query,
    term = dfb$term_b,
    hits = dfb$hits_b,
    hits_ab_sum = dfb$hits_ab_sum
  )
  dfres = rbind(dfa,dfb)
  dfres
}

# formula to scale: <q1term1,q1term2>, <q2term2,q2term3> 
# (to express term3 in the same range as q1):
#         q1term3 = (q1term2 * q2term3) / q2term2
transform_gtrends_idx = function( q1term2, q2term2, q2term3){
  stopifnot(q2term2>0)
  q1term3 = (q1term2 * q2term3) / q2term2
  stopifnot(q1term3>=0)
  round(q1term3,DIGITS)
}

# Get GT data from API (with built-in delay)
call_gtrends_api_for_pairs = function(term_pairs, time_span, geoscope=''){
  # get google trends for each pair
  resdf = foreach_row_in_df(term_pairs, function(r){
    x = as.character(r$x)
    y = as.character(r$y)
    
    print(paste('  ',x,'<>',y))
    Sys.sleep(1) # pause in secs
    # call Google Trends API (slow)
    df = gtrends(c(x,y), geo=geoscope, time=time_span)
    # extract results
    res = df$interest_over_time
    res$term1 = x
    res$term2 = y
    res$term1b = res$keyword == res$term1
    res$term2b = res$keyword == res$term2
    res$query = paste0(x,';',y)
    res$query_time = time_span
    res$ts = CUR_DATE
    return(res)
  })
  resdf$hits = parse_gt_hits(resdf$hits)
  resdf
}

# rescale Google Trends index in range 0-1000
rescale_index1000 = function(rankdf){
  rankdf = rankdf[,c('term','hits')]
  # add 0 value if needed
  if (min(rankdf$hits)>0){
    rankdf = rbind(rankdf, data.frame(term=NA, hits=0))
  }
  stopifnot(min(rankdf$hits)==0)
  rankdf$hits1000 = round( 
    rescale( rankdf$hits, to = c(min(rankdf$hits), 1000) ), DIGITS)
  names(rankdf)[2] = 'scaled_hits'
  rankdf = rankdf[!is.na(rankdf$term), ]
  rankdf
}

# Main algorithm
compare_google_trends_terms = function( comptermdf ){
  # combine results into a single ranking of terms
  comptermdf = sort_df(comptermdf,'hits_ab_sum',asc = F)
  comptermdf$term_a = as.character(comptermdf$term_a)
  comptermdf$term_b = as.character(comptermdf$term_b)
  
  queries_todo = as.character(comptermdf$query)
  rankdf = data.frame()
  i = 0
  while(length(queries_todo)>0){
    i=i+1
    q = head(queries_todo,1)
    queries_todo = tail(queries_todo,length(queries_todo)-1)
    querydf = comptermdf[comptermdf$query==q, ]
    stopifnot(nrow(querydf)==1)
    #View(querydf)
    if (nrow(rankdf)==0){
      # add first pair
      rankdf = data.frame( term=c(querydf$term_a, querydf$term_b), 
                           hits = c(querydf$hits_a,querydf$hits_b),
                           source_query = q,
                           original_hits = c(querydf$hits_a,querydf$hits_b),
                           base_term = T)
      
      next()
    }
    afound = querydf$term_a %in% rankdf$term
    bfound = querydf$term_b %in% rankdf$term
    if (!afound & !bfound){
      # missing link, re-add term to end of the list
      queries_todo = c(queries_todo,q)
      next()
    }
    # if term_a is present, rescale term b
    if (afound & !bfound){
      baseIdx = rankdf[rankdf$term == querydf$term_a,'hits']
      transIdx = transform_gtrends_idx(baseIdx, querydf$hits_a, querydf$hits_b )
      rankdf = rbind(rankdf, data.frame(term=querydf$term_b,
                                        hits=transIdx,
                                        source_query=q,
                                        original_hits=querydf$hits_b,
                                        base_term = F))
    }
    
    # if term_b is present, rescale term a
    if (bfound & !afound){
      baseIdx = rankdf[rankdf$term == querydf$term_b,'hits']
      transIdx = transform_gtrends_idx(baseIdx, querydf$hits_b, querydf$hits_a )
      rankdf = rbind(rankdf, data.frame(term=querydf$term_a,
                                        hits=transIdx,
                                        source_query=q,
                                        original_hits=querydf$hits_a,
                                        base_term = F))
    }
    
    if (afound & bfound){
      # nothing to do
    }
  }
  print(paste(i,'iterations'))
  
  debug_fn = 'output/google_trends_comparison_df_debug.rds'
  saveRDS(rankdf,debug_fn)
  print(paste('Debug dataset written in',debug_fn))
  
  # rescale results in range [min, 1000]
  simplrankdf = rescale_index1000(rankdf)
  simplrankdf
}


# Main ------

# read terms from file
search_terms = trimws(scan(INPUT_TERMS, character(), quote = "", sep = '\n'))
print(paste("Loaded terms from",INPUT_TERMS))
print(search_terms)

term_pairs = get_all_pairs( sort(unique(search_terms)) )

print("Retrieve Google Trends data from API")
resdf = call_gtrends_api_for_pairs( term_pairs, TIME_SPAN, geoscope = '' )

# save results
bin_df_fn = 'output/gtrends_raw_results_df_debug.rds'
saveRDS(resdf,bin_df_fn)
rm(resdf)

# read & analyse results
gtrendsdf = readRDS(bin_df_fn)

# summarise results over time in a single value
termsummarydf = foreach_group_in_df(gtrendsdf, c('query','keyword'), function(block){
    row = data.frame(
      query = unique(block$query),
      keyword = unique(block$keyword),
      term = ifelse( unique(block$term1b), 'a', 'b'),
      hits_mean = round(mean(block$hits,na.rm = T),DIGITS),
      hits_sd = round(sd(block$hits,na.rm = T),DIGITS),
      hits_median = median(block$hits,na.rm = T),
      hits_max = max(block$hits,na.rm = T),
      hits_sum = round(sum(block$hits,na.rm = T),DIGITS),
      date_range = paste(min(block$date),max(block$date))
    )
    row
})
termsummarydf = sort_df(termsummarydf,'query')
#View(termsummarydf)
#saveRDS(resdf,bin_df_fn)

# compare terms a and b
comptermdf = foreach_group_in_df(termsummarydf, c('query'), function(block){
  stopifnot(nrow(block)==2)
  hits_metric = 'hits_mean'
  row = data.frame(
    query = unique(block$query)
  )
  if (block[1,hits_metric] > block[2,hits_metric]){
    row$term_a = block[1,'keyword']
    row$term_b = block[2,'keyword']
    row$hits_a = block[1,hits_metric]
    row$hits_b = block[2,hits_metric]
  } else {
    row$term_a = block[2,'keyword']
    row$term_b = block[1,'keyword']
    row$hits_a = block[2,hits_metric]
    row$hits_b = block[1,hits_metric]
  }
  row$diff = row$hits_a - row$hits_b
  row$diff_abs = abs(row$diff)
  row$hits_ab_sum = row$hits_a + row$hits_b
  stopifnot(row$diff>=0)
  row$weak_signal = row$hits_a < MIN_INDEX | row$hits_b < MIN_INDEX
  row$date_range = unique(block$date)
  row
})

# call main algorithm
print('Compare and rescale index')
termrank_df = compare_google_trends_terms(comptermdf)
termrank_df$collected_at = CUR_DATE
termrank_df$time_span = paste(min(gtrendsdf$date),max(gtrendsdf$date))
#View(termrank_df)

stopifnot( length(search_terms) == nrow(termrank_df) )

# write results for user
result_fn = 'output/google_trends_scaled_index.csv'
write.csv(termrank_df, result_fn, row.names = F,na = '')
print(paste("Results written in",result_fn))

print("OK")
