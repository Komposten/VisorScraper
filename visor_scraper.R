scrape.matches <- function(dashboardHtmlFile)
{
	require(scrapeR)
	require(magrittr)
	
	matches <- scrape(file = dashboardHtmlFile, parse = T) %>% {getNodeSet(doc = .[[1]], path = "//div[@class=\"_2-e0X\"]/div[3]/div[position()>1]/a/@href")}
	
	paste0("Scraping data from ", length(matches), " matches!") %>% message
	match.data <- lapply(seq_along(matches), FUN = function(index) 
    {
	    url <- matches[[index]]
  	  paste0("Scraping match ", url, " [", index, "/", length(matches), "]") %>% print
	    scrape.match(url)
	  })
	names(match.data) <- matches
	
	match.data <- match.data[lapply(match.data, length) > 0] %>% 	# Remove all empty list elements (invalid matches)
	{.[lapply(., function(x) { x$match$heroes %>% length}) > 0 ]}	# Remove matches with no heroes (i.e. broken matches)
		
	paste0("Successfully scraped ",
				 length(match.data),
				 " matches (",
				 length(matches) - length(match.data),
				 " were invalid or broken)\n") %>%
		message
	
	return(match.data)
}


scrape.match <- function(url)
{
	require(jsonlite)
	require(magrittr)
	
	Sys.sleep(0.1)
	
	dom <- scrape(url = url, parse = T)
	
	if (getNodeSet(doc = dom[[1]], path = "//title", fun = xmlValue) %>% trimws %>% length == 0)
	{
		warning("Invalid match: ", url, " (broken URL, or the server is unreachable)")
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
				result = x$result,
				impact_score = x$impact_score,
				teamplay_score = x$teamplay_score,
				ultimate_score = x$ultimate_score,
				ults = x$ults_used)
		}) %>%
		do.call("rbind", .) %>% # rbind everything into a single data frame
		return
}


# filter.hero <- function(heroName, match.data)
# {
# 	if (!is.character(heroName))
# 	{
# 		stop("heroName must be a character!")
# 	}
# 	
# 	per.hero <- lapply(match.data, function(x)
# 		{
# 			date.full = data.frame(date_and_time = rep(x$match$created_at, times = nrow(x$heroStats)))
# 			date.short = data.frame(date = date.full[,1] %>% as.Date)
# 			days.since.first.match = data.frame(days_since_first_match = date.full[,1] %>% make.relative(match.data))
# 			cbind(date.full, date.short, days.since.first.match, x$heroStats)
# 		})
# 		
# 	lapply(per.hero, FUN = function(x) x[x$hero == heroName,]) %>%		# Remove all rows rows with the wrong heroName
# 		{.[lapply(., nrow) > 0]} %>%														# Remove all matches where the specified hero wasn't played (i.e. no rows)
# 		lapply(FUN = flatten) %>%																# Flatten the nested data frames (required for rbind to work)
# 		lapply(FUN = function(x) x[, !is.na(x[1,])]) %>%				# Remove all NA values (hero-specific stats for other heroes)
# 		do.call("rbind", .) %>%																	# rbind everything into a single data frame
# 		return
# }


filter.heroes <- function(match.data)
{
  require(plyr)
  
  # Extract the hero stats and prepend date information
  per.hero <- lapply(match.data, function(x)
  {
    date.full = data.frame(date_and_time = rep(x$match$created_at, times = nrow(x$heroStats)))
    date.short = data.frame(date = date.full[,1] %>% as.Date)
    days.since.first.match = data.frame(days_since_first_match = date.full[,1] %>% make.relative(match.data))
    cbind(date.full, date.short, days.since.first.match, x$heroStats)
  }) %>%
    lapply(FUN = flatten)	# Flatten the nested data frames (required for rbind to work)
  
  heroes <- list()
  
  # Go through all heroes in each match and add them to their respective data frames in the heroes list.
  for (i in seq_along(per.hero))
  {
    match.name = names(per.hero[i])
    hero.data = per.hero[[i]]
    
    for (row in 1:nrow(hero.data))
    {
      row.data <- cbind(match_name = match.name, hero.data[row,])
      hero.name <- as.character(row.data["hero"])
      
      df <- heroes[[hero.name]]
      
      if (is.null(df))
      {
        df <- as.data.frame(row.data)
      }
      else
      {
        df <- rbind.fill(df, row.data)
      }
      
      heroes[[hero.name]] <- df
    }
  }
  
  lapply(heroes, FUN = function(x) x[, !is.na(x[1,])]) %>% return # Remove NA columns and return.
}


make.relative <- function(visor.date, match.data)
{
	dates <- sapply(match.data, FUN = function(x) x$match$created_at %>% as.Date) %>% {.[order(.)]}
	
	as.numeric(as.Date(visor.date)) - dates[1] %>% return
}


scrape.match.data <- function(dashboardFile, outputFolder = NULL)
{
	message("Starting scraping job...")
	matches <- scrape.matches(dashboardFile)
	assign("raw.stats", matches, pos = globalenv())
	
	message("Extracting match stats...")
	match.stats <<- filter.global.stats(matches)
	
	message("Extracting hero-specific stats...")
	hero.stats = filter.heroes(matches)
	assign("hero.stats", hero.stats, pos = globalenv())
	
	if (!is.null(outputFolder))
	{
		message(paste0("Saving to files in folder \"", outputFolder, "\""))
		
		dir.create(outputFolder)
		write.table(match.stats, file = paste0(outputFolder, "match.stats.csv"), quote = F, sep = ",", row.names = T, col.names = T)
		sapply(hero.stats, FUN = function(x)
			{
				hero <- x$hero[1]
				write.table(x, file = paste0(outputFolder, hero, ".csv"), quote = F, sep = ",", row.names = T, col.names = T)
			})
	}
	
	message("\nScraping job finished!")
	message(paste0("A total of ", nrow(match.stats), " matches were scraped. ",
	               "Data is available for the following heroes:"))
	sapply(names(hero.stats), function(x)
	  {
	    message(paste0("  ", x, ": ", hero.stats[[x]] %>% nrow, " matches"))
	  })
	message("\nThe data has been stored in two variables: match.stats (data frame) and hero.stats (list with one data frame per hero).")
	if (!is.null(outputFolder))
	{
		message(paste0("It has also been written to files in the folder \"", outputFolder, "\".\n"))
	}
}

scrape.match.data("files/Visor.gg.html", "output/")
