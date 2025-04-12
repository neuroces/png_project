import argparse
from io import BytesIO
from pathlib import Path

import boto3
import matplotlib.pyplot as plt
import numpy as np
from PIL import Image


def read_image_from_s3(bucket: str, key: str):
    """
    Read an image from S3 and return a PIL Image object.
    """
    s3 = boto3.client('s3')
    print(f"Reading image from s3://{bucket}/{key}")
    response = s3.get_object(Bucket=bucket, Key=key)
    image = Image.open(BytesIO(response['Body'].read()))
    # return image and s3 client
    return image, s3

def generate_fft_plot(bucket: str, key: str):
    """
    Generate a 2D FFT plot from an image.
    """
    # Load the image and convert to grayscale
    image, s3 = read_image_from_s3(bucket, key)
    image = image.convert('L')  # grayscale
    image_array = np.array(image)
    h, w = image_array.shape

    # Compute 2D FFT and shift zero frequency to center
    fft_result = np.fft.fft2(image_array)
    fft_shifted = np.fft.fftshift(fft_result)
    magnitude_spectrum = 20 * np.log(np.abs(fft_shifted) + 1)

    # Create frequency bins
    freq_x = np.fft.fftshift(np.fft.fftfreq(w))
    freq_y = np.fft.fftshift(np.fft.fftfreq(h))

    # Set up the plot
    plt.figure(figsize=(6, 6))
    extent = [freq_x[0], freq_x[-1], freq_y[0], freq_y[-1]]
    plt.imshow(magnitude_spectrum, extent=extent, cmap='gray', origin='lower')
    plt.title('2D FFT Magnitude Spectrum')
    plt.xlabel('Normalized Frequency (X)')
    plt.ylabel('Normalized Frequency (Y)')
    plt.colorbar(label='Magnitude (dB)')
    plt.grid(False)
    plt.tight_layout()

    # Save to in-memory buffer
    output_buffer = BytesIO()
    plt.savefig(output_buffer, format='png', dpi=300)
    plt.close()
    output_buffer.seek(0)

    # Construct output S3 key
    input_filename = Path(key).name
    output_key = f"outputs/{Path(input_filename).stem}-fft-plot.png"

    # Upload to S3
    s3.put_object(Bucket=bucket, Key=output_key, Body=output_buffer, ContentType='image/png')

    print(f"FFT plot saved to s3://{bucket}/{output_key}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate FFT plot from an image.")
    parser.add_argument("bucket", help="Name of the S3 bucket")
    parser.add_argument("key", help="Key of the input image file")
    args = parser.parse_args()

    generate_fft_plot(args.bucket, args.key)