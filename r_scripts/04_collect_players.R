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

cat("\n👥 [4/12] Zbieranie wartości zawodników (Transfermarkt)...\n")

LEAGUE_URL <- "https://www.transfermarkt.com/ekstraklasa/startseite/wettbewerb/PL1"
SEASON <- 2025
output_file <- file.path("data", "players.json")

tryCatch({
  # Pobierz listę drużyn
  team_urls <- tm_league_team_urls(league_url = LEAGUE_URL, start_year = SEASON)
  
  cat(sprintf("Znaleziono %d drużyn\n", length(team_urls)))
  
  all_players <- list()
  
  for (i in seq_along(team_urls)) {
    cat(sprintf("  [%d/%d]\n", i, length(team_urls)))
    
    # Użyj tm_squad_stats() - zwraca statystyki zawodników + wartości rynkowe
    players <- tryCatch({
      tm_squad_stats(team_url = team_urls[i])
    }, error = function(e) {
      cat(sprintf("    ⚠️ Błąd: %s\n", e$message))
      NULL
    })
    
    if (!is.null(players) && nrow(players) > 0) {
      players$scraped_date <- as.character(Sys.Date())
      all_players[[length(all_players) + 1]] <- players
    }
    
    Sys.sleep(5)
  }
  
  players_df <- if (length(all_players) > 0) bind_rows(all_players) else data.frame()
  
  if (nrow(players_df) > 0) {
    write_json(players_df, output_file, pretty = TRUE, auto_unbox = TRUE)
    cat(sprintf("✅ Zapisano %d zawodników\n", nrow(players_df)))
  } else {
    cat("❌ Brak zawodników\n")
    quit(status = 1)
  }
  
}, error = function(e) {
  cat(sprintf("❌ BŁĄD: %s\n", e$message))
  quit(status = 1)
})
