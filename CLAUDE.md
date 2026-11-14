# brothers-game

Videogioco **personale di Kevin**. Progetto partito da zero il 2026-11-10: niente codice, niente engine, idea ancora da definire.

## Regole di lavoro

- Si lavora **in italiano**.
- Kevin non è un game developer: **spiegare sempre le procedure passo per passo**, in modo semplice, senza dare per scontati termini tecnici.
- **Chiedere prima** di fare scelte tecniche importanti (engine, linguaggio, librerie, struttura) e prima di installare o creare qualcosa di strutturale. Prima si spiega cosa e perché, poi si aspetta l'ok.
- Domande a Kevin: poche per volta, non elenchi lunghi.

## STATO.md — come tenerlo aggiornato

`STATO.md` è il diario del progetto.

- **All'inizio di ogni sessione**: leggere `STATO.md` prima di fare qualsiasi altra cosa.
- **Aggiornarlo** quando Kevin dice "chiudiamo" (o equivalente a fine sessione) e ogni volta che prendiamo una decisione importante.
- Il **log** è in ordine cronologico (le voci nuove vanno in fondo), ogni voce con la data.
- Le **decisioni non si cancellano**: se cambiano, si segnano come *superate* (con data e motivo) e si aggiunge la nuova.

## Idea del gioco

_In definizione._ Il nome "brothers-game" è provvisorio.

- **Per chi**: pensato per far giocare Kevin (30 anni) e suo fratello (16) quando sono a casa insieme.
- **Genere**: picchiaduro / sparatutto in arena, a round brevi: **2-4 personaggi uno contro l'altro**, il round finisce quando ne resta vivo uno solo.
- **Struttura della partita**: "infinita", come in Stick Fight. Si parte in una **lobby** (una piattaforma vuota) dove ci si può già combattere; la partita inizia quando qualcuno fa fuori un avversario. Poi le arene si susseguono round dopo round; ogni ~20 arene si torna alla lobby con classifica e statistiche. Si chiude quando si vuole, e si vede il vincitore.
- **Vita**: c'è (100 punti; pugni e proiettili tolgono vita, ogni arma il suo danno; a zero si muore), ma **non si mostra**: non si deve sapere qual è l'ultimo colpo. Cadere nel vuoto uccide sempre.
- **Ispirazioni** (solo come riferimento, il gioco deve essere originale: niente personaggi, grafica, livelli o nomi copiati):
  - *Stick Fight: The Game*: duello in un'arena, armi che cadono dal cielo, ambientazioni che cambiano durante la partita.
  - *Metal Slug*: controlli semplici. La pixel art è stata scartata il 2026-11-11.
- **Controlli e azioni**: pochi e semplici (muoversi, saltare, mirare, sparare, colpire a mani nude). Il divertimento viene dalle armi e dall'ambientazione, non da combo complicate.
- **Sensazione del movimento**: **arcade e preciso**, niente fisica "ragdoll" (personaggi molli). **I colpi non spostano chi li subisce**: chi è colpito lampeggia di rosso e trema (solo grafica). Il rinculo delle armi riguarda solo chi spara. Il movimento però deve essere **molto veloce e fluido**, come in Stick Fight: corsa rapida, salti molto alti (anche più alti con i potenziamenti), schivate, saltare alle spalle dell'avversario e sparargli. Battaglie rapide e ragionate, mai lente.
- **Giocatori**: da 2 a 4 sullo stesso schermo. Si progetta **fin da subito per fino a 4** (input, punti di partenza, telecamera e dimensioni delle arene), anche se all'inizio si gioca in 2.
- **Visuale**: **2D fisso**, visto di lato. *Idea per il futuro, da non fare ora*: arene che "si rompono" e passano a un falso 3D fatto con tecniche 2D (strada che scorre verso lo schermo, labirinto visto dall'alto inclinato).
- **Stile grafico**: **pupazzetti disegnati** (non pixel art): corpo tondo, mani e piedi staccati, gusto anime/chibi. Tutti hanno la **stessa sagoma** e si distinguono per colore. Si animano **"a pezzi" (cutout)**: i pezzi si muovono e ruotano in Godot, senza disegni fotogramma per fotogramma. I pezzi da colorare si preparano chiari (bianchi o grigi), così Godot può tingerli di qualsiasi colore.
- **Armi standardizzate**: ogni arma è un solo disegno, con il punto di impugnatura e il punto da cui esce il colpo. Si aggancia alla "mano" del personaggio, che ruota per mirare. Poche famiglie di armi (una mano, due mani, corpo a corpo, da lancio), con un'animazione condivisa per famiglia. Qualsiasi personaggio usa qualsiasi arma.
- **Personaggi**: all'inizio tutti uguali, cambia solo il colore. Esiste comunque una "scheda personaggio" (`Resource`), pronta ad accogliere in futuro skin o statistiche.
- **Grafica e audio**: Kevin non disegna. Si useranno pacchetti gratuiti già pronti e/o immagini generate con l'IA e scontornate da Kevin. Bisogna sempre controllare la licenza di ogni risorsa (anche i termini d'uso dello strumento di IA) e annotarla.
- **Armi**: cadono dal cielo durante il round; tipi diversi con poteri diversi, da saper usare bene. Le prime 3: pistola, mitra, fucile a pompa.
- **Ambientazioni (arene)**: una sola schermata fissa per round, senza esplorazione. Piattaforme su cui salire ed elementi tipici di ogni ambientazione. Possono essere **dinamiche e distruttibili** (es. colonne di ghiaccio che si rompono a colpi d'arma e fanno precipitare l'avversario). **Cadere nel vuoto uccide** ed è uno dei modi principali per morire. Nel riferimento ce ne sono 50-70; il numero per noi è da definire.

