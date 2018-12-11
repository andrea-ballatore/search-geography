Google Trends comparator for 5+ terms
=============================================

Authors: [Andrea Ballatore](http://aballatore.space), with contributions from [Simon Scheider](http://www.geographicknowledge.de)

**Keywords:** Internet geography, search engines, Google Trends, R

Dependent on R packages: `gtrendsR`, `foreach`, `iterators`, `scales`.

## Abstract

The `gtrends_compare_terms.R` script takes a list of search terms in `input/search_terms.txt`
and generates a Google Trends index rescaled in 0 and 1000.
The tool overcomes the limitation of Google Trends to 5 terms, supporting an arbitrary
number of terms.

The results are written in CSV format in the `output` folder.

For debugging purposes, the script also produces rds files with the complete dataset.

For example, for 10 terms Austria, Belgium, Cyprus, Denmark, Estonia, Finland, 
Germany, Greece, Hungary, and Italy,
the script produces this table, where `scaled_hits` is the Google Trends index, 
and `hits1000` is the same value rescaled between 0 and 1000 for readability.
Note that hits is the *average of the Google Trends index* in the selected `time_span`.

| term    | scaled_hits | hits1000 | collected_at     | time_span             |
|---------|-------------|----------|------------------|-----------------------|
| Austria | 101.9617    | 324.2405 | 2018-12-11 11:22 | 2017-12-17 2018-12-02 |
| Belgium | 123.5705    | 392.957  | 2018-12-11 11:22 | 2017-12-17 2018-12-02 |
| Cyprus  | 74.1176     | 235.6956 | 2018-12-11 11:22 | 2017-12-17 2018-12-02 |
| Denmark | 76.9148     | 244.5908 | 2018-12-11 11:22 | 2017-12-17 2018-12-02 |
| Estonia | 19.8276     | 63.0522  | 2018-12-11 11:22 | 2017-12-17 2018-12-02 |
| Finland | 53.7647     | 170.9729 | 2018-12-11 11:22 | 2017-12-17 2018-12-02 |
| Germany | 314.4632    | 1000     | 2018-12-11 11:22 | 2017-12-17 2018-12-02 |
| Greece  | 151.9191    | 483.1061 | 2018-12-11 11:22 | 2017-12-17 2018-12-02 |
| Hungary | 35.1315     | 111.719  | 2018-12-11 11:22 | 2017-12-17 2018-12-02 |
| Italy   | 299.5809    | 952.674  | 2018-12-11 11:22 | 2017-12-17 2018-12-02 |


## License

This work is licensed under a Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.

