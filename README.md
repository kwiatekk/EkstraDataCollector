# ⚽ EkstraDataCollector

Automatyczny system zbierania i publikacji danych o polskiej **Ekstraklasie**  
(Transfermarkt + FBref + dane finansowe) w ramach projektu **EkstraData**.

Dane są aktualizowane codziennie o 06:00 (CET) przez **GitHub Actions**,  
a wyniki są publicznie dostępne przez **GitHub Pages** w formacie JSON.

---

## 🌍 Publiczne dane JSON

Po pierwszym uruchomieniu workflowa pliki pojawią się tutaj:

| Typ danych | URL |
|-------------|-----|
| 📊 Forma drużyn | https://kwiatekk.github.io/EkstraDataCollector/data/form.json |
| ⚽ Wyniki meczów | https://kwiatekk.github.io/EkstraDataCollector/data/match_results.json |
| 👟 Statystyki xG | https://kwiatekk.github.io/EkstraDataCollector/data/xg.json |
| 💰 Transfery | https://kwiatekk.github.io/EkstraDataCollector/data/transfers.json |
| 🧒 Młodzieżowcy | https://kwiatekk.github.io/EkstraDataCollector/data/young_talents.json |

---

## 🕒 Harmonogram

- Codziennie o **06:00 (CET)** – automatyczne uruchomienie pipeline’u  
- Możesz też uruchomić ręcznie z zakładki **Actions → Run workflow**

---

## 🔗 Integracja z OpenAI Agent Builder

Aby agent mógł pobierać dane:
1. W Agent Builderze dodaj narzędzie **Web / File Search**.
2. Podaj źródła danych:
3. Agent może generować posty (#EkstraData) na podstawie świeżych danych.

---

## 👨‍💻 Autor

**Krzysztof Kwiatkowski**  
📧 kkwiatkowski87@gmail.com  
🔗 Projekt: [EkstraDataCollector](https://github.com/kwiatekk/EkstraDataCollector)

