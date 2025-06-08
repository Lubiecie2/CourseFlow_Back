# Table

- [Table](#table)
  - [O projekcie](#o-projekcie)
  - [Wymagania wstępne](#wymagania-wstępne)
  - [Instalacja zależności](#instalacja-zależności)
  - [Konfiguracja](#konfiguracja)
  - [Uruchamianie aplikacji](#uruchamianie-aplikacji)
    - [Migracja bazy danych](#migracja-bazy-danych)
    - [Uruchamianie w trybie deweloperskim](#uruchamianie-w-trybie-deweloperskim)
    - [Uruchamianie z Docker Compose](#uruchamianie-z-docker-compose)
  - [Struktura projektu](#struktura-projektu)
  - [Powiązane projekty](#powiązane-projekty)

## O projekcie

CourseFlow to platforma edukacyjna online, zaprojektowana do tworzenia, zarządzania i korzystania z interaktywnych kursów. Aplikacja składa się z dwóch głównych części: frontendu opartego na Vue.js/Nuxt.js oraz backendu wykorzystującego Node.js z Express.

System umożliwia zarządzanie kursami, testami, certyfikatami, notatkami oraz interakcjami między użytkownikami, oferując bogate doświadczenie edukacyjne dla uczniów.

## Wymagania wstępne

- Zainstalowany [Node.js](https://nodejs.org/)
- Zainstalowany [PostgreSQL](https://www.postgresql.org/)
- Zainstalowany [Docker](https://www.docker.com/)
- Zainstalowany [Docker Compose](https://docs.docker.com/compose/install/)
- Zainstalowany [Redis](https://redis.io/) (opcjonalnie)
- Działający frontend [CourseFlow Frontend](https://github.com/Lubiecie2/CourseFlow)

## Instalacja zależności

Aby zainstalować wszystkie wymagane zależności, uruchom poniższe polecenia:

```bash
npm install
```

## Konfiguracja

Aplikacja korzysta z plików .env do konfiguracji zmiennych środowiskowych:

```
# Baza danych
DB_USER=twoja_nazwa_uzytkownika
DB_PASSWORD=twoje_haslo
DB_HOST=localhost
DB_PORT=5432
DB_NAME=nazwa_bazy

# Uwierzytelnianie
JWT_SECRET=twoj_sekretny_klucz
JWT_EXPIRES_IN=24h
JWE_SECRET=twoj_sekretny_klucz

# Mailtrap
MAIL_HOST=sandbox.smtp.mailtrap.io
MAIL_PORT=587
MAIL_USER=nazwa_uzytkownika
MAIL_PASS=haslo_uzytkownika
```

## Uruchamianie aplikacji

### Migracja bazy danych

```bash
npx prisma db push
```

### Uruchamianie w trybie deweloperskim

Aby uruchomić aplikację w trybie deweloperskim, użyj poniższego polecenia:

```bash
npm run start
```

### Uruchamianie z Docker Compose

Projekt zawiera konfigurację Docker Compose, która pozwala na łatwe uruchomienie całego środowiska:

```bash
docker-compose up --build
```

## Struktura projektu

```
CourseFlow_Back/                       # Backend aplikacji (Node.js/Express)
├── bin/                               # Pliki wykonywalne
│   └── www                            # Główny plik serwera (Socket.IO config)
├── config/                            # Pliki konfiguracyjne
├── controllers/                       # Kontrolery API
├── middleware/                        # Middleware Express
├── models/                            # Modele danych
├── prisma/                            # Prisma ORM
├── routes/                            # Definicje tras API
├── services/                          # Serwisy aplikacji
├── uploads/                           # Katalog na przesyłane pliki
│   ├── certificates/                  # Wygenerowane certyfikaty PDF
│   ├── courses/                       # Obrazy kursów
│   └── notes/                         # Załączniki do notatek
├── utils/                             # Narzędzia pomocnicze
├── .dockerignore                      # Pliki ignorowane przez Docker
├── .env                               # Zmienne środowiskowe
├── .gitignore                         # Pliki ignorowane przez Git
├── app.js                             # Główny plik aplikacji Express
├── docker-compose.yml                 # Konfiguracja Docker Compose
├── dockerfile                         # Konfiguracja Docker dla backendu
├── example.http                       # Przykładowe zapytania HTTP
├── package.json                       # Zależności i skrypty npm
└── README.md                          # Dokumentacja projektu
```

## Powiązane projekty

- [CourseFlow Frontend](https://github.com/Lubiecie2/CourseFlow) - Repozytorium frontendu aplikacji CourseFlow zbudowane na Nuxt.js/Vue.js z interfejsem użytkownika platformy edukacyjnej
