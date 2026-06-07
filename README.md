# PhotoOrganizer

En fristående macOS-app som:

1. **Konverterar RW2 → DNG** (Panasonic RAW → Adobe DNG) med bevarad metadata.
2. **Sorterar JPEG/JPG/DNG** in i `YYYY/MM/DD/`-mappar baserat på EXIF-datum.

RW2-originalen flyttas till papperskorgen efter verifierad konvertering. Inget skrivs till disk förrän du godkänner planen i förhandsgranskningen.

## Så här kör du

Dubbelklicka:

```
PhotoOrganizer.app
```

Det är allt. Appen är fristående — inga andra program behövs.

### Om macOS säger "appen kan inte öppnas"

Eftersom appen är ad-hoc-signerad (inte Apple-notariserad) kan Gatekeeper stoppa den första gången:

1. **Högerklicka** på `PhotoOrganizer.app` → välj **Öppna**
2. Bekräfta dialogen

Sedan körs appen som vanligt genom dubbelklick.

## Använd appen

1. Klicka **Välj mapp…** och peka ut en mapp med foton.
2. Klicka **Skanna och bygg plan**.
3. Granska planen och lös ev. datum-konflikter.
4. Klicka **Kör plan**.

## Mappstruktur (exempel)

Väljer du mappen `Foton/` med bilder från mars 2024 skapas:

```
Foton/
├── 2024/
│   └── 03/
│       └── 15/
│           ├── IMG_0001.JPG
│           └── P1020304.DNG
└── _unsorted/       # för bilder utan EXIF-datum
```

Heter den valda mappen redan `2024` skapas bara `03/15/` under den. `2024-03` → bara `15/`. `2024-03-15` → ändå `YYYY/MM/DD/`.

## Filhantering

- **RW2 → DNG:** RW2 flyttas till papperskorgen **först efter** att DNG skapats och verifierats ha EXIF-datum.
- **JPEG/DNG:** flyttas till sin måladress (inte kopieras).
- **Namnkonflikter:** vid krock läggs suffix `-1`, `-2`, … på filnamnet.
- **Utan EXIF-datum:** hamnar i `_unsorted/`.

## Bygga om från källkod

Om du vill ändra och bygga om appen:

```
./build.sh
```

Det räcker med Swift-compilern som följer med macOS Command Line Tools — ingen Xcode behövs. Resultatet blir en ny `PhotoOrganizer.app` i projektets rot.

## Tekniska detaljer

- Skriven i Swift + SwiftUI
- Måljakt: macOS 13+, Apple Silicon (arm64)
- EXIF-läsning via Apples inbyggda `ImageIO`
- RW2 → DNG via inbakad [`dnglab`](https://github.com/dnglab/dnglab) (open source, MIT) i `PhotoOrganizer.app/Contents/Resources/dnglab`
- Ad-hoc-signerad med `codesign`

## Projektstruktur

```
PhotoOrganizer/
├── PhotoOrganizer.app/           # ← färdiga appen (efter build.sh)
├── build.sh                      # bygger appen från källkod
├── PhotoOrganizer/               # källkod
│   ├── PhotoOrganizerApp.swift
│   ├── ContentView.swift
│   ├── Views/
│   ├── Core/
│   ├── Models/
│   └── Resources/
│       └── dnglab                # inbakad konverterare
└── README.md
```
