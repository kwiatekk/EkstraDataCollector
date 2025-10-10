#!/usr/bin/env Rscript
if (Sys.getenv("R_USER") == "") {
  Sys.setenv(R_USER = path.expand("~"))
  Sys.setenv(HOME = path.expand("~"))
}

suppressPackageStartupMessages({
  library(worldfootballR)
  library(dplyr)
  library(jsonlite)
})

cat("\n🎯 [3/12] Zbieranie statystyk xG (FBref)...\n")

SEASON_END <- as.numeric(Sys.getenv("SEASON_END", "2026"))
COUNTRY <- "POL"
output_file <- file.path("data", "xg.json")

tryCatch({
  xg_stats <- fb_season_team_stats(
    country = COUNTRY,
    gender = "M",
    season_end_year = SEASON_END,
    tier = "1st",
    stat_type = "shooting"
  )
  
  xg_stats <- xg_stats %>%
    mutate(collected_at = Sys.time(), source = "FBref")
  
  write_json(xg_stats, output_file, pretty = TRUE, auto_unbox = TRUE)
  cat(sprintf("✅ Zapisano xG (%d drużyn)\n", nrow(xg_stats)))
  
}, error = function(e) {
  cat(sprintf("❌ BŁĄD: %s\n", e$message))
  quit(status = 1)
})
