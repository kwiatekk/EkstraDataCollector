#!/usr/bin/env Rscript
if (Sys.getenv("R_USER") == "") {
  Sys.setenv(R_USER = path.expand("~"))
  Sys.setenv(HOME = path.expand("~"))
}

suppressPackageStartupMessages({
  library(dplyr)
  library(jsonlite)
})

cat("\n📈 [12/12] Trend wartości ligi...\n")

players_file <- file.path("data", "players.json")
output_file <- file.path("data", "league_value_trend.json")
cache_file <- file.path("data", "ekstraklasa_clubs_cache.json")
SEASON <- 2025

tryCatch({
  if (!file.exists(players_file)) {
    stop("Brak players.json")
  }
  
  players_df <- fromJSON(players_file)
  
  # Znajdź kolumnę z wartością rynkową
  value_col <- NULL
  for (col in c("player_market_value_euro", "market_value_euro", "player_market_value", "market_value")) {
    if (col %in% colnames(players_df)) {
      value_col <- col
      break
    }
  }
  
  # Znajdź kolumnę z klubem
  club_col <- NULL
  for (col in c("player_club", "club", "Club", "Squad", "Team")) {
    if (col %in% colnames(players_df)) {
      club_col <- col
      break
    }
  }
  
  if (nrow(players_df) > 0 && !is.null(value_col)) {
    # Konwertuj wartości do numeryczne (usuń wszystko oprócz cyfr i kropki)
    players_df$value_numeric <- as.numeric(gsub("[^0-9.]", "", as.character(players_df[[value_col]])))
    
    total_value <- players_df %>%
      summarise(
        season = paste0(SEASON, "/", SEASON+1),
        total_market_value = sum(value_numeric, na.rm = TRUE),
        average_player_value = mean(value_numeric, na.rm = TRUE),
        median_player_value = median(value_numeric, na.rm = TRUE),
        total_players = n(),
        scraped_date = as.character(Sys.Date())
      )
    
    write_json(total_value, output_file, pretty = TRUE, auto_unbox = TRUE)
    cat(sprintf("✅ Wartość ligi: %.2f M EUR\n", total_value$total_market_value / 1000000))
    
    # Clubs cache
    if (!is.null(club_col)) {
      clubs_cache <- players_df %>%
        rename(club = !!club_col) %>%
        group_by(club) %>%
        summarise(
          total_players = n(),
          total_value = sum(value_numeric, na.rm = TRUE),
          avg_value = mean(value_numeric, na.rm = TRUE),
          .groups = "drop"
        ) %>%
        arrange(desc(total_value))
      
      write_json(clubs_cache, cache_file, pretty = TRUE, auto_unbox = TRUE)
      cat(sprintf("✅ Cache: %d drużyn\n", nrow(clubs_cache)))
    } else {
      cat("⚠️ Brak informacji o klubach\n")
      write_json(list(), cache_file, pretty = TRUE)
    }
  } else {
    cat("⚠️ Brak danych o wartościach zawodników\n")
    write_json(list(season = paste0(SEASON, "/", SEASON+1), scraped_date = as.character(Sys.Date())), output_file, pretty = TRUE)
    write_json(list(), cache_file, pretty = TRUE)
  }
  
}, error = function(e) {
  cat(sprintf("❌ BŁĄD: %s\n", e$message))
  write_json(list(), output_file, pretty = TRUE)
  write_json(list(), cache_file, pretty = TRUE)
})
