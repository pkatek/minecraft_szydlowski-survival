# Szydłowski Survival

Początkowa konfiguracja serwera Paper dla Minecraft Java Edition uruchamianego
przez Docker Compose.

## Uruchomienie lokalne

1. Przeczytaj [umowę EULA Minecrafta](https://www.minecraft.net/eula).
2. Skopiuj `.env.example` do `.env` i ustaw `EULA=TRUE` tylko, jeśli akceptujesz
   umowę.
3. Utwórz trwały wolumen: `docker volume create szydlowski-survival-data`.
4. Zbuduj obraz i uruchom serwer: `docker compose up -d --build`.
5. Śledź uruchamianie: `docker compose logs -f minecraft`.
6. Połącz się z adresem `localhost:25565`.

Wolumen Docker `szydlowski-survival-data` przechowuje świat i dane serwera
po restarcie kontenera oraz aktualizacji obrazu. Jest przypisany tylko do tego
serwera — nie podłączaj go do innych kontenerów jednocześnie.

Compose buduje lokalny `Dockerfile`, który zawiera skrypt, panel salda i ikonę.
Po zmianach tych plików ponownie użyj `docker compose up -d --build`.

## Cloud66

Repozytorium zawiera `Dockerfile`, którego wymaga Cloud66 do zbudowania obrazu.
To cienka warstwa na obrazie `itzg/minecraft-server` — ustawienia serwera,
pluginy, port i trwałe dane konfiguruj w usłudze Cloud66 zgodnie z `compose.yaml`.
Nie kopiuj świata ani sekretów do obrazu; `/data` ma być trwałym wolumenem.
Jeżeli Cloud66 zarządza usługą przez `service.yml` lub szablony Kubernetes,
lokalny `compose.yaml` nie zmienia automatycznie ustawień tej usługi.

Przy uruchamianiu przez Compose utwórz wolumen Docker na tym samym hoście,
na którym będzie uruchomiony serwer:

```sh
docker volume create szydlowski-survival-data
```

Jeśli Cloud66 nie pozwala uruchomić tej komendy przed wdrożeniem, utwórz
wolumen przez dostępne narzędzia/SSH na serwerze albo użyj trwałego dysku
Cloud66 zamontowanego jako katalog hosta dla `/data`. W Compose wolumen jest
oznaczony jako `external`, więc musi istnieć przed uruchomieniem usługi.
W Cloud66 zarządzanym przez Kubernetes skonfiguruj trwały wolumen przez
mechanizm storage tej usługi; samo `docker volume create` go nie podłącza.

W Cloud66 buduj usługę z lokalnego `Dockerfile`. Upewnij się, że
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
Przy wdrożeniu bez Compose zmienna obrazu nazywa się `VERSION`, a nie
`MINECRAFT_VERSION` — ustaw `VERSION=26.1.2` oraz pozostałe wartości z
sekcji `environment` (w szczególności `TYPE=PAPER` i `PLUGINS`).

### Jedna instancja i restarty w Cloud66

Ten świat obsługuje **jedna instancja serwera** na hoście z jego wolumenem.
Użyj zwykłego Deployment z liczbą replik 1. `DaemonSet` uruchamia po jednej
kopii na każdym pasującym węźle; nie jest ograniczeniem do jednej kopii
w całym klastrze. Wyłącz autoskalowanie tej usługi. Wdrożenie powinno
najpierw zatrzymać starą instancję, pozwolić jej zapisać świat i dopiero
potem uruchomić nową z tym samym `/data`. Wiąże się to z przerwą dla graczy.
Nie uruchamiaj równolegle dwóch procesów Paper na tych samych danych.

Dla Cloud66 Container Service v2 poniższy fragment można scalić z istniejącą
definicją usługi w panelu. Zachowaj jej nazwę, repozytorium, zmienne, porty
i istniejące montowanie `/data`; to nie jest kompletna konfiguracja wdrożenia.
Ustaw także bieżącą liczbę instancji na 1 i przypisanie do hosta z danymi.
Zastąp dotychczasową sekcję `health`, aby nie pozostawić testu HTTP.

```yaml
services:
  minecraft:
    type: deployment
    stop_grace: 120
    constraints:
      min_count: 1
      max_count: 1
      max_surge: 0
      max_unavailable: 1
    health:
      startup:
        type: exec
        command: mc-health
        period: 10
        timeout: 5
        failure_threshold: 60
      ready:
        type: exec
        command: mc-health
        period: 10
        timeout: 5
        failure_threshold: 3
```

`max_surge: 0` ogranicza dodatkowe repliki, ale sam w sobie nie gwarantuje
zakończenia procesu starego poda przed startem nowego. Jeśli konfiguracja v2
nie udostępnia strategii `Recreate`, przed wdrożeniem zatrzymaj usługę przez
panel i poczekaj na całkowite zakończenie starego procesu. Samo usunięcie poda
przy nadal aktywnym kontrolerze spowoduje jego odtworzenie.

W v3 skonfiguruj odpowiadające ustawienia w szablonie Kubernetes: Deployment,
`replicas: 1`, strategię `Recreate`, `terminationGracePeriodSeconds: 120`
oraz startup/readiness probes uruchamiające `mc-health`. Kontroler musi
umieszczać instancję na węźle z właściwym trwałym `/data`.
Dockerfile ma własny healthcheck z 5 minutami na start, ale Kubernetes
wymaga osobnych probes; nie należy zakładać, że przejmie Docker HEALTHCHECK.
Test HTTP na porcie Minecrafta jest niewłaściwy — używaj `mc-health`.

Źródła: [DaemonSet](https://help.cloud66.com/deploy/3/cloud-66-101/concepts-and-terminology/),
[limity instancji](https://help.cloud66.com/deploy/2/build-and-config/service-resources/),
[aktualizacje podów](https://help.cloud66.com/deploy/2/deployment/configuring-pod-updates/),
[kontrole stanu i czas zamknięcia](https://help.cloud66.com/deploy/build-and-config/service-lifecycle-management/),
[strategia Recreate](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#recreate-deployment).

### Pamięć i zbieranie informacji o awarii

Domyślnie Java zaczyna od `INIT_MEMORY=1G`, a maksymalna sterta wynosi
`MEMORY=4G`. `INIT_MEMORY` nie może przekraczać `MEMORY`. JVM, pluginy,
system i Cloud66 potrzebują również pamięci poza stertą. Na hoście z 8 GB
RAM zacznij od jednej instancji z `MEMORY=4G`; nie ustawiaj sterty na całe
8 GB ani limitu kontenera równego rozmiarowi sterty. Mniejsza pamięć
początkowa nie usuwa przyczyny ewentualnego OOM pod obciążeniem.
Zasady ustawień opisuje [dokumentacja obrazu](https://docker-minecraft-server.readthedocs.io/en/latest/configuration/jvm-options/).

W Cloud66 sprawdź status zakończonego kontenera/poda, jego poprzednie logi,
zdarzenia oraz historię wdrożeń. Wiele zakończonych podów nie oznacza wielu
maszyn. `OOMKilled` wskazuje na zabicie z powodu braku pamięci; sam kod 137
nie wystarcza do ustalenia przyczyny. Błędy probes, `session.lock`, brak miejsca
na dysku i watchdog serwera wymagają innych działań niż zwiększanie RAM.

Jeżeli usługa działa bezpośrednio w Dockerze, uruchom na hoście:

```sh
sh scripts/diagnose-server.sh NAZWA_LUB_ID_KONTENERA
```

Bez argumentu używana jest nazwa `szydlowski-survival`. Skrypt tylko odczytuje
stan, limity, montowania, bieżące zużycie zasobów, ostatnie zdarzenia i logi.
Nie uruchamia, nie usuwa ani nie restartuje kontenerów. Zbieraj dane przed
odtworzeniem kontenera: po restarcie/odtworzeniu część dowodów może zniknąć.
W Kubernetes użyj panelu lub poleceń z właściwą przestrzenią nazw i nazwą poda:

```sh
kubectl -n TWOJA_PRZESTRZEN describe pod TWOJ_POD
kubectl -n TWOJA_PRZESTRZEN logs TWOJ_POD --previous --tail=200
```

Compose ogranicza logi Dockera do 5 plików po 10 MB i daje 2 minuty na
zamknięcie kontenera; proces serwera ma `STOP_DURATION=90` sekund na zapis.
W Cloud66 ustaw analogiczny czas zamknięcia i retencję logów w usłudze.

## Funkcje

Obraz serwera używa Java 25. Przy pierwszym uruchomieniu pobierane są
przypięte wersje pluginów:

- EssentialsX — ekonomia, saldo i przelewy (`/bal`, `/pay`).
- PlaceholderAPI i SimpleScore — saldo na panelu po prawej stronie ekranu.
- Skript — blokuje PvP wobec gracza, który nie ma pełnego zestawu zbroi.
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

Skrypt PvP i przypomnienia są dostarczane w `scripts/full-armor-pvp.sk` i
kopiowane do `/data/plugins/Skript/scripts` z obrazu przy starcie. W Cloud66
dopisz do zmiennej `PLUGINS` przypięte adresy Skript, PlaceholderAPI i
SimpleScore z `compose.yaml`, a następnie przebuduj obraz i wdróż usługę
ponownie. Plik panelu salda również jest kopiowany do katalogu pluginów przy
starcie. Ikona jest pobierana z obrazu i zastępuje poprzednią ikonę serwera.

Skrypt co 15 minut przypomina graczom o komendach salda, płatności, prac i
sklepu (`/shop`) oraz płatnym teleportowaniu. Gracz wysyła prośbę przez
`/tpa100 <nick>`; adresat akceptuje ją komendą `/tp100accept` albo odrzuca
`/tp100deny`. Po akceptacji skrypt sprawdza saldo i wykonuje teleport;
100$ pobierane jest dopiero po potwierdzeniu, że teleport nie został anulowany
i gracz dotarł do celu. Nieudana próba nie pobiera pieniędzy i wymaga nowej
prośby. Aktywnej prośby nie można nadpisać kolejną. Prośba wygasa po 2 minutach.
Dodatkowo co 10 minut wszystkim graczom wyświetla się krótka wiadomość na actionbarze:
`Sklep serwerowy: /shop`.
Nowi gracze są przy pierwszym wejściu automatycznie dołączani do wszystkich
18 prac VJobs. Aby to zadziałało, grupa `default` musi mieć uprawnienia:

```text
lp group default permission set jobs.limit.18 true
lp group default permission set jobs.cooldown.instant true
```

Każdy może dzięki temu zarabiać i zdobywać poziomy we wszystkich pracach.
Automatyczne dołączanie dotyczy nowych graczy; obecnych graczy trzeba dodać
ręcznie komendami `/vjobs join <praca>`.
Panel SimpleScore pokazuje saldo przez placeholder Vault. Po pierwszym
uruchomieniu PlaceholderAPI wpisz w konsoli serwera Cloud66 (nie w terminalu
systemowym kontenera):

```text
papi ecloud download Vault
papi reload
```

Po przeładowaniu pluginów panel powinien wyświetlić aktualne saldo gracza.

### Kupowanie bloków claimów

Gracze mogą kupować bloki ochrony za pieniądze z `/bal`:

```text
/buyclaimblocks 100
```

Domyślna cena to **10$ za blok**, więc ten zakup kosztuje **1000$**.
`/claimslist` pokazuje pulę bloków i działki gracza. Komendy obsługuje
GriefPrevention, korzystając z ekonomii EssentialsX przez VaultUnlocked.

Cena jest ustawiana przed startem Paper przez `scripts/configure-claims.sh`.
Skrypt zmienia wyłącznie `GriefPrevention.Economy.ClaimBlocksPurchaseCost`
w `/data/plugins/GriefPreventionData/config.yml` za pomocą narzędzia obrazu
`mc-image-helper`. Działa także na istniejącym wolumenie i zachowuje pozostałe
wartości konfiguracji. Przed pierwszą zmianą istniejącego pliku tworzy kopię
`config.yml.before-claim-shop`. Formatowanie i komentarze YAML mogą się zmienić.
Przy świeżej instalacji tworzy minimalną konfigurację; plugin uzupełnia resztę.

W Compose ustaw cenę w `.env`, a w Cloud66 w zmiennych usługi:

```text
CFG_CLAIM_BLOCK_PRICE=10.0
```

Wartość musi być dodatnia; ułamki zapisuj z kropką. Cena z tej zmiennej jest
ponownie stosowana przy każdym starcie, więc ręczna zmiana tego pola w pliku
pluginu nie jest trwała. Pozostałe ustawienia, w tym cena odsprzedaży bloków,
pozostają bez zmian. Uprawnienie do zakupów `griefprevention.buysellclaimblocks`
jest domyślnie przyznane graczom; sprawdź LuckPerms, jeśli wcześniej je odebrano.

Po dodaniu tej funkcji przebuduj i wdróż obraz w Cloud66. Lokalnie użyj
`docker compose up -d --build`. Samo `gpreload` nie pobiera nowych plików
z repozytorium. Jeśli masz własny `PRE_START_SCRIPT` ustawiony w panelu,
uwzględnij w nim wywołanie `/opt/minecraft/configure-claims.sh`.
Po wdrożeniu sprawdź `/bal`, `/claimslist` i zakup jednego bloku zwykłym graczem:
saldo powinno zmniejszyć się o 10$, a pula wzrosnąć o 1.

Wersja GriefPrevention 16.18.7 używa katalogu `GriefPreventionData`, nie
`GriefPrevention`. Wcześniejsza wersja skryptu zapisywała cenę w błędnym
katalogu. Po wdrożeniu poprawki istniejące claimy i dane graczy pozostają
na miejscu; skrypt aktualizuje właściwy plik i odczytuje cenę ponownie,
a w logu `[claims]` podaje jej wartość oraz pełną ścieżkę.
Plik utworzony wcześniej w `plugins/GriefPrevention/config.yml` jest ignorowany
przez tę wersję pluginu; nie kopiuj go w miejsce pełnej konfiguracji.

Jeżeli kupowanie nadal jest wyłączone, sprawdź cenę w
`plugins/GriefPreventionData/config.yml` oraz log pluginu. Wiersz
`Hooked into economy: ... Ready to buy/sell claim blocks!` potwierdza połączenie
z ekonomią. Komunikaty o braku Vault lub obsługiwanego pluginu ekonomii
wskazują na problem integracji, nawet jeśli sama cena jest już poprawna.

Test konfiguracji bez uruchamiania Paper (po zbudowaniu obrazu):

```sh
docker run --rm --entrypoint sh \
  --mount "type=bind,src=$PWD,dst=/workspace,readonly" \
  szydlowski-survival:local /workspace/tests/test-configure-claims.sh
```

Test używa tymczasowego katalogu i rzeczywistego `mc-image-helper` z obrazu;
nie podłącza produkcyjnego wolumenu świata.

Źródła: [ekonomia GriefPrevention](https://docs.griefprevention.com/configuration/#economy-integration),
[ścieżka konfiguracji w 16.18.7](https://github.com/GriefPrevention/GriefPrevention/blob/16.18.7/src/main/java/me/ryanhamshire/GriefPrevention/DataStore.java),
[modyfikacja konfiguracji w obrazie](https://docker-minecraft-server.readthedocs.io/en/latest/configuration/interpolating/#patching-existing-files).

Pluginy i świat są przechowywane w trwałym wolumenie `/data`. Przed aktualizacją
serwera lub pluginów wykonaj kopię zapasową tego wolumenu. Projekt jest
ustawiony na Minecraft 26.1.2, najnowszą wspólną wersję obsługiwaną przez
obecnie przypięte pluginy. Nowsza wersja gry może wymagać aktualizacji pluginów.

## Sprawdzenie zmian na serwerze testowym

Po zbudowaniu obrazu sprawdź logi ładowania Skript (bez błędów składni),
panel salda, ikonę oraz blokadę PvP dla gracza bez pełnej zbroi.
Dla teleportów sprawdź z trzema graczami:

- Udana akceptacja: przeniesienie do celu i dokładnie 100$ opłaty;
  ponowna akceptacja nie pobiera pieniędzy.
- Dwie prośby do jednego adresata: druga jest odrzucona i nie zmienia pierwszej.
- Saldo poniżej 100$, odrzucenie, wylogowanie proszącego i wygaśnięcie
  po 2 minutach: brak teleportu i brak opłaty.
- Anulowanie teleportu przez testową regułę Skript lub inny plugin:
  brak opłaty i komunikatu sukcesu, również gdy gracz już stoi w celu.
- Teleport między światami: poprawny cel i pojedyncza opłata.

Na końcu zatrzymaj i odtwórz instancję testową na tym samym wolumenie:
świat, saldo i ustawienia pluginów powinny pozostać zachowane.
