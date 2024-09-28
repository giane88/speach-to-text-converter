# Sistema di Trascrizione Automatica con Google Cloud Functions

## Descrizione

Questo progetto implementa un sistema automatizzato per estrarre l'audio dai video caricati in un bucket Google Cloud Storage e trascrivere l'audio utilizzando le API di Speech-to-Text di Google. Le trascrizioni risultanti vengono salvate nello stesso bucket.

## Struttura del Progetto

- `extract_audio_function/`: Contiene il codice per la funzione Cloud Function che estrae l'audio dai video.
- `transcribe_audio_function/`: Contiene il codice per la funzione Cloud Function che trascrive l'audio.
- `deployment/`: Contiene gli script di deployment per creare le risorse su GCP.
- `.gitignore`: File per escludere file e cartelle non necessari dal repository.
- `README.md`: Questo file, con le istruzioni e la documentazione del progetto.

## Prerequisiti

- Account Google Cloud Platform con le API abilitate per Cloud Functions, Cloud Storage e Speech-to-Text.
- Installazione di Google Cloud SDK.
- Installazione di `ffmpeg` per l'estrazione dell'audio.
- Python 3.7 o superiore.

## Guida all'Installazione

### 1. Configurare l'Ambiente GCP

- Autenticarsi con GCP:

  ```bash
  gcloud auth login
  ```

- Impostare il progetto GCP:

  ```bash
  gcloud config set project YOUR_PROJECT_ID
  ```

### 2. Creare il Bucket di Storage

Il bucket verrà creato automaticamente tramite lo script di deployment.

### 3. Deploy delle Cloud Functions

#### a. Preparare il Codice delle Funzioni

Per entrambe le funzioni, creare un archivio zip del codice.

**Per `extract_audio_function`:**

```bash
cd extract_audio_function
zip -r ../extract_audio_function.zip *
cd ..
```

**Per `transcribe_audio_function`:**

```bash
cd transcribe_audio_function
zip -r ../transcribe_audio_function.zip *
cd ..
```

#### b. Caricare il Codice su un Bucket Temporaneo

Creare un bucket temporaneo per il codice sorgente:

```bash
gsutil mb -l europe-west1 gs://YOUR_SOURCE_BUCKET
```

Caricare gli archivi zip:

```bash
gsutil cp extract_audio_function.zip gs://YOUR_SOURCE_BUCKET/
gsutil cp transcribe_audio_function.zip gs://YOUR_SOURCE_BUCKET/
```

#### c. Modificare il File di Deployment

Nel file `deployment/deployment.yaml`, sostituire:

- `YOUR_PROJECT_ID` con l'ID del vostro progetto.
- `YOUR_SOURCE_BUCKET` con il nome del bucket temporaneo creato.

#### d. Eseguire il Deployment

```bash
gcloud deployment-manager deployments create mg-speech-to-text-deployment --config deployment/deployment.yaml
```

## Utilizzo

- **Caricare un Video**: Caricare un file video nella cartella `video/` del bucket `mg-speech-to-text`.
- **Processo Automatico**: L'audio verrà estratto automaticamente e salvato in `audio/`. Successivamente, l'audio verrà trascritto e la trascrizione salvata in `traduzioni/`.

## Pulizia delle Risorse

Per evitare costi indesiderati, eliminare le risorse quando non sono più necessarie:

```bash
gcloud deployment-manager deployments delete mg-speech-to-text-deployment
gsutil rm -r gs://YOUR_SOURCE_BUCKET
```

## Troubleshooting

- **Logs delle Funzioni**: Per visualizzare i logs delle Cloud Functions:

  ```bash
  gcloud functions logs read extract_audio_function
  gcloud functions logs read transcribe_audio_function
  ```

- **Permessi**: Assicurarsi che le Cloud Functions abbiano i permessi necessari per accedere al bucket e alle API Speech-to-Text.

## Contributi

Le pull requests sono benvenute. Per cambiamenti major, si prega di aprire prima un issue per discutere cosa si desidera cambiare.

## Licenza

[MIT](https://choosealicense.com/licenses/mit/)

---

Questo progetto è stato sviluppato per soddisfare i requisiti specificati, utilizzando le migliori pratiche per le Cloud Functions e l'IaC su Google Cloud Platform.