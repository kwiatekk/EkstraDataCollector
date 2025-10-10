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

cat("\n🚑 [6/12] Zbieranie kontuzji (Transfermarkt)...\n")

LEAGUE_URL <- "https://www.transfermarkt.com/ekstraklasa/startseite/wettbewerb/PL1"
output_file <- file.path("data", "injuries.json")

tryCatch({
  injuries <- tm_league_injuries(league_url = LEAGUE_URL)
  
  if (!is.null(injuries) && nrow(injuries) > 0) {
    injuries$scraped_date <- as.character(Sys.Date())
    write_json(injuries, output_file, pretty = TRUE, auto_unbox = TRUE)
    cat(sprintf("✅ Zapisano %d kontuzji\n", nrow(injuries)))
  } else {
    cat("ℹ️ Brak aktualnych kontuzji\n")
    write_json(list(scraped_date = as.character(Sys.Date())), output_file, pretty = TRUE)
  }
  
}, error = function(e) {
  cat(sprintf("⚠️ BŁĄD: %s\n", e$message))
  write_json(list(error = e$message, scraped_date = as.character(Sys.Date())), output_file, pretty = TRUE)
})
