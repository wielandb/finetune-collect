import argparse
import requests

# Small 1x1 red pixel PNG encoded in base64
TEST_IMAGE_B64 = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMDBC0DbS8AAAAASUVORK5CYII="
)

def upload_image(url: str, key: str, ext: str = "png") -> str:
    """Upload a test image to the given URL. Returns the image URL."""
    payload = {
        "key": key,
        "image": TEST_IMAGE_B64,
        "ext": ext,
    }
    try:
        response = requests.post(url, data=payload, timeout=10)
    except Exception as e:
        print(f"Upload request failed: {e}")
        return ""

    print(f"Upload HTTP status: {response.status_code}")
    if response.status_code != 200:
        print(f"Upload failed with body: {response.text}")
        return ""

    image_url = response.text.strip()
    print(f"Server returned image URL: {image_url}")
    return image_url

def fetch_image(image_url: str) -> bool:
    """Fetch the uploaded image and print diagnostics."""
    try:
        response = requests.get(image_url, timeout=10)
    except Exception as e:
        print(f"Download request failed: {e}")
        return False

    print(f"Download HTTP status: {response.status_code}")
    if response.status_code != 200:
        print(f"Download failed with body: {response.text}")
        return False

    content_type = response.headers.get("Content-Type", "")
    print(f"Content-Type: {content_type}")
    print(f"Image size: {len(response.content)} bytes")
    if not content_type.startswith("image/"):
        print("Warning: Response is not an image.")
    return True

def main() -> None:
    parser = argparse.ArgumentParser(description="Test image-upload.php")
    parser.add_argument("url", help="URL to image-upload.php")
    parser.add_argument("--key", default="CHANGE_ME", help="Secret key for upload")
    parser.add_argument("--ext", default="png", help="Image extension to use")
    args = parser.parse_args()

    img_url = upload_image(args.url, args.key, args.ext)
    if not img_url:
        print("Image upload failed.")
        return

    if fetch_image(img_url):
        print("Image uploaded and retrieved successfully.")
    else:
        print("Failed to retrieve uploaded image.")

if __name__ == "__main__":
    main()
