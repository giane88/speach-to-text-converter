#!/bin/bash

# Script di deployment per il sistema di trascrizione automatica con Google Cloud Functions

# Exit immediately if a command exits with a non-zero status
set -e

# Funzione per stampare messaggi di errore
error_exit() {
  echo "Errore: $1" 1>&2
  exit 1
}

# Verifica se gcloud è installato
if ! command -v gcloud &> /dev/null
then
    error_exit "gcloud non è installato. Installalo seguendo le istruzioni su https://cloud.google.com/sdk/docs/install"
fi

# Verifica se ffmpeg è installato
if ! command -v ffmpeg &> /dev/null
then
    error_exit "ffmpeg non è installato. Installalo prima di procedere."
fi

# Verifica se Deployment Manager è abilitato
if ! gcloud services list --enabled | grep -q "deploymentmanager.googleapis.com"; then
    echo "Abilito Deployment Manager..."
    gcloud services enable deploymentmanager.googleapis.com || error_exit "Impossibile abilitare Deployment Manager."
fi

REQUIRED_APIS=(
  "cloudfunctions.googleapis.com"
  "storage.googleapis.com"
  "speech.googleapis.com"
  "deploymentmanager.googleapis.com"
  "artifactregistry.googleapis.com"
  "cloudbuild.googleapis.com"
)

for api in "${REQUIRED_APIS[@]}"; do
    if ! gcloud services list --enabled | grep -q "$api"; then
        echo "Abilito l'API $api..."
        gcloud services enable "$api" || error_exit "Impossibile abilitare l'API $api."
    else
        echo "L'API $api è già abilitata."
    fi
done

# Percorso del file di configurazione
CONFIG_FILE="deployment/config.local.yaml"

# Verifica se il file di configurazione esiste
if [ ! -f "$CONFIG_FILE" ]; then
    error_exit "Il file di configurazione $CONFIG_FILE non esiste. Crea e configura questo file prima di procedere."
fi

# Estrazione delle variabili dal file di configurazione utilizzando awk
PROJECT_ID=$(awk -F": " '/project_id:/ {print $2}' "$CONFIG_FILE")
SOURCE_BUCKET=$(awk -F": " '/source_bucket:/ {print $2}' "$CONFIG_FILE")

# Rimuove eventuali spazi bianchi dai valori estratti
PROJECT_ID=$(echo "$PROJECT_ID" | xargs)
SOURCE_BUCKET=$(echo "$SOURCE_BUCKET" | xargs)

# Verifica che le variabili siano state estratte
if [ -z "$PROJECT_ID" ] || [ -z "$SOURCE_BUCKET" ]; then
    error_exit "Impossibile estrarre project_id o source_bucket dal file di configurazione."
fi

echo "Project ID: $PROJECT_ID"
echo "Source Bucket: $SOURCE_BUCKET"

# Imposta il progetto corrente
gcloud config set project "$PROJECT_ID" || error_exit "Impossibile impostare il progetto $PROJECT_ID."

# Verifica se il bucket di origine esiste, altrimenti crealo
if gsutil ls "gs://$SOURCE_BUCKET" > /dev/null 2>&1; then
    echo "Il bucket gs://$SOURCE_BUCKET esiste già."
else
    echo "Creazione del bucket gs://$SOURCE_BUCKET..."
    gsutil mb -l europe-west1 "gs://$SOURCE_BUCKET" || error_exit "Impossibile creare il bucket gs://$SOURCE_BUCKET."
fi

# Funzione per impacchettare una funzione
package_function() {
    FUNCTION_DIR=$1
    ZIP_FILE=$2

    if [ ! -d "$FUNCTION_DIR" ]; then
        error_exit "La directory $FUNCTION_DIR non esiste."
    fi

    echo "Impacchettamento della funzione $FUNCTION_DIR in $ZIP_FILE..."
    cd "$FUNCTION_DIR"
    zip -r "../$ZIP_FILE" . -x "*.git*"
    cd ..
}

# Impacchettamento delle funzioni
package_function "extract_audio_function" "extract_audio_function.zip"
package_function "transcribe_audio_function" "transcribe_audio_function.zip"

# Caricamento degli archivi zip nel bucket di origine
echo "Caricamento degli archivi zip nel bucket gs://$SOURCE_BUCKET..."
gsutil cp "extract_audio_function.zip" "gs://$SOURCE_BUCKET/" || error_exit "Impossibile caricare extract_audio_function.zip."
gsutil cp "transcribe_audio_function.zip" "gs://$SOURCE_BUCKET/" || error_exit "Impossibile caricare transcribe_audio_function.zip."

# Esecuzione del deployment
echo "Esecuzione del deployment con Deployment Manager..."
if ! gcloud deployment-manager deployments describe mg-speech-to-text-deployment > /dev/null 2>&1; then
    gcloud deployment-manager deployments create mg-speech-to-text-deployment --config "deployment/config.local.yaml" || error_exit "Impossibile creare il deployment."
else
    echo "Il deployment esiste già. Provo ad aggiornare..."
    gcloud deployment-manager deployments update mg-speech-to-text-deployment --config "deployment/config.local.yaml" || error_exit "Impossibile aggiornare il deployment."
fi

echo "Deployment completato con successo."

# Opzionale: Pulizia degli archivi zip locali
read -p "Vuoi rimuovere gli archivi zip locali? (y/N): " CLEANUP
if [[ "$CLEANUP" =~ ^[Yy]$ ]]; then
    rm "extract_audio_function.zip" "transcribe_audio_function.zip"
    echo "Archivi zip locali rimossi."
else
    echo "Archivi zip locali mantenuti."
fi

# Fine dello script
