# STATO del progetto

## Situazione attuale

Impianto completo (Godot 4.7.2, 20 skill, stile a pupazzetti con animazione a pezzi). **Tappa 1 del workflow in corso**: il prototipo di movimento è pronto e superato dai test automatici. Ora aspetta che Kevin lo provi e dia la sua valutazione.

### Workflow del progetto (concordato il 2026-11-11)
Ogni tappa funziona così: Claude costruisce → Kevin prova → feedback e ritocchi → Kevin approva → commit e aggiornamento di STATO.md.
1. **Prototipo movimento** (cerchi colorati): corsa, salto, doppio salto, piattaforme, pugno con contraccolpo, cadute. ⏳
2. **Prototipo combattimento**: mira, 2-3 armi base che cadono dal cielo, vita/morte, round con vincitore. Domanda da chiarire: "è divertente?"
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
| 2026-11-10 | Movimento arcade e preciso (niente ragdoll), con contraccolpo quando si viene colpiti, ma molto veloce e fluido con salti alti | Con la pixel art Kevin immagina personaggi "solidi"; però vuole il ritmo rapido di Stick Fight | attiva |
| 2026-11-10 | Solo multigiocatore locale; l'online forse in una futura "versione 2" | Il gioco serve per giocare insieme sullo stesso divano | attiva |
| 2026-11-10 | **Engine: Godot 4** (GDScript). Scartati GameMaker (a pagamento per vendere), Unity (pesante, C#, pensato per il 3D) e Phaser (scomodo per PC con 4 joystick e per Steam) | Ottimo per il 2D e la pixel art, `CharacterBody2D` adatto al movimento arcade, GDScript simile a Python, 4 joystick gestiti in modo nativo, gratis e open source, leggero, file di testo facili da modificare anche per Claude. Contro: il porting su console passa da aziende esterne a pagamento | attiva |
| 2026-11-10 | Screenshot di riferimento in `docs/riferimenti/`, esclusi da git e ignorati da Godot (`.gdignore`) | Sono immagini protette da copyright di altri giochi e sono pesanti: restano solo in locale. Godot non deve importarle come grafica del gioco | attiva |
| 2026-11-10 | Architettura a scene e struttura delle cartelle `assets/`, `src/`, `docs/` (dettagli in CLAUDE.md) | Proposta da Claude e approvata insieme alla scelta di Godot | attiva |
| 2026-11-11 | **Armi standardizzate**: qualsiasi personaggio deve poter usare qualsiasi arma, senza animazioni dedicate per ogni coppia personaggio-arma (obiettivo indicativo: circa 10 personaggi e 40 armi) | Requisito di Kevin: animare ogni combinazione sarebbe troppo lavoro | attiva |
| 2026-11-11 | I giocatori restano arcade (`CharacterBody2D`), ma gli **oggetti delle arene** (casse, piattaforme in bilico, laser che oscilla, travi appese a catene) possono usare la fisica di Godot (`RigidBody2D`, giunti) | Dagli screenshot molte trappole funzionano proprio con la fisica (equilibrio, oscillazioni, crolli). Sugli oggetti la fisica è divertente, sui personaggi no | attiva |
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

- **Kevin prova il prototipo 1** (F5 in Godot) da solo e con il fratello, poi dice cosa cambiare: velocità, altezza dei salti, pugno, piattaforme.
- Decidere da dove prendere la grafica dei pupazzetti (IA + scontorno, pacchetti pronti, o un mix). Si farà alla tappa 5.
- Decidere come scegliere i personaggi (proposta di Claude: all'inizio tutti uguali, cambia solo il colore, ma il sistema è pronto per aggiungere skin o statistiche in seguito).
- Scrivere un primo documento di design essenziale in `docs/` (regole del round, prime 3-4 armi, prima arena).
- Primo prototipo grezzo (con rettangoli al posto della grafica): 2 giocatori con joystick che corrono, saltano e sparano in un'arena semplice, per capire se il movimento è divertente.

## Dubbi aperti

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
