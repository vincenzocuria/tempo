# ⏱️ Tempo — Presenza & Tempo Tracker (100% Locale & Privacy-First)

**Tempo** è un'applicazione mobile nativa (Android & iOS) per monitorare automaticamente dove passi le tue giornate e quanto tempo ci trascorri (*quante ore passo a lavoro? Quante in palestra? Quanto a casa o all'università?*).

Nata con una filosofia rigorosa **senza login, senza account e senza cloud di terze parti**: tutti i dati e le coordinate GPS restano esclusivamente memorizzati sul tuo dispositivo.

---

## 🌟 Funzionalità Principali

* **📍 Rilevamento Presenza Geofence**: Monitora i tuoi luoghi preferiti (Lavoro, Palestra, Casa, Studio, Svago) con raggio personalizzabile (50m - 500m) e filtro anti-jitter.
* **📡 Radar di Presenza & Timer Live**: Scheda visiva animata ad onde concentriche che mostra in tempo reale dove ti trovi e il cronometro attivo.
* **📊 Statistiche & Metriche Ore**:
  * Focus immediato su **Ore a Lavoro** e **Ore in Palestra**.
  * Grafico a ciambella interattivo per la distribuzione percentuale del tempo.
  * Grafico ad attività giornaliera a barre (ultimi 7 giorni).
  * Classifica dei luoghi più frequentati.
* **📅 Cronologia Completa & Visite Manuali**: Ricerca, raggruppamento per giorno e possibilità di aggiungere sessioni passate se il GPS era spento.
* **🔒 Privacy & Proprietà dei Dati**: Esportazione completa delle sessioni in **CSV** (compatibile Excel) e **JSON**.
* **🌓 Tema Material 3**: Modalità Scuro profondo e Chiaro con supporto feedback aptico.

---

## 🛠️ Stack Tecnologico

* **Framework**: Flutter 3 / Dart 3
* **Database**: SQLite locale (`sqflite`)
* **Geolocalizzazione**: `geolocator`
* **Grafici**: `fl_chart`
* **Notifiche**: `flutter_local_notifications`
* **Architettura**: MVVM + Repository Pattern con `provider`

---

## 📱 Compilazione ed Esecuzione

```bash
# Dipendenze
flutter pub get

# Esegui i test
flutter test

# Compila l'APK Release per Android
flutter build apk --release
```
