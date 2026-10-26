# Szydłowski Survival

Początkowa konfiguracja serwera Paper dla Minecraft Java Edition uruchamianego
przez Docker Compose.

## Uruchomienie lokalne

1. Przeczytaj [umowę EULA Minecrafta](https://www.minecraft.net/eula).
2. Skopiuj `.env.example` do `.env` i ustaw `EULA=TRUE` tylko, jeśli akceptujesz
   umowę.
3. Utwórz trwały wolumen: `docker volume create szydlowski-survival-data`.
4. Uruchom serwer: `docker compose up -d`.
5. Śledź uruchamianie: `docker compose logs -f minecraft`.
6. Połącz się z adresem `localhost:25565`.

Wolumen Docker `szydlowski-survival-data` przechowuje świat i dane serwera
po restarcie kontenera oraz aktualizacji obrazu. Jest przypisany tylko do tego
serwera — nie podłączaj go do innych kontenerów jednocześnie.

## Cloud66

Repozytorium zawiera `Dockerfile`, którego wymaga Cloud66 do zbudowania obrazu.
To cienka warstwa na oficjalnym obrazie serwera Minecraft — ustawienia serwera,
pluginy, port i trwałe dane konfiguruj w usłudze Cloud66 zgodnie z `compose.yaml`.
Nie kopiuj świata ani sekretów do obrazu; `/data` ma być trwałym wolumenem.

Przed pierwszym wdrożeniem utwórz wolumen Docker na tym samym hoście, na którym
będzie uruchomiony serwer:

```sh
docker volume create szydlowski-survival-data
```

Jeśli Cloud66 nie pozwala uruchomić tej komendy przed wdrożeniem, utwórz
wolumen przez dostępne narzędzia/SSH na serwerze albo użyj trwałego dysku
Cloud66 zamontowanego jako katalog hosta dla `/data`. W Compose wolumen jest
oznaczony jako `external`, więc musi istnieć przed uruchomieniem usługi.

Wdróż projekt Compose na serwerze Cloud66 z obsługą Dockera. Upewnij się, że
port TCP `25565` jest wystawiony publicznie, a zapora VPS-a zezwala na ruch
przychodzący na tym porcie. Ruch Minecraft Java musi trafiać bezpośrednio do
kontenera — proxy obsługujące wyłącznie HTTP nie wystarczy.

Ustaw `EULA=TRUE` w zmiennych środowiskowych wdrożenia tylko po zaakceptowaniu
EULA. Zachowaj ten sam wolumen przy kolejnych wdrożeniach i rób regularne kopie
zapasowe. Wolumen Docker jest trwały przy odtworzeniu kontenera na tym samym
hoście, ale sam w sobie nie chroni przed utratą lub wymianą VPS-a. Jeśli Cloud66
przeniesie usługę na inny host, trzeba odtworzyć dane z kopii albo użyć dysku
trwałego, który pozostaje dostępny dla nowego hosta. W razie potrzeby ustaw
`MINECRAFT_VERSION` i `MEMORY` jako zmienne środowiskowe wdrożenia.

## Funkcje

Obraz serwera używa Java 25. Przy pierwszym uruchomieniu pobierane są
przypięte wersje pluginów:

- EssentialsX — ekonomia, saldo i przelewy (`/bal`, `/pay`).
- VaultUnlocked — łączy ekonomię z pluginami sklepowymi i pracami.
- LuckPerms — rangi i uprawnienia.
- GriefPrevention — ochrona działek graczy.
- VJobs — prace oraz zadania dające zarobek.
- EconomyShop — sklep serwerowy i sklepy prowadzone przez graczy.

Po starcie sprawdź logi poleceniem `docker compose logs -f minecraft`.
Pluginy utworzą swoje pliki konfiguracyjne w `/data/plugins`. Zanim zaprosisz
graczy, skonfiguruj ceny i wypłaty, przetestuj `/bal`, `/pay`, prace, zakupy
oraz sprzedaż, a następnie nadaj właścicielowi uprawnienia administratora.
Nie udostępniaj publicznie dostępu do konsoli ani RCON.

Pluginy i świat są przechowywane w trwałym wolumenie `/data`. Przed aktualizacją
serwera lub pluginów wykonaj kopię zapasową tego wolumenu. Projekt jest
ustawiony na Minecraft 26.1.2, najnowszą wspólną wersję obsługiwaną przez
obecnie przypięte pluginy. Nowsza wersja gry może wymagać aktualizacji pluginów.
