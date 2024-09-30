import os
import logging
from google.cloud import storage, speech_v1p1beta1 as speech
from google.cloud import logging as cloud_logging

# Configura il logger
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Inizializza il client di Cloud Logging
cloud_logger = cloud_logging.Client()
cloud_logger.setup_logging()

def transcribe_audio(event, context):
    bucket_name = event['bucket']
    audio_file = event['name']

    logger.info(f"Ricevuto evento per il file audio: {audio_file} nel bucket: {bucket_name}")

    gcs_uri = f'gs://{bucket_name}/{audio_file}'
    client = speech.SpeechClient()

    audio = speech.RecognitionAudio(uri=gcs_uri)
    config = speech.RecognitionConfig(
        encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
        language_code='it-IT',
    )

    try:
        logger.info(f"Inizio trascrizione asincrona per: {gcs_uri}")
        operation = client.long_running_recognize(config=config, audio=audio)
        response = operation.result(timeout=90)
        logger.info(f"Trascrizione completata per: {gcs_uri}")

        transcription = ''
        for result in response.results:
            transcription += result.alternatives[0].transcript

        storage_client = storage.Client()
        bucket_tans = storage_client.bucket("mg-speech-to-text-traduzioni-bucket")
        transcription_blob = bucket_tans.blob('' + os.path.basename(audio_file).replace('.wav', '.txt'))
        transcription_blob.upload_from_string(transcription)
        logger.info(f"Trascrizione salvata in '{os.path.basename(transcription_blob.name)}'")

    except Exception as e:
        logger.error(f"Errore durante la trascrizione audio: {e}")
        raise e
