import os
import tempfile
import logging
from google.cloud import storage
from google.cloud import logging as cloud_logging
import subprocess

# Configura il logger
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Inizializza il client di Cloud Logging
cloud_logger = cloud_logging.Client()
cloud_logger.setup_logging()

def extract_audio(event, context):
    bucket_name = event['bucket']
    video_file = event['name']

    logger.info(f"Ricevuto evento per il file video: {video_file} nel bucket: {bucket_name}")

    storage_client = storage.Client()
    bucket_video = storage_client.bucket(bucket_name)
    bucket_audio = storage_client.bucket('mg-speech-to-text-audio-bucket')

    try:
        _, temp_video = tempfile.mkstemp()
        _, temp_audio = tempfile.mkstemp(suffix='.wav')

        blob = bucket_video.blob(video_file)
        blob.download_to_filename(temp_video)
        logger.info(f"Scaricato il file video {video_file} in {temp_video}")

        # Estrazione audio con ffmpeg
        subprocess.run(['ffmpeg', '-y' , '-i', temp_video, temp_audio], check=True)
        logger.info(f"Audio estratto e salvato in {temp_audio}")

        audio_blob = bucket_audio.blob('' + os.path.basename(video_file).replace('.mkw', '.wav'))
        audio_blob.upload_from_filename(temp_audio)
        logger.info(f"Caricato il file audio in '{os.path.basename(audio_blob.name)}'")

    except Exception as e:
        logger.error(f"Errore durante l'estrazione audio: {e}")
        raise e
    finally:
        # Pulizia dei file temporanei
        try:
            os.remove(temp_video)
            os.remove(temp_audio)
            logger.info(f"File temporanei {temp_video} e {temp_audio} rimossi.")
        except Exception as cleanup_error:
            logger.warning(f"Errore durante la rimozione dei file temporanei: {cleanup_error}")
