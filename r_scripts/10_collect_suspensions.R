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

cat("\n⚠️ [10/12] Zbieranie zawieszeń...\n")

LEAGUE_URL <- "https://www.transfermarkt.com/ekstraklasa/startseite/wettbewerb/PL1"
output_file <- file.path("data", "suspensions.json")

tryCatch({
  suspensions <- tryCatch({
    tm_get_suspensions(league_url = LEAGUE_URL)
  }, error = function(e) {
    cat("    ⚠️ Nie można pobrać zawieszeń\n")
    data.frame()
  })
  
  risk_suspension <- tryCatch({
    tm_get_risk_of_suspension(league_url = LEAGUE_URL)
  }, error = function(e) {
    cat("    ⚠️ Nie można pobrać zagrożonych zawieszeniem\n")
    data.frame()
  })
  
  suspensions_combined <- list(
    suspended = if(!is.null(suspensions) && nrow(suspensions) > 0) suspensions else list(),
    at_risk = if(!is.null(risk_suspension) && nrow(risk_suspension) > 0) risk_suspension else list(),
    scraped_date = as.character(Sys.Date())
  )
  
  write_json(suspensions_combined, output_file, pretty = TRUE, auto_unbox = TRUE)
  cat(sprintf("✅ Zawieszeni: %d | Zagrożeni: %d\n", 
              ifelse(is.data.frame(suspensions), nrow(suspensions), 0),
              ifelse(is.data.frame(risk_suspension), nrow(risk_suspension), 0)))
  
}, error = function(e) {
  cat(sprintf("❌ BŁĄD: %s\n", e$message))
  write_json(list(error = e$message, scraped_date = as.character(Sys.Date())), output_file, pretty = TRUE)
  quit(status = 1)
})
