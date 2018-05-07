scrape.matches <- function(dashboardHtmlFile)
{
	require(scrapeR)
	require(magrittr)
	
	matches <- scrape(file = dashboardHtmlFile, parse = T) %>% {getNodeSet(doc = .[[1]], path = "//div[@class=\"_2-e0X\"]/div[3]/div[position()>1]/a/@href")}
	
	paste0("Scraping data from ", length(matches), " matches!") %>% message
	match.data <- lapply(matches, FUN = scrape.match)
	names(match.data) <- matches
	
	match.data <- match.data[lapply(match.data, length) > 0] %>% 	# Remove all empty list elements (invalid matches)
	{.[lapply(., function(x) { x$match$heroes %>% length}) > 0 ]}	# Remove matches with no heroes (i.e. broken matches)
		
	paste0("Successfully scraped ",
				 length(match.data),
				 " matches (",
				 length(matches) - length(match.data),
				 " were invalid or broken)") %>%
		message
	
	return(match.data)
}


scrape.match <- function(url)
{
	require(jsonlite)
	require(magrittr)
	
	paste0("Scraping match ", url) %>% print
	
	Sys.sleep(0.1)
	
	dom <- scrape(url = url, parse = T)
	
	if (getNodeSet(doc = dom[[1]], path = "//title", fun = xmlValue) %>% trimws %>% length == 0)
	{
		warning("Invalid match: ", url)
		return(data.frame())
	}
	
	properties.json <- getNodeSet(doc = dom[[1]], path = "//div[@data-react-class=\"OWMatchApp\"]/@data-react-props")
	properties.r <- fromJSON(txt = as.character(properties.json))
}


filter.global.stats <- function(match.data)
{
	global.stats <- lapply(match.data, function(x) x$match)
	
	lapply(global.stats, FUN = function(x) # Grab the interesting data
		{
			data.frame(
				date_and_time = x$created_at,
				date = x$created_at %>% as.Date,
				days_since_first_match = make.relative(x$created_at, match.data),
				sr = x$user$overwatch_sr,
				impact_score = x$impact_score,
				teamplay_score = x$teamplay_score,
				ultimate_score = x$ultimate_score,
				ults = x$ults_used)
		}) %>%
		do.call("rbind", .) %>% # rbind everything into a single data frame
		return
}


filter.hero <- function(heroName, match.data)
{
	if (!is.character(heroName))
	{
		stop("heroName must be a character!")
	}
	
	per.hero <- lapply(match.data, function(x)
		{
			date.full = data.frame(date_and_time = rep(x$match$created_at, times = nrow(x$heroStats)))
			date.short = data.frame(date = date.full[,1] %>% as.Date)
			days.since.first.match = data.frame(days_since_first_match = date.full[,1] %>% make.relative(match.data))
			cbind(date.full, date.short, days.since.first.match, x$heroStats)
		})
		
	lapply(per.hero, FUN = function(x) x[x$hero == heroName,]) %>%		# Remove all rows rows with the wrong heroName
		{.[lapply(., nrow) > 0]} %>%														# Remove all matches where the specified hero wasn't played (i.e. no rows)
		lapply(FUN = flatten) %>%																# Flatten the nested data frames (required for rbind to work)
		lapply(FUN = function(x) x[, !is.na(x[1,])]) %>%				# Remove all NA values (hero-specific stats for other heroes)
		do.call("rbind", .) %>%																	# rbind everything into a single data frame
		return
}


make.relative <- function(visor.date, match.data)
{
	dates <- sapply(match.data, FUN = function(x) x$match$created_at %>% as.Date) %>% {.[order(.)]}
	
	as.numeric(as.Date(visor.date)) - dates[1] %>% return
}


scrape.match.data <- function(dashboardFile, heroes, outputFolder = NULL)
{
	# TODO Look for all heroes by default, don't save anything for those that have no matches.
	# TODO At the end, print the total number of scraped matches, as well as the number each hero was found in.
	# TODO Possibly rewrite the "filter.hero" function to handle all heroes at once (create data frames -> for each match move the hero data to the correct df's)
	
	message("Starting scraping job...")
	matches <- scrape.matches(dashboardFile)
	
	message("Extracting match stats...")
	match.stats <<- filter.global.stats(matches)
	
	message("Extracting hero-specific stats...")
	hero.stats <- sapply(heroes, FUN = function(x)
		{
			stats <- filter.hero(x, matches)
			assign(x, stats, pos = globalenv())
		})
	
	if (!is.null(outputFolder))
	{
		message(paste0("Saving to files in folder ", outputFolder))
		
		dir.create(outputFolder)
		write.table(match.stats, file = paste0(outputFolder, "match.stats.csv"), quote = F, sep = ",", row.names = T, col.names = T)
		sapply(hero.stats, FUN = function(x)
			{
				hero <- x$hero[1]
				write.table(x, file = paste0(outputFolder, hero, ".csv"), quote = F, sep = ",", row.names = T, col.names = T)
			})
	}
	
	message("Scraping job finished!")
	message(paste0("Data has been stored in these variables: match.stats, ", paste(heroes, sep = ", ", collapse = ", ")), ".")
	if (!is.null(outputFolder))
	{
		message(paste0("It has also been written to files with the same names in the folder ", outputFolder, "."))
	}
}


scrape.match.data("files/Visor.gg.html", c("mercy", "ana"), "output/")