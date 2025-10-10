#!/usr/bin/env Rscript
if (Sys.getenv("R_USER") == "") {
  Sys.setenv(R_USER = path.expand("~"))
  Sys.setenv(HOME = path.expand("~"))
}

suppressPackageStartupMessages({
  library(dplyr)
  library(jsonlite)
})

cat("\n🌟 [11/12] Wyszukiwanie młodych talentów...\n")

players_file <- file.path("data", "players.json")
output_file <- file.path("data", "young_talents.json")
YOUNG_TALENT_AGE <- 21

tryCatch({
  if (!file.exists(players_file)) {
    stop("Brak players.json")
  }
  
  players_df <- fromJSON(players_file)
  
  # Znajdź kolumnę z wiekiem
  age_col <- NULL
  for (col in c("player_age", "age", "Age")) {
    if (col %in% colnames(players_df)) {
      age_col <- col
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
  
  # Znajdź kolumnę z nazwą
  name_col <- NULL
  for (col in c("player_name", "name", "Name", "Player")) {
    if (col %in% colnames(players_df)) {
      name_col <- col
      break
    }
  }
  
  # Znajdź kolumnę z pozycją
  position_col <- NULL
  for (col in c("player_position", "position", "Position", "Pos")) {
    if (col %in% colnames(players_df)) {
      position_col <- col
      break
    }
  }
  
  # Znajdź kolumnę z narodowością
  nationality_col <- NULL
  for (col in c("player_nationality", "nationality", "Nationality")) {
    if (col %in% colnames(players_df)) {
      nationality_col <- col
      break
    }
  }
  
  if (nrow(players_df) > 0 && !is.null(age_col)) {
    # Przygotuj dane
    talents <- players_df
    talents$age_temp <- as.numeric(talents[[age_col]])
    
    # Filtruj młodych zawodników
    talents <- talents %>% filter(age_temp <= YOUNG_TALENT_AGE)
    
    if (nrow(talents) > 0) {
      # Sortuj po wartości rynkowej jeśli dostępna
      if (!is.null(value_col)) {
        talents$value_temp <- as.numeric(gsub("[^0-9.]", "", as.character(talents[[value_col]])))
        talents <- talents %>% arrange(desc(value_temp))
      }
      
      # Wybierz top 20
      talents <- talents %>% head(20)
      
      # Przygotuj output ze wszystkimi dostępnymi kolumnami
      output_cols <- list()
      if (!is.null(name_col)) output_cols$player_name <- talents[[name_col]]
      if (!is.null(age_col)) output_cols$player_age <- talents[[age_col]]
      if (!is.null(position_col)) output_cols$player_position <- talents[[position_col]]
      if (!is.null(value_col)) output_cols$player_market_value <- talents[[value_col]]
      if (!is.null(nationality_col)) output_cols$player_nationality <- talents[[nationality_col]]
      
      young_talents <- as.data.frame(output_cols)
      
      write_json(young_talents, output_file, pretty = TRUE, auto_unbox = TRUE)
      cat(sprintf("✅ Znaleziono %d młodych talentów (≤%d lat)\n", nrow(young_talents), YOUNG_TALENT_AGE))
    } else {
      cat("⚠️ Brak młodych zawodników\n")
      write_json(list(), output_file, pretty = TRUE)
    }
  } else {
    cat("⚠️ Brak danych o wieku zawodników\n")
    write_json(list(), output_file, pretty = TRUE)
  }
  
}, error = function(e) {
  cat(sprintf("❌ BŁĄD: %s\n", e$message))
  write_json(list(), output_file, pretty = TRUE)
})
