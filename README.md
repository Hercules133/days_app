# Nur noch...

Eine minimalistische Countdown-App für Flutter, die dir hilft, deine Ziele zu visualisieren und jeden Tag bis zu deinem großen Ereignis abzuhaken.

## Features

- 📅 **Zieldatum setzen**: Wähle ein Datum in der Zukunft aus
- ⏳ **Live-Countdown**: Sieh auf einen Blick, wie viele Tage noch verbleiben
- ✅ **Tägliches Abhaken**: Hake jeden Tag ab, um deinen Fortschritt zu verfolgen
- 📊 **Fortschrittsanzeige**: Visualisierung deines Fortschritts mit Prozentangabe
- 🔔 **Tägliche Benachrichtigungen**: Erhalte jeden Tag eine Erinnerung (Android/iOS)
- 🎨 **Light & Dark Mode**: Automatische Anpassung an die System-Einstellungen
- 💾 **Persistente Speicherung**: Deine Daten bleiben auch nach dem Schließen der App erhalten
- ⚙️ **Hamburger-Menü**: Ändere dein Zieldatum oder setze den Countdown zurück

## Installation

1. Stelle sicher, dass Flutter installiert ist
2. Installiere die Dependencies:
   ```bash
   flutter pub get
   ```
3. Starte die App:
   ```bash
   flutter run
   ```

## Verwendung

1. **Beim ersten Start**: Wähle ein Zieldatum aus
2. **Tägliche Nutzung**: Öffne die App und hake den heutigen Tag ab
3. **Datum ändern**: Öffne das Menü (☰) und wähle "Zieldatum ändern"
4. **Zurücksetzen**: Im Menü kannst du den Countdown zurücksetzen
5. **Alles löschen**: Im Menü gibt es "App-Daten löschen (alles)" – setzt die App komplett zurück

### Countdown-Logik
- Beim Setzen des Datums wird die anfängliche Differenz in Tagen gespeichert
- Der Countdown zeigt: Ursprüngliche Tage minus abgehakte Tage
- Öffnest du die App nach X Tagen, werden die verpassten Tage automatisch nachgetragen – der heutige Tag bleibt bewusst zum manuellen Abhaken frei

## Berechtigungen

Die App benötigt folgende Berechtigungen:
- **Benachrichtigungen**: Für tägliche Erinnerungen
- **Exakte Alarme**: Für präzise zeitgesteuerte Benachrichtigungen

## Design

Die App folgt den Material Design 3 Richtlinien und bietet:
- Klares, übersichtliches Interface
- Große, gut lesbare Zahlen
- Intuitive Bedienung
- Automatischer Light/Dark Mode

## Technische Details

- **Framework**: Flutter 3.x
- **State Management**: StatefulWidget
- **Persistenz**: shared_preferences
- **Benachrichtigungen**: flutter_local_notifications
- **Datum-Formatierung**: intl

## Plattform-Hinweise

### Linux
- Die App läuft auf Linux; Benachrichtigungen via `periodicallyShow` sind dort nicht implementiert – sie werden deshalb automatisch deaktiviert
- Persistente Daten liegen unter: `~/.config/com.example.days_app/shared_preferences.json`

### Android/iOS App-Icon
- Das App-Icon wird aus `assets/icons/app_icon.png` generiert
- Icon neu generieren:
   ```fish
   dart run flutter_launcher_icons
   ```
- Hinweis iOS: Falls das PNG Transparenz enthält, setze in der pubspec.yaml im `flutter_icons` Block `remove_alpha_ios: true` und führe den Befehl erneut aus
