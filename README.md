# SillyTube — wersja online

## Co jest gotowe
- Supabase Auth: rejestracja/logowanie e-mail + hasło
- publiczne filmy
- upload filmów
- custom thumbnails JPG/PNG/GIF
- kanały
- subskrypcje
- +10 zł do WIRTUALNEGO salda twórcy za nową subskrypcję
- kody promocyjne zmieniane w SQL
- RLS i polityki Storage

## Uruchomienie
1. W Supabase SQL Editor uruchom `supabase_secure.sql`.
2. Otwórz `index.html` w przeglądarce albo wdroż go na hostingu statycznym.
3. W Auth masz już włączone Email i Confirm email.

## Ważne
`psc_balance` to wyłącznie wirtualne saldo aplikacji. Nie jest prawdziwym PSC, pieniądzem ani systemem wypłat.

W kodzie znajduje się tylko publishable key. Nigdy nie wkładaj `sb_secret_...` do HTML/JS.
