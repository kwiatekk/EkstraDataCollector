#!/usr/bin/env Rscript
if (Sys.getenv("R_USER") == "") {
  Sys.setenv(R_USER = path.expand("~"))
  Sys.setenv(HOME = path.expand("~"))
}

suppressPackageStartupMessages({
  library(dplyr)
  library(jsonlite)
})

cat("\n🌍 [9/12] Analiza narodowości...\n")

players_file <- file.path("data", "players.json")
output_file <- file.path("data", "nationalities.json")

tryCatch({
  if (!file.exists(players_file)) {
    stop("Brak players.json")
  }
  
  players_df <- fromJSON(players_file)
  
  # Znajdź kolumnę z narodowością (różne źródła używają różnych nazw)
  nationality_col <- NULL
  for (col in c("player_nationality", "nationality", "Nationality")) {
    if (col %in% colnames(players_df)) {
      nationality_col <- col
      break
    }
  }
  
  # Znajdź kolumnę z wartością rynkową
  value_col <- NULL
  for (col in c("player_market_value_euro", "market_value_euro", "player_market_value", "market_value")) {
    if (col %in% colnames(players_df)) {
      value_col <- col
      break
    }
  }
  
  if (nrow(players_df) > 0 && !is.null(nationality_col)) {
    if (!is.null(value_col)) {
      # Z wartościami rynkowymi
      nationalities <- players_df %>%
        rename(nationality = !!nationality_col, market_value = !!value_col) %>%
        group_by(nationality) %>%
        summarise(
          count = n(),
          avg_market_value = mean(market_value, na.rm = TRUE),
          .groups = "drop"
        ) %>%
        arrange(desc(count)) %>%
        mutate(percentage = round(count / sum(count) * 100, 2))
    } else {
      # Bez wartości rynkowych
      nationalities <- players_df %>%
        rename(nationality = !!nationality_col) %>%
        group_by(nationality) %>%
        summarise(count = n(), .groups = "drop") %>%
        arrange(desc(count)) %>%
        mutate(percentage = round(count / sum(count) * 100, 2))
    }
    
    write_json(nationalities, output_file, pretty = TRUE, auto_unbox = TRUE)
    cat(sprintf("✅ Przeanalizowano %d narodowości\n", nrow(nationalities)))
  } else {
    cat("⚠️ Brak danych o narodowościach\n")
    write_json(list(), output_file, pretty = TRUE)
  }
  
}, error = function(e) {
  cat(sprintf("❌ BŁĄD: %s\n", e$message))
  write_json(list(), output_file, pretty = TRUE)
})
