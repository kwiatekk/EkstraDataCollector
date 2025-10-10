#!/usr/bin/env Rscript
if (Sys.getenv("R_USER") == "") {
  Sys.setenv(R_USER = path.expand("~"))
  Sys.setenv(HOME = path.expand("~"))
}

suppressPackageStartupMessages({
  library(dplyr)
  library(jsonlite)
})

cat("\n📊 [7/12] Obliczanie formy drużyn...\n")

matches_file <- file.path("data", "match_results.json")
output_file <- file.path("data", "form.json")

tryCatch({
  if (!file.exists(matches_file)) {
    stop("Brak match_results.json - najpierw uruchom 01_collect_matches.R")
  }
  
  matches <- fromJSON(matches_file)
  
  # Debug: sprawdź nazwy kolumn
  cat(sprintf("Kolumny w danych: %s\n", paste(colnames(matches), collapse=", ")))
  
  # Obsługa różnych nazw kolumn z FBref
  if ("Home_Goals" %in% colnames(matches)) {
    # Format z fetch_fbref_ekstraklasa.R
    matches <- matches %>%
      rename(
        Home = Home,
        Away = Away,
        HomeGoals = Home_Goals,
        AwayGoals = Away_Goals,
        Date = Date
      )
  } else if ("HomeGoals" %in% colnames(matches)) {
    # Format z fb_match_results
    # Już OK
  } else if ("Score" %in% colnames(matches)) {
    # Alternatywny format - wyciągnij wynik z kolumny Score
    matches <- matches %>%
      mutate(
        HomeGoals = as.numeric(sub("–.*", "", Score)),
        AwayGoals = as.numeric(sub(".*–", "", Score))
      )
  }
  
  # Filtruj tylko zakończone mecze
  matches <- matches %>%
    filter(!is.na(HomeGoals) & !is.na(AwayGoals)) %>%
    arrange(Date) %>%
    mutate(
      HomeResult = case_when(
        HomeGoals > AwayGoals ~ "W",
        HomeGoals < AwayGoals ~ "L",
        TRUE ~ "D"
      ),
      AwayResult = case_when(
        AwayGoals > HomeGoals ~ "W",
        AwayGoals < HomeGoals ~ "L",
        TRUE ~ "D"
      )
    )
  
  cat(sprintf("Znaleziono %d zakończonych meczów\n", nrow(matches)))
  
  # Funkcja obliczająca formę
  calculate_form <- function(team_name) {
    home_matches <- matches %>%
      filter(Home == team_name) %>%
      select(Date, Result = HomeResult, GF = HomeGoals, GA = AwayGoals)
    
    away_matches <- matches %>%
      filter(Away == team_name) %>%
      select(Date, Result = AwayResult, GF = AwayGoals, GA = HomeGoals)
    
    all_matches <- bind_rows(home_matches, away_matches) %>%
      arrange(desc(Date)) %>%
      head(5)
    
    if (nrow(all_matches) == 0) {
      return(list(
        team = team_name,
        matches_played = 0,
        wins = 0,
        draws = 0,
        losses = 0,
        goals_for = 0,
        goals_against = 0,
        goal_diff = 0,
        points_L5 = 0,
        form_string = "N/A",
        collected_at = Sys.time()
      ))
    }
    
    list(
      team = team_name,
      matches_played = nrow(all_matches),
      wins = sum(all_matches$Result == "W"),
      draws = sum(all_matches$Result == "D"),
      losses = sum(all_matches$Result == "L"),
      goals_for = sum(all_matches$GF),
      goals_against = sum(all_matches$GA),
      goal_diff = sum(all_matches$GF) - sum(all_matches$GA),
      points_L5 = sum(all_matches$Result == "W") * 3 + sum(all_matches$Result == "D"),
      form_string = paste(all_matches$Result, collapse = "-"),
      collected_at = Sys.time()
    )
  }
  
  # Pobierz wszystkie drużyny
  teams <- unique(c(matches$Home, matches$Away))
  
  cat(sprintf("Obliczam formę dla %d drużyn...\n", length(teams)))
  
  # Oblicz formę dla każdej drużyny
  form_data <- lapply(teams, calculate_form)
  form_df <- bind_rows(form_data) %>%
    arrange(desc(points_L5), desc(goal_diff))
  
  write_json(form_df, output_file, pretty = TRUE, auto_unbox = TRUE)
  cat(sprintf("✅ Obliczono formę dla %d drużyn\n", length(teams)))
  
}, error = function(e) {
  cat(sprintf("❌ BŁĄD: %s\n", e$message))
  cat("Traceback:\n")
  print(traceback())
  quit(status = 1)
})
