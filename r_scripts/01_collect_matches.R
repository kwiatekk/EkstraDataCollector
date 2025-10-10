#!/usr/bin/env Rscript
# ============================================
# FIX: Windows R_USER - MUSI BYĆ NA POCZĄTKU!
# ============================================
if (Sys.getenv("R_USER") == "") {
  Sys.setenv(R_USER = path.expand("~"))
  Sys.setenv(HOME = path.expand("~"))
}

suppressPackageStartupMessages({
  library(worldfootballR)
  library(dplyr)
  library(jsonlite)
})

cat("\n⚽ [1/12] Zbieranie wyników meczów (FBref)...\n")

SEASON_END <- as.numeric(Sys.getenv("SEASON_END", "2026"))
COUNTRY <- "POL"
output_file <- file.path("data", "match_results.json")

tryCatch({
  matches <- fb_match_results(
    country = COUNTRY,
    gender = "M",
    season_end_year = SEASON_END,
    tier = "1st"
  )
  
  matches <- matches %>%
    mutate(
      collected_at = Sys.time(),
      source = "FBref",
      season = paste0(SEASON_END - 1, "/", SEASON_END)
    )
  
  write_json(matches, output_file, pretty = TRUE, auto_unbox = TRUE, na = "null")
  cat(sprintf("✅ Zapisano %d meczów\n", nrow(matches)))
  
}, error = function(e) {
  cat(sprintf("❌ BŁĄD: %s\n", e$message))
  quit(status = 1)
})
