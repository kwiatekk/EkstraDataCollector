#!/usr/bin/env Rscript
if (Sys.getenv("R_USER") == "") {
  Sys.setenv(R_USER = path.expand("~"))
  Sys.setenv(HOME = path.expand("~"))
}

options(download.file.method = "libcurl")
options(url.method = "libcurl")

suppressPackageStartupMessages({
  library(worldfootballR)
  library(dplyr)
  library(jsonlite)
})

cat("\n🔄 [5/12] Zbieranie transferów (Transfermarkt)...\n")

LEAGUE_URL <- "https://www.transfermarkt.com/ekstraklasa/startseite/wettbewerb/PL1"
SEASON <- 2025
output_file <- file.path("data", "transfers.json")

tryCatch({
  team_urls <- tm_league_team_urls(league_url = LEAGUE_URL, start_year = SEASON)
  
  cat(sprintf("Znaleziono %d drużyn\n", length(team_urls)))
  
  all_transfers <- list()
  
  for (i in seq_along(team_urls)) {
    cat(sprintf("  [%d/%d]\n", i, length(team_urls)))
    
    transfers <- tryCatch({
      tm_team_transfers(team_url = team_urls[i], transfer_window = "all")
    }, error = function(e) {
      cat(sprintf("    ⚠️ Błąd: %s\n", e$message))
      NULL
    })
    
    if (!is.null(transfers) && nrow(transfers) > 0) {
      transfers$season <- paste0(SEASON, "/", SEASON+1)
      transfers$scraped_date <- as.character(Sys.Date())
      all_transfers[[length(all_transfers) + 1]] <- transfers
    }
    
    Sys.sleep(5)
  }
  
  transfers_df <- if (length(all_transfers) > 0) bind_rows(all_transfers) else data.frame()
  
  if (nrow(transfers_df) > 0) {
    write_json(transfers_df, output_file, pretty = TRUE, auto_unbox = TRUE)
    cat(sprintf("✅ Zapisano %d transferów\n", nrow(transfers_df)))
  } else {
    cat("ℹ️ Brak transferów w tym sezonie\n")
    write_json(list(scraped_date = as.character(Sys.Date())), output_file, pretty = TRUE)
  }
  
}, error = function(e) {
  cat(sprintf("❌ BŁĄD: %s\n", e$message))
  quit(status = 1)
})
