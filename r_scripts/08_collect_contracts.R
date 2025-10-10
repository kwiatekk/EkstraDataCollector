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

cat("\n📝 [8/12] Zbieranie kontraktów...\n")

LEAGUE_URL <- "https://www.transfermarkt.com/ekstraklasa/startseite/wettbewerb/PL1"
CONTRACT_YEAR <- 2026
output_file <- file.path("data", "contracts.json")

tryCatch({
  contracts <- tm_expiring_contracts(
    country_name = "",
    league_url = LEAGUE_URL,
    contract_end_year = CONTRACT_YEAR
  )
  
  if (!is.null(contracts) && nrow(contracts) > 0) {
    contracts$scraped_date <- as.character(Sys.Date())
    write_json(contracts, output_file, pretty = TRUE, auto_unbox = TRUE)
    cat(sprintf("✅ Zapisano %d kontraktów wygasających w roku %d\n", nrow(contracts), CONTRACT_YEAR))
  } else {
    cat(sprintf("ℹ️ Brak kontraktów wygasających w roku %d\n", CONTRACT_YEAR))
    write_json(list(scraped_date = as.character(Sys.Date())), output_file, pretty = TRUE)
  }
  
}, error = function(e) {
  cat(sprintf("❌ BŁĄD: %s\n", e$message))
  write_json(list(error = e$message, scraped_date = as.character(Sys.Date())), output_file, pretty = TRUE)
  quit(status = 1)
})
