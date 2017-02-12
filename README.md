Search Engine Geography
=============================================
This repository contains datasets produced for the study described in:

Andrea Ballatore, Mark Graham, Shilad Sen (2017) *Digital Hegemonies: The localness of search engine results*, Annals of the American Association of Geographers

## Abstract

Every day, billions of Internet users rely on search engines to find information about places to make decisions about tourism, shopping, and countless other economic activities. In an opaque process, search engines assemble digital content produced in a variety of locations around the world and make it available to large cohorts of consumers. Although these representations of place are increasingly important and consequential, little is known about their characteristics and possible biases. Analysing a corpus of Google search results generated for 188 capital cities, this article investigates the geographic dimension of search results, focusing on searches such as "Lagos" and "Rome" on different localized versions of the engine. This study answers the questions: To what degree is this city-related information locally produced and diverse? Which countries are producing their own representations and which are represented by others? Through a new indicator of localness of search results, we identify the factors that contribute to shape this uneven digital geography, combining several development indicators. The development of the publishing industry and scientific production appears as a fairly strong predictor of localness of results. This empirical knowledge will support efforts to curb the digital divide, promoting a more inclusive, democratic information society.

**Keywords:** Internet geography, search engines, Google, localness, digital place

## Datasets

**google_localness_dataset_summary.csv:** Summary of localness results.

`country_code`: ISO country code

`country_name`: Country name

`US_mean_L`: Mean localess of US Google results

`US_mean_L_SD`: Standard deviation of localness of US Google results

`US_prob_L`: Probability of correct localness of US Google results

`US_diversity`: Diversity of US Google results

`LOCAL_mean_L`: Mean localess of Local Google results

`LOCAL_mean_L_SD`: Standard deviation of localness of Local Google results

`LOCAL_prob_L`: Probability of correct localness of Local Google results

`LOCAL_diversity`: Diversity of Local Google results

**google_localness_dataset_detail.csv:** Details of localness results.

`QUERY_COUNTRY, QUERY_COUNTRY_ISO3, QUERY_COUNTRY_NAME`: Country name and ISO codes

`ENGINE_VER`: Version of search engine

`LANG`: Query language ISO codes

`LOCAL`: Local or US Google (True or False)

`LANG_IS_LOCAL`: Language is local (True or False)

`QUERY`: Query text

`SEARCH_URL`: Query full URL

`RESULTS_N`: Number of results

`LOCALNESS_IDX_MEAN, LOCALNESS_IDX_SD, LOCALNESS_IDX_PROB_MEAN, LOCALNESS_IDX_PROB_SD`: Localness of results

`URLS_SHANNON_DIVERSITY`: Diversity of results

`URLS_TOP_COUNTRY`: Dominant country in results

`URLS_COUNTRY_COUNT`: Number of countries in results

`REGION, INCOME`: Country classification (World Bank)

`GDP_PPP, GDPPC_PPP, POP`: Country GDP and population (World Bank)

`INT_USERS, INT_BROADBAND, INT_SERVERS`: Country internet usage (World Bank)

`TOUR_RECEIPT, TOUR_ARRIVALS`: Tourism information (World Bank)

`Documents, Citable_documents, Citations, Self_Citations, Citations_per_Document, H_index`: Academic publishing information (SciMago)

**google_localness_maps.pdf:** High-resolution maps.