## Piattaforma (dove si gioca)

- **Ora**: PC (Windows), **multigiocatore locale** sullo stesso schermo, da 2 a 4 giocatori con joystick per PC (es. 8BitDo).
- **Online**: **no**, solo locale. Al massimo ci sarà una "versione 2" online, molto più avanti.
- **Forse in futuro** (non è una priorità): pubblicazione su Steam ed eventuale porting su console.

## Tempo ed esperienza

- Kevin ha basi di Python, HTML e JavaScript, ma non è legato a nessun linguaggio: si sceglie in base all'engine.
- Ci lavora a tempo perso, senza scadenze fisse. Obiettivo: **gioco finito e completo entro circa un anno** (novembre 2027).

## Engine

**Godot 4** (ultima versione stabile 4.x, edizione standard con GDScript, non la versione .NET/C#). Scelto il 2026-11-10: i motivi sono in STATO.md.

### Skill di game dev
Sono installate a livello globale 20 skill della raccolta `awesome-gamedev-agent-skills` (l'elenco è in STATO.md). Per le richieste di game dev si parte dalla skill `router`, che carica solo le skill pertinenti. Prima di aggiungerne altre si chiede a Kevin.

## Architettura

Tutto è costruito con **scene** di Godot che si incastrano tra loro. I blocchi principali:

- **Gestore partita** (`src/core/`): round, punteggi, fine round quando resta vivo un solo giocatore, cambio arena.
- **Gestore controlli** (`src/core/`): associa ogni joystick a un giocatore. Va scritto per **N giocatori (fino a 4)**, mai con codice fisso per "giocatore 1 e 2".
- **Personaggio** (`src/player/`): `CharacterBody2D` con movimento arcade fatto a mano, veloce e preciso. Niente ragdoll né `RigidBody2D` per i personaggi. I colpi non lo spostano (solo lampo rosso). Grafica a pezzi (corpo, mani, piedi) animata in Godot, con un punto di aggancio "mano" che ruota verso la mira.
- **Oggetti delle arene** (`src/objects/`): possono usare la fisica di Godot (`RigidBody2D`, giunti), per esempio casse in equilibrio, laser che oscillano, travi appese a catene.
- **Armi** (`src/weapons/`): una scena "arma base" più una scheda dati (`Resource`) per ogni arma (danno, cadenza, rinculo, munizioni…). Un'arma nuova si crea compilando una nuova scheda.
- **Generatore di armi**: fa cadere le armi dal cielo durante il round.
- **Arena** (`src/arenas/<nome>/`): piattaforme, 4 punti di partenza, zona di morte (il vuoto), elementi distruttibili.
- **Telecamera**: per ora fissa, inquadra tutta l'arena (che è più grande dello schermo, es. 3200×1800 con zoom 0,6). Ogni arena ha i suoi `bounds` e bordi invisibili. In futuro scorrerà da un'arena all'altra (idea "arene una accanto all'altra", tappa 2c).
- **Interfaccia** (`src/ui/`): menu, schermata di ingresso dei joystick, punteggi.

### Struttura delle cartelle

```
brothers-game/
├── CLAUDE.md, STATO.md, .gitignore
├── project.godot
├── assets/        sprites/, audio/, fonts/, LICENZE.md
├── src/           core/, player/, weapons/, arenas/, objects/, camera/, ui/
└── docs/          documento di design
```

## Convenzioni

- Scena e script di una stessa cosa stanno **nella stessa cartella**, divisi per argomento.
- Ogni risorsa grafica o audio esterna va registrata in `assets/LICENZE.md` (origine, autore, licenza). Si preferiscono licenze CC0 o comunque compatibili con un'eventuale vendita.
- Nomi di file e cartelle in minuscolo con trattini bassi (`snake_case`), come raccomanda Godot.
- _Altre convenzioni da definire quando iniziamo a scrivere codice._
