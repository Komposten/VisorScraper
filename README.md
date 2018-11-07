# VisorScraper
### What is VisorScraper?
**VisorScraper has been (temporarily?) discontinued due to Visor.gg completely re-working their platform.**

VisorScraper is a R-based tool that scrapes Overwatch match data from [Visor.gg](https://visor.gg). Visor.gg itself does not currently provide a way to view data from multiple matches at once in a convenient way (e.g. as graphs of stats vs. date), nor does it provide an API to easily access match data. This tool automatically scrapes match data from all matches present on your Visor Dashboard and compiles it into a number of tables (one with overall match data for each match, and one for each hero and match).
### How do I use VisorScraper?
**NOTE: Downloading data from Visor requires permission from the Visor team. See their [Terms of Use](https://docsend.com/view/8ade7sa) for more information.**

#### First time
1) Download required files:
   1) [Download and install R](https://cran.r-project.org)
   2) Install the R packages [scrapeR](https://cran.r-project.org/web/packages/scrapeR/index.html), [magrittr](https://cran.r-project.org/web/packages/magrittr/index.html), [jsonlite](https://cran.r-project.org/web/packages/jsonlite/index.html) and [plyr](https://cran.r-project.org/web/packages/plyr/index.html):
		```R
    	install.packages(c("scrapeR", "magrittr", "jsonlite", "plyr"))
    	```
   3) Download [visor_scraper.R](https://github.com/Komposten/VisorScraper/blob/master/visor_scraper.R) from this repository.
2) Download your Visor.gg dashboard.
   1) Go to your [Visor.gg dashboard](https://visor.gg/visor/dashboard).
   2) *Keep scrolling down* until all matches you want to scrape have been loaded.
   3) Press Ctrl+S (or equivalent) and save the website HTML to your computer.
3) Set up VisorScraper
   1) Open visor_scraper.R and scroll to the bottom.
   2) Replace `files/Visor.gg.html` with the path to your downloaded HTML file (the path can be absolute or relative to your R working directory). If you are on Windows, use `/` instead of `\`.
   3) Replace `output/` with a path to a folder you want output files to be created in, or `NULL` if you don't want VisorScraper to create any files (i.e. the data is only available in your R environment).
4) Run VisorScraper
   1) Open R and `source()` visor_scraper.R.
5) Find the scraped data
   1) If you specified an output folder, it should now contain a number of .csv files.
   2) Additionally, the data is also stored in the R environment under the variables `match.stats` and `hero.stats`.
6) Save your R workspace!

#### Adding new matches
1) Load your previously saved R workspace, containing the VisorScraper data (raw.stats, match.stats and hero.stats).
2) Download your Visor.gg dashboard as before. This time it *only* needs to contain the new matches.
3) Run VisorScraper. It will automatically merge the new data with your previous one. Previously downloaded matches (if present in the HTML file) will not be re-downloaded.
   
#### Why must I download the Visor Dashboard HTML?
This is an easy way to get access to a list of all matches that a user wants to scrape.

It should be possible to let VisorScraper itself sign in to Visor.gg and scrape the Dashboard. However, I don't know exactly how to do this or if it is worth the trouble. This is especially because of the fact that Visor.gg's dashboard only loads 20 matches at first, and then requires you to scroll down for it to load further. I don't know if this can be achieved programmatically using R.

### Other useful information
* VisorScraper works in a single thread and waits 0.1 second between each match, as to not spam Visor.gg with too many requests.
* Matches that cannot be opened (e.g. because of server errors) and matches without stats (i.e. Visor messed up) will be ignored.
* SR cannot currently be scraped in a reasonable way since Visor.gg does not store SR per match.

### License
This is free and unencumbered software released into the public domain. See [LICENSE](https://github.com/Komposten/VisorScraper/blob/master/LICENSE) for more information.
