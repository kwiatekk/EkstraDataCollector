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

cat("\n🏆 [2/12] Zbieranie tabeli ligowej (FBref)...\n")

SEASON_END <- as.numeric(Sys.getenv("SEASON_END", "2026"))
COUNTRY <- "POL"
output_file <- file.path("data", "standings.json")

tryCatch({
  standings <- fb_season_team_stats(
    country = COUNTRY,
    gender = "M",
    season_end_year = SEASON_END,
    tier = "1st",
    stat_type = "league_table"
  )
  
  standings <- standings %>%
    mutate(
      collected_at = Sys.time(),
      source = "FBref",
      season = paste0(SEASON_END - 1, "/", SEASON_END)
    ) %>%
    arrange(Rk)
  
  write_json(standings, output_file, pretty = TRUE, auto_unbox = TRUE)
  cat(sprintf("✅ Zapisano tabelę (%d drużyn)\n", nrow(standings)))
  
}, error = function(e) {
  cat(sprintf("❌ BŁĄD: %s\n", e$message))
  quit(status = 1)
})
