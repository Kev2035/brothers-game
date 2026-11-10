# STATO del progetto

## Situazione attuale

Progetto appena impostato: repository git, `.gitignore` provvisorio, `CLAUDE.md` e questo file. Nessun codice e nessun engine. Idea di base definita (vedi CLAUDE.md). Engine scelto (Godot 4.7.2, installato). Progetto Godot vuoto creato con le cartelle. Prossima: **Fase 4** (skill).

Piano generale:
1. Fase 1 — Impianto del progetto ✅
2. Fase 2 — Capire l'idea ✅
3. Fase 3 — Scegliere engine e architettura ✅
4. Fase 4 — Valutare e installare le skill di game dev (solo quelle utili) ⏳

## Decisioni prese

| Data | Decisione | Motivo | Stato |
|------|-----------|--------|-------|
| 2026-11-10 | `.gitignore` generico e provvisorio | L'engine non è ancora scelto; si affina dopo | superata il 2026-11-10: adattato a Godot |
| 2026-11-10 | Gioco di duello in arena 1 contro 1, armi che cadono dal cielo, arene fisse con elementi distruttibili e morte per caduta nel vuoto | È il tipo di gioco che Kevin e il fratello giocano sempre insieme (riferimento: Stick Fight) | attiva |
| 2026-11-10 | Stile grafico pixel art e controlli semplici (ispirazione: Metal Slug) | Gusto di Kevin: azioni semplici, il divertimento sta in armi e arene | attiva |
| 2026-11-10 | Piattaforma: PC, multigiocatore locale con due joystick | Prima di tutto ci giocano Kevin e il fratello; Steam e console sono solo un'idea futura | superata il 2026-11-10 dalla decisione sui 2-4 giocatori |
| 2026-11-10 | Piattaforma: PC, multigiocatore locale **da 2 a 4 giocatori**, progettato per 4 fin dall'inizio | Kevin vuole poter giocare anche in più persone; prevederlo subito costa poco, aggiungerlo dopo costa molto | attiva |
| 2026-11-10 | Visuale 2D fissa, vista di lato | Coerente con la pixel art e con il riferimento. Il falso 3D resta un'idea per il futuro | attiva |
| 2026-11-10 | Grafica e audio da pacchetti gratuiti già pronti, eventualmente generati con IA | Kevin non disegna | attiva |
| 2026-11-10 | Obiettivo: gioco finito entro circa un anno (nov 2027), lavorando a tempo perso | Nessuna scadenza rigida | attiva |
| 2026-11-10 | Movimento arcade e preciso (niente ragdoll), con contraccolpo quando si viene colpiti, ma molto veloce e fluido con salti alti | Con la pixel art Kevin immagina personaggi "solidi"; però vuole il ritmo rapido di Stick Fight | attiva |
| 2026-11-10 | Solo multigiocatore locale; l'online forse in una futura "versione 2" | Il gioco serve per giocare insieme sullo stesso divano | attiva |
| 2026-11-10 | **Engine: Godot 4** (GDScript). Scartati GameMaker (a pagamento per vendere), Unity (pesante, C#, pensato per il 3D) e Phaser (scomodo per PC con 4 joystick e per Steam) | Ottimo per il 2D e la pixel art, `CharacterBody2D` adatto al movimento arcade, GDScript simile a Python, 4 joystick gestiti in modo nativo, gratis e open source, leggero, file di testo facili da modificare anche per Claude. Contro: il porting su console passa da aziende esterne a pagamento | attiva |
| 2026-11-10 | Architettura a scene e struttura delle cartelle `assets/`, `src/`, `docs/` (dettagli in CLAUDE.md) | Proposta da Claude e approvata insieme alla scelta di Godot | attiva |
| 2026-11-10 | Risoluzione interna 640×360, finestra 1280×720, ingrandimento solo a multipli interi, filtro "nearest", renderer Compatibility | 640×360 si ingrandisce perfettamente a 720p, 1080p e 4K. I pixel restano nitidi e quadrati. Compatibility è il renderer più leggero, adatto al 2D. Valori modificabili quando avremo la grafica | attiva |

## Strumenti installati

| Data | Strumento | Versione | Come | Dove |
|------|-----------|----------|------|------|
| 2026-11-10 | Godot Engine (standard, GDScript) | 4.7.2 stable | `winget install --id GodotEngine.GodotEngine` | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_...`. Il comando `godot` **non** funziona (winget lo crea solo con diritti di amministratore): si apre dai collegamenti "Godot 4.7" nel menu Start e sul desktop |
| — | Node.js (già presente) | 24.19.0 | — | serve per la Fase 4 |

## Prossimi passi

- Kevin apre il progetto in Godot con "Importa" per vederlo nel Project Manager.
- Fase 4: valutare le skill di game dev per Godot.
- Kevin mostrerà alcuni screenshot di riferimento.

## Dubbi aperti

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
