# STATO del progetto

## Situazione attuale

Impianto completo (Godot 4.7.2, 20 skill, stile a pupazzetti con animazione a pezzi). **Tappa 1 approvata** (2026-11-13). **Tappa 2a approvata** (2026-11-14). **Tappa 2b approvata** (2026-11-14): 3 armi, sparo, rinculo, scudo sui proiettili, tasto per lasciare l'arma. **Prossima: tappa 2c** (lobby, partita infinita, cambio di arena a scorrimento).

### Per riprendere in una nuova chat (aggiornato il 2026-11-14)
- **Dove siamo**: tappa 2b chiusa e salvata (commit). Si riparte dalla **2c**.
- **Cosa c'è nel gioco** (F5 in Godot): arena di prova 3200×1800 con telecamera; fino a 4 giocatori (tastiera+mouse entra con W o Spazio, tastiera frecce con Freccia su, joystick con A); corsa, salto, doppio salto, salto dai muri, piattaforme attraversabili (Giù+Salto); pugno con mira a 360°; scudo ad arco; vita nascosta (100), colpi che non spostano (lampo rosso); round con scritte di vittoria a caso; statistiche nella scritta in alto; armi (pistola, mitra, pompa) che cadono dal cielo; tasto per lasciare l'arma (Q / Ctrl destro / Y). Tasti di prova: **F2** manichino (premi ancora per cambiare cosa fa), **F3** lo toglie, **F4** dà un'arma a tutti, **R** nuovo round.
- **Kevin ha una sola tastiera** (joystick in arrivo): per provare da solo si usa il manichino.
- **Test automatico**: `tests/test_prototipo.gd` (58 controlli). Si lancia dalla cartella del progetto con:
  `& "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/test_prototipo.gd`
  (prima, dopo aver aggiunto file nuovi, lanciare lo stesso comando con `--import` al posto di `--script ...`). Va aggiornato a ogni modifica.
- **Modo di lavorare che funziona**: Claude costruisce → test automatico + screenshot reale → Kevin prova e dà feedback → ritocchi → ok di Kevin → commit + STATO.md.

### Workflow del progetto (concordato il 2026-11-11)
Ogni tappa funziona così: Claude costruisce → Kevin prova → feedback e ritocchi → Kevin approva → commit e aggiornamento di STATO.md.
1. **Prototipo movimento** (cerchi colorati): corsa, salto, doppio salto, piattaforme, pugno con mira a 360°, scudo, salto dai muri, cadute. ✅
2. **Prototipo combattimento**: mira, 2-3 armi base che cadono dal cielo, vita/morte, round con vincitore. Domanda da chiarire: "è divertente?" ⏳
3. **Documento di design**: Kevin descrive da zero come si svolge una partita (round, punteggi, vittoria) e la prima arena vera. Claude lo scrive in `docs/`.
4. **Prima arena vera in versione grezza**: forme semplici, ma con le trappole dinamiche; telecamera dinamica, 4 giocatori.
5. **Direzione artistica e asset**: stile definito, pezzi dei pupazzetti (IA + scontorno), armi e oggetti. Si sostituiscono i cerchi.
6. **Contenuti**: più armi, più arene, menu, audio, effetti ("game feel").
7. **Rifinitura**: file `.exe`, partite di prova tra fratelli, correzioni.

Piano generale:
1. Fase 1 — Impianto del progetto ✅
2. Fase 2 — Capire l'idea ✅
3. Fase 3 — Scegliere engine e architettura ✅
4. Fase 4 — Valutare e installare le skill di game dev (solo quelle utili) ✅

## Decisioni prese

