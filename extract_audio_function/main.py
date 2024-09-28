import os
import tempfile
from google.cloud import storage
import subprocess

def extract_audio(event, context):
    bucket_name = event['bucket']
    video_file = event['name']

    if not video_file.startswith('video/'):
        return

    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)

    _, temp_video = tempfile.mkstemp()
    _, temp_audio = tempfile.mkstemp(suffix='.wav')

    blob = bucket.blob(video_file)
    blob.download_to_filename(temp_video)

    subprocess.run(['ffmpeg', '-i', temp_video, temp_audio])

    audio_blob = bucket.blob('audio/' + os.path.basename(video_file).replace('.mp4', '.wav'))
    audio_blob.upload_from_filename(temp_audio)

    os.remove(temp_video)
    os.remove(temp_audio)
