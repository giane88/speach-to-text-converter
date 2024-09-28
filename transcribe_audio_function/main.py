import os
from google.cloud import storage, speech_v1p1beta1 as speech

def transcribe_audio(event, context):
    bucket_name = event['bucket']
    audio_file = event['name']

    if not audio_file.startswith('audio/'):
        return

    gcs_uri = f'gs://{bucket_name}/{audio_file}'
    client = speech.SpeechClient()

    audio = speech.RecognitionAudio(uri=gcs_uri)
    config = speech.RecognitionConfig(
        encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
        language_code='it-IT',
        use_enanced=True,
        model= "video",
        enable_automatic_punctuation=True,
    )

    operation = client.long_running_recognize(config=config, audio=audio)
    response = operation.result()

    transcription = ''
    for result in response.results:
        transcription += result.alternatives[0].transcript

    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob('traduzioni/' + os.path.basename(audio_file).replace('.wav', '.txt'))
    blob.upload_from_string(transcription)