| Data | Decisione | Motivo | Stato |
|------|-----------|--------|-------|
| 2026-11-10 | `.gitignore` generico e provvisorio | L'engine non è ancora scelto; si affina dopo | superata il 2026-11-10: adattato a Godot |
| 2026-11-10 | Gioco di duello in arena 1 contro 1, armi che cadono dal cielo, arene fisse con elementi distruttibili e morte per caduta nel vuoto | È il tipo di gioco che Kevin e il fratello giocano sempre insieme (riferimento: Stick Fight) | attiva |
| 2026-11-10 | Stile grafico pixel art e controlli semplici (ispirazione: Metal Slug) | Gusto di Kevin: azioni semplici, il divertimento sta in armi e arene | **superata** il 2026-11-11 per la parte grafica: si passa ai pupazzetti disegnati. I controlli semplici restano |
| 2026-11-11 | **Stile grafico: pupazzetti disegnati** (tondi, mani e piedi staccati, gusto anime/chibi) con **animazione "a pezzi" (cutout)** in Godot. Stessa sagoma per tutti, colori diversi | Pixel art troppo costosa: va animata fotogramma per fotogramma, l'IA la genera in modo incoerente e le armi ruotate si vedono male. Con i pezzi separati si anima tutto in Godot, il colore cambia con un'impostazione e le armi si agganciano alla mano | attiva |
| 2026-11-10 | Piattaforma: PC, multigiocatore locale con due joystick | Prima di tutto ci giocano Kevin e il fratello; Steam e console sono solo un'idea futura | superata il 2026-11-10 dalla decisione sui 2-4 giocatori |
| 2026-11-10 | Piattaforma: PC, multigiocatore locale **da 2 a 4 giocatori**, progettato per 4 fin dall'inizio | Kevin vuole poter giocare anche in più persone; prevederlo subito costa poco, aggiungerlo dopo costa molto | attiva |
| 2026-11-10 | Visuale 2D fissa, vista di lato | Coerente con il riferimento. Il falso 3D resta un'idea per il futuro | attiva |
| 2026-11-10 | Grafica e audio da pacchetti gratuiti già pronti, eventualmente generati con IA | Kevin non disegna | attiva |
| 2026-11-10 | Obiettivo: gioco finito entro circa un anno (nov 2027), lavorando a tempo perso | Nessuna scadenza rigida | attiva |
| 2026-11-10 | Movimento arcade e preciso (niente ragdoll), con contraccolpo quando si viene colpiti, ma molto veloce e fluido con salti alti | Con la pixel art Kevin immagina personaggi "solidi"; però vuole il ritmo rapido di Stick Fight | superata in parte il 2026-11-14: movimento confermato, ma i colpi non spostano più (vedi sotto) |
| 2026-11-10 | Solo multigiocatore locale; l'online forse in una futura "versione 2" | Il gioco serve per giocare insieme sullo stesso divano | attiva |
| 2026-11-10 | **Engine: Godot 4** (GDScript). Scartati GameMaker (a pagamento per vendere), Unity (pesante, C#, pensato per il 3D) e Phaser (scomodo per PC con 4 joystick e per Steam) | Ottimo per il 2D e la pixel art, `CharacterBody2D` adatto al movimento arcade, GDScript simile a Python, 4 joystick gestiti in modo nativo, gratis e open source, leggero, file di testo facili da modificare anche per Claude. Contro: il porting su console passa da aziende esterne a pagamento | attiva |
| 2026-11-10 | Screenshot di riferimento in `docs/riferimenti/`, esclusi da git e ignorati da Godot (`.gdignore`) | Sono immagini protette da copyright di altri giochi e sono pesanti: restano solo in locale. Godot non deve importarle come grafica del gioco | attiva |
| 2026-11-10 | Architettura a scene e struttura delle cartelle `assets/`, `src/`, `docs/` (dettagli in CLAUDE.md) | Proposta da Claude e approvata insieme alla scelta di Godot | attiva |
| 2026-11-11 | **Armi standardizzate**: qualsiasi personaggio deve poter usare qualsiasi arma, senza animazioni dedicate per ogni coppia personaggio-arma (obiettivo indicativo: circa 10 personaggi e 40 armi) | Requisito di Kevin: animare ogni combinazione sarebbe troppo lavoro | attiva |
| 2026-11-11 | I giocatori restano arcade (`CharacterBody2D`), ma gli **oggetti delle arene** (casse, piattaforme in bilico, laser che oscilla, travi appese a catene) possono usare la fisica di Godot (`RigidBody2D`, giunti) | Dagli screenshot molte trappole funzionano proprio con la fisica (equilibrio, oscillazioni, crolli). Sugli oggetti la fisica è divertente, sui personaggi no | attiva |
| 2026-11-11 | **Pugno reattivo**: il colpo è istantaneo quando premi (l'animazione è solo grafica: 0,035 s in avanti, 0,07 s indietro). Tra due pugni bastano 0,11 s (circa 9 al secondo) e un pugno premuto troppo presto viene "ricordato" | Feedback di Kevin: vuole colpire veloce quanto riesce a premere | attiva |
| 2026-11-11 | **Mira a 360°**: joystick con la levetta destra (o la sinistra se la destra è ferma), tastiera+mouse col mouse, tastiera frecce in 8 direzioni. Il pugno parte nella direzione di mira e spinge in quella direzione. Pugno verso il basso in aria = rimbalzo sopra l'avversario | Feedback di Kevin: vuole colpire anche in alto, in basso e in diagonale, come la mira di Stick Fight. Servirà uguale per le armi | attiva per la mira; la parte "spinge in quella direzione" è superata il 2026-11-14 (i colpi non spostano) |
| 2026-11-11 | **Scudo (parata)**: un tasto alza un arco davanti al personaggio, nella direzione di mira. L'arco parte come un semicerchio e si chiude in 0,45 s. Para solo i colpi che arrivano dentro l'arco; ogni pressione lo rigenera; con lo scudo alzato non si attacca; se ti colpiscono da un lato scoperto, lo scudo cade. Tasti: clic destro o E (tastiera+mouse), Shift destro (frecce), B o LB (joystick) | Richiesta di Kevin, come in Stick Fight: o ti difendi o attacchi, e chi è veloce ti aggira | attiva |
| 2026-11-11 | **Salto dai muri**: in aria contro un muro, salto = salto dal muro, infinite volte e senza "aggrapparsi". Senza SU ti lancia via; tenendo SU sali poco (~74 px a salto) e ti stacca, quindi scalare richiede tanti salti. L'altezza non dipende da quanto tieni premuto | Richiesta di Kevin, come in Stick Fight: serve anche per salvarsi cadendo in un pozzo | attiva |
| 2026-11-11 | Scendere dalle piattaforme attraversabili con Giù + Salto (sul joystick: levetta giù + A) | Comodo in arene con più piani; non c'è in Stick Fight. **Provvisorio**: Kevin potrebbe toglierlo | attiva (provvisoria) |
| 2026-11-14 | **Vita**: ogni personaggio ha una barra della vita. Pugni e proiettili tolgono vita; a zero si muore. Cadere nel vuoto uccide comunque | Scelta di Kevin. Ogni arma farà danni diversi: serve un sistema dei danni bilanciato (discorso da fare alla fine della tappa 2, con le prime 3 armi in mano) | superata il 2026-11-14 per la parte "barra": la vita resta ma non si vede |
| 2026-11-14 | **Prime 3 armi**: pistola (colpo singolo e preciso), mitra (raffica con rinculo che spinge indietro), fucile a pompa (pallini a corto raggio, spinta fortissima) | Tre armi molto diverse tra loro, presenti anche in Stick Fight. Le altre si aggiungono dopo | attiva |
| 2026-11-14 | **Struttura della partita "infinita" con lobby**: il gioco parte in una **lobby** (una sola piattaforma vuota) dove ci si può già combattere. La partita inizia quando il primo giocatore fa fuori un altro. Poi le arene si susseguono un round dopo l'altro (un round = finché ne resta vivo uno). Ogni ~20 arene si torna alla lobby, che mostra classifica e statistiche (vittorie, colpi, cadute…): lì si può restare a guardarle combattendo o ricominciare subito. Si finisce quando si chiude la partita, e allora si vedono punteggio finale e vincitore | Come in Stick Fight, che piace a Kevin e al fratello: nessun limite di round, si gioca finché si vuole | attiva |
| 2026-11-14 | **Manichino d'allenamento** per i test da soli: F2 lo aggiunge (fermo) e ne cambia il comportamento (fermo → si muove → attacca), F3 lo toglie. Occupa uno dei 4 posti e partecipa ai round | Kevin ha una sola tastiera: senza un avversario non si può provare il combattimento | attiva |
| 2026-11-14 | **Vita nascosta**: la vita c'è (100 punti, ogni colpo ne toglie) ma **non si mostra** da nessuna parte | Scelta di Kevin: non si deve sapere con certezza qual è l'ultimo colpo | attiva |
| 2026-11-14 | **I colpi non spostano chi li subisce** (né spinta né perdita di controllo). Chi è colpito diventa tutto rosso per un attimo e trema (solo grafica); il personaggio rosso diventa bianco. Il rinculo delle armi resterà per chi spara. Il rimbalzo del pugno in basso resta | Kevin: con la spinta il gioco si sbilanciava troppo sul far cadere l'avversario | attiva |
| 2026-11-14 | **Scritte di vittoria a caso** in inglese "da gamer" (GG, EZ, GET REKT, OUTPLAYED…) nel colore del vincitore, al posto di "ROSSO VINCE" | Come in Stick Fight: chi vince si capisce dal colore | attiva |
| 2026-11-14 | **Arena più ampia con telecamera**: l'arena di prova misura 3200×1800 e la telecamera la inquadra tutta (zoom 0,6), quindi i personaggi sono più piccoli sullo schermo, come nelle reference. Bordi invisibili come in Stick Fight: si può uscire dallo schermo di 250 px di lato e 450 px in alto, poi c'è un muro invisibile (da cui non si può saltare); sotto si muore | Kevin: arena troppo piccola e personaggi troppo grandi rispetto a Stick Fight | attiva |
| 2026-11-14 | **Sistema delle armi**: ogni arma è una "scheda" (`WeaponData`, file `.tres` in `src/weapons/`) con danno, numero di pallini, dispersione, automatica sì/no, cadenza, munizioni, velocità e portata dei proiettili, rinculo, aspetto. Si impugna dalla "mano" che segue la mira; le armi a due mani hanno anche la seconda mano sull'arma | Requisito delle armi standardizzate: un'arma nuova = una scheda nuova, senza codice | attiva |
| 2026-11-14 | **Regole delle armi (provvisorie)**: cadono dal cielo ogni 4-7 s (la prima dopo 2 s, max 3 a terra); si raccolgono passandoci sopra **solo a mani nude**; finite le munizioni l'arma sparisce e si torna ai pugni; a ogni round si riparte a mani nude. I proiettili si fermano sui muri solidi e attraversano le piattaforme attraversabili; lo scudo li para; non spostano chi colpiscono. Il rinculo spinge solo chi spara (più forte in aria; sparando in basso mentre cadi si fa un "salto col rinculo") | Prima versione da provare; da rivedere col bilanciamento | attiva |
| 2026-11-14 | **Valori di partenza delle 3 armi** (vita = 100): pistola 20 di danno, 12 colpi, 5 colpi al secondo max · mitra 8 di danno, automatico ~13 colpi/s, 40 colpi, dispersione 7° · pompa 7 pallini da 9 (63 se vanno tutti a segno), portata 750 px, 6 colpi, rinculo fortissimo | Punto di partenza ragionevole; si rivede nel discorso sul bilanciamento | attiva |
| 2026-11-14 | **Tasto per lasciare l'arma** (Q con tastiera+mouse, Ctrl destro con le frecce, Y sul joystick): l'arma cade dove sei e resta lì con i colpi rimasti; chi l'ha lasciata non la riprende finché non si allontana | Richiesta di Kevin: uso strategico, lasci l'arma per prenderne una più potente passandoci sopra | attiva |
| 2026-11-14 | Test automatico salvato nel progetto in `tests/test_prototipo.gd` | Prima era solo nella cartella temporanea della chat: in una nuova chat sarebbe andato perso | attiva |
| 2026-11-10 | Risoluzione interna 640×360, finestra 1280×720, ingrandimento solo a multipli interi, filtro "nearest", renderer Compatibility | 640×360 si ingrandisce perfettamente a 720p, 1080p e 4K. I pixel restano nitidi e quadrati. Compatibility è il renderer più leggero, adatto al 2D. Valori modificabili quando avremo la grafica | superata il 2026-11-11: abbandonata la pixel art |
| 2026-11-11 | Risoluzione di riferimento 1920×1080, finestra 1280×720, ridimensionamento libero (`canvas_items`, scala frazionaria), filtro morbido (lineare), renderer Compatibility | Con la grafica disegnata serve alta risoluzione e immagini levigate, non pixel quadrati. Si disegna pensando al Full HD e il gioco si adatta a qualsiasi schermo | attiva |

## Strumenti installati

| Data | Strumento | Versione | Come | Dove |
|------|-----------|----------|------|------|
| 2026-11-10 | Godot Engine (standard, GDScript) | 4.7.2 stable | `winget install --id GodotEngine.GodotEngine` | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_...`. Il comando `godot` **non** funziona (winget lo crea solo con diritti di amministratore): si apre dai collegamenti "Godot 4.7" nel menu Start e sul desktop |
| — | Node.js (già presente) | 24.19.0 | — | serve per la Fase 4 |
| 2026-11-10 | 20 skill di game dev da `gamedev-skills/awesome-gamedev-agent-skills` (Apache-2.0) | versione della repo al 2026-11-10, CLI `skills` 1.7.6 | `npx skills add gamedev-skills/awesome-gamedev-agent-skills -g -a claude-code --copy -y --skill ...` | `C:\Users\PC\.claude\skills\` (globali, solo Claude Code, copie vere) |

**Skill installate (20):** `router` · Godot: `godot-gdscript`, `godot-nodes-scenes`, `godot-signals-groups`, `godot-2d-movement`, `godot-physics`, `godot-tilemap`, `godot-animation`, `godot-resources`, `godot-ui-control`, `godot-audio`, `godot-export`, `godot-gdscript-headless-testing` · Discipline: `input-systems`, `game-feel`, `camera-systems`, `level-design`, `create-game-assets` · Genere e metodo: `platformer`, `prototype-fast`.

**Rimandate (da aggiungere se serviranno):** `godot-shaders`, `shader-programming`, `physics-tuning`, `audio-design`, `game-ui-ux`, `game-ai`, `performance-optimization`, `steam-publish`.

**Escluse di proposito:** `godot-multiplayer` (è solo per l'online, il gioco locale non ne ha bisogno), `godot-3d-essentials`, `godot-csharp`, le skill degli altri engine e dei generi che non c'entrano.

Comandi utili: `npx skills list -g` (cosa è installato) · `npx skills check` (aggiornamenti) · `npx skills add gamedev-skills/awesome-gamedev-agent-skills -g -a claude-code --copy -y --skill <nome>` (aggiungerne una).

## Prossimi passi

1. **Tappa 2c — Partita e lobby** (prossima):
   - **Lobby**: una piattaforma semplice dove il gioco parte e ci si può già combattere; la partita inizia quando qualcuno fa fuori un avversario.
   - **Partita infinita**: arene una dopo l'altra (per ora l'arena di prova + 2-3 varianti veloci); ogni ~20 arene si torna alla lobby, che mostra classifica e statistiche; si chiude quando si vuole e si vede il vincitore.
   - **Cambio di arena a scorrimento** (idea di Kevin): arene una accanto all'altra nel mondo, la telecamera scorre fino alla prossima, caricamento in background.
2. **Discorso sui danni e sul bilanciamento**, alla fine della tappa 2: concetto di "tempo per uccidere", tabella delle armi in `docs/`. Insieme: ritmo di caduta delle armi e munizioni (Kevin teme che cadano troppo spesso e che i caricatori finiscano troppo presto).
3. **Tappa 3 — Documento di design**: Kevin descrive da zero partita e prima arena vera.
4. Più avanti: grafica dei pupazzetti (tappa 5), scelta dei personaggi (proposta: tutti uguali, cambia il colore).

## Dubbi aperti

- Armi: si devono poter anche **lanciare** addosso agli altri (come in Stick Fight)? Da decidere. (Lasciare l'arma: fatto.)
- Armi: **ritmo di caduta** (ora una ogni 4-7 s) e **munizioni** forse troppo basse: Kevin ci pensa, se ne parla nel bilanciamento.

- **Cambio di arena "a scorrimento"** (idea di Kevin, da fare nella tappa 2c): tutte le arene stanno una accanto all'altra in un grande mondo; finito il round la telecamera scorre fino all'arena successiva, mentre le prossime si caricano in background. Valutazione di Claude: è una buona idea e in Godot si può fare (caricamento in background con `ResourceLoader.load_threaded_request`, telecamera che scorre). L'arena grande con telecamera di questa tappa ne è già la base.

- Kevin per ora ha **una sola tastiera** e nessun joystick: provare da solo un gioco a 2 è difficile. Risolto in parte con il manichino d'allenamento (F2); le partite vere tra fratelli restano il test finale.

- Personaggi: solo estetici (colori o skin) o con statistiche e poteri diversi?
- I due video (`VID-20261110-WA0045.mp4`, `VID-20261110-WA0050.mp4`) non sono ancora stati guardati: Claude non legge i video direttamente, servirebbe estrarne dei fotogrammi.
- Quante arene e quante armi per la prima versione giocabile?
- Nome definitivo del gioco.
- Grafica generata con IA: va verificato che la qualità sia costante e che le animazioni siano coerenti tra loro, e vanno controllate le licenze.
- Idea futura del falso 3D (arene che si rompono, strada che scorre verso lo schermo, labirinto visto dall'alto): da valutare dopo la prima versione.

## Log

- **2026-11-10** — Avvio progetto. Il repository git esisteva già (vuoto, ramo `master`). Creati `.gitignore`, `CLAUDE.md`, `STATO.md`. Iniziata la Fase 2.
- **2026-11-10** — Fase 2, primo giro di risposte: gioco da giocare con il fratello, duello 1 contro 1 in arena ispirato a Stick Fight, grafica e controlli ispirati a Metal Slug, su PC in locale con due joystick.
- **2026-11-10** — Fase 2, secondo giro di risposte: da 2 a 4 giocatori, 2D fisso (falso 3D come idea futura), grafica da pacchetti gratuiti o IA, Kevin ha basi di Python, HTML e JS, obiettivo di circa un anno.
- **2026-11-10** — Fase 2 chiusa: movimento arcade veloce senza ragdoll, solo locale. Iniziata la Fase 3 con il confronto degli engine.
- **2026-11-10** — Kevin ha scelto **Godot 4**. Architettura e cartelle annotate in CLAUDE.md. `.gitignore` adattato a Godot.
- **2026-11-10** — Installato Godot 4.7.2 con winget (verificato con `--version`).
- **2026-11-10** — Il comando `godot` non funzionava: creati i collegamenti "Godot 4.7" nel menu Start e sul desktop. Creati `project.godot` (impostazioni per la pixel art), `.gitattributes`, le cartelle `assets/`, `src/`, `docs/` (con `.gitkeep` vuoti, perché git non salva le cartelle vuote) e `assets/LICENZE.md`. Il progetto si apre in Godot senza errori.
- **2026-11-10** — Primo commit (`9a7b842`). Fase 4: letti README, INSTALLATION e COMPATIBILITY della raccolta `gamedev-skills/awesome-gamedev-agent-skills` (licenza Apache-2.0, skill Godot allineate alla 4.7). Fatta l'anteprima con `--list` (CLI `skills` 1.7.6), senza installare niente. Controllati gli script inclusi: fanno solo analisi locale di file e immagini. Proposta a Kevin una selezione di 20 skill, in attesa del suo ok.
- **2026-11-10** — Kevin ha approvato le 20 skill: installate a livello globale per Claude Code. Verifica superata: 20 su 20 presenti con `SKILL.md` valido e visibili a Claude Code. **Fase 4 chiusa.**
- **2026-11-10** — Creata `docs/riferimenti/` per gli screenshot, con `LEGGIMI.md` (cosa serve e come nominare i file), `NOTE.md` (commenti) e `.gdignore`. Le immagini sono escluse da git.
- **2026-11-11** — Kevin ha caricato 15 screenshot e 2 video di Stick Fight in `docs/riferimenti/`, con le spiegazioni in `NOTE.md` (laser che oscilla, travi con catene da spezzare, ghiaccio distruttibile, neve scivolosa, ruota che gira, barili esplosivi, barili con serpenti, costruzioni di casse in equilibrio, partita a 4). Kevin ripensa alla pixel art e valuta pupazzetti disegnati, tutti con la stessa sagoma e colori diversi. Ha fissato il requisito delle armi standardizzate (10 personaggi × 40 armi senza animazioni dedicate).
- **2026-11-11** — Kevin ha scelto i **pupazzetti disegnati con animazione a pezzi** al posto della pixel art. Aggiornati `project.godot` (1920×1080, `canvas_items`, filtro morbido; il progetto si apre senza errori) e CLAUDE.md (stile, armi standardizzate, personaggi, oggetti fisici delle arene). Da decidere: grafica generata con l'IA o pacchetti pronti.
- **2026-11-11** — Concordato il workflow in 7 tappe (vedi "Situazione attuale"). Costruito il **prototipo 1 (movimento)**: `src/core/main.tscn` (scena principale, i giocatori entrano premendo salto, fino a 4, con tastiera WASD, tastiera frecce e joystick), `src/core/input_setup.gd` (comandi separati per ogni giocatore), `src/player/` (pupazzetto disegnato con cerchi: corsa veloce, salto variabile, doppio salto, coyote time, buffer, discesa rapida, piattaforme attraversabili, pugno con contraccolpo), `src/objects/platform.gd` (piattaforme modificabili nell'editor), `src/arenas/test_arena/` (arena di prova con un buco al centro). Un test automatico headless ha superato 15 controlli su 15 (salto di ~300 px, doppio salto di ~490 px, contraccolpo, morte nel vuoto e ricomparsa, piattaforme attraversabili). Fatto anche uno screenshot reale con 4 giocatori.
- **2026-11-11** — Primo feedback di Kevin sul prototipo 1: il resto del movimento va "ottimo", ma il pugno era lento a tornare e non si poteva mirare. Modifiche: pugno istantaneo con ritorno rapido e possibilità di martellare il tasto (9 pugni al secondo), mira a 360° (mouse per la tastiera WASD, levetta destra per il joystick, frecce in 8 direzioni), pugno nella direzione di mira con spinta coerente, rimbalzo colpendo in basso in aria, puntino che mostra la mira. Test automatico: 19 controlli su 19.
- **2026-11-11** — Kevin ha approvato il pugno ("perfetto") e ha chiesto scudo e salto dai muri. Aggiunti: azione `shield` per ogni dispositivo, scudo ad arco che si restringe (parato = nessuna spinta; colpo alle spalle o fuori dall'arco = colpito), salto dai muri con scalata faticosa. Corretto un difetto: tagliava il salto dal muro a chi lasciava subito il tasto. Arena di prova: muro alto a sinistra (`WallLeft`) e blocchi di terra allungati, così il buco centrale è un pozzo con pareti per salvarsi. Test automatico: 28 controlli su 28.
- **2026-11-13** — Kevin ha approvato la tappa 1 ("mi piace molto", scudo "perfetto"). Si passa a preparare la tappa 2.
- **2026-11-14** — Decisioni di Kevin per la tappa 2: barra della vita (pugni e proiettili tolgono vita), prime 3 armi pistola, mitra e fucile a pompa, partita "infinita" con lobby iniziale e ritorno alla lobby con le statistiche ogni ~20 arene. Concordato di dividere la tappa 2 in 2a/2b/2c.
- **2026-11-14** — Costruita la **tappa 2a**: barra della vita sopra ogni pupazzetto (100 punti, un pugno ne toglie 10), morte a zero vita con sbuffo di fumo colorato, round (chi resta in piedi vince, scritta "COLORE VINCE!", nuovo round dopo 2,5 s con vita piena; da soli si ricompare subito), statistiche nella scritta in alto (vittorie, eliminazioni anche per caduta dopo un colpo, cadute, danni fatti), manichino d'allenamento (`src/player/dummy_brain.gd`). Il personaggio ora legge i comandi da tastiera/joystick oppure dal "cervello" del manichino. Test automatico: 38 controlli su 38.
- **2026-11-14** — Feedback di Kevin sulla 2a: niente barra della vita, i colpi non devono spostare (lampo rosso al loro posto), scritte di vittoria "cool" a caso, arena troppo piccola. Fatto: barra tolta, spinta e perdita di controllo a 0, lampo rosso e tremolio, 24 scritte di vittoria, arena 3200×1800 con telecamera (zoom 0,6) e bordi invisibili (non validi per il salto dai muri). Trovato e corretto un difetto: il timer di un round già finito poteva far ripartire un round di troppo. Test automatico riscritto per l'arena grande: 36 controlli su 36. Kevin ha descritto il cambio di arena a scorrimento di Stick Fight (vedi Dubbi aperti).
- **2026-11-14** — Kevin ha approvato la 2a (commit `7e27bd4`). Costruita la **tappa 2b**: scheda delle armi (`src/weapons/weapon_data.gd`) e 3 armi (`pistol.tres`, `smg.tres`, `shotgun.tres`), proiettili (`bullet.gd`) con controllo del tragitto, armi che cadono dal cielo e si raccolgono (`weapon_pickup.gd`), disegno provvisorio delle armi (`weapon_draw.gd`), effetti (`src/core/fx.gd`), sparo e rinculo nel personaggio, manichino che spara se ha un'arma, F4 per dare un'arma a tutti. Durante le prove: armi rese più chiare e più grandi (troppo scure sullo sfondo) e caduta azzerata prima del rinculo verso il basso (prima il "salto col rinculo" dipendeva dalla velocità di caduta). Test automatico: 53 controlli su 53.
- **2026-11-14** — Kevin ha approvato la 2b (proiettili e piattaforme "ottimo"; ritmo delle armi e munizioni da ripensare). Aggiunto il tasto per lasciare l'arma (cade e tiene i colpi; chi la lascia non la riprende finché non si allontana). Aggiunto `auto_weapons` in `main.gd` per spegnere le armi automatiche. Manichino più prudente vicino al vuoto (ogni tanto si buttava nel pozzo saltando). Test automatico spostato nel progetto (`tests/test_prototipo.gd`): 58 controlli su 58, stabile su 3 esecuzioni. Kevin chiude la sessione; si riprende dalla tappa 2c in una nuova chat.
