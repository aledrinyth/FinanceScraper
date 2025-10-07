import json
import os
import sys

def find_chromedriver_url():
    """
    Parses the latest chromedriver version information and prints the URL
    for the linux64 version matching the CHROME_MAJOR_VERSION environment variable.
    """
    with open('/tmp/latest.json') as f:
        data = json.load(f)

    major_version = os.environ.get('MAJOR')
    if not major_version:
        raise SystemExit("MAJOR environment variable not set.")

    for build, meta in data.get('builds', {}).items():
        if build.split('.')[0] == major_version:
            if 'chromedriver' in meta.get('downloads', {}):
                for download in meta['downloads']['chromedriver']:
                    if download.get('platform') == 'linux64':
                        print(download['url'])
                        return

    raise SystemExit(f"No linux64 chromedriver URL found for major version {major_version}")

if __name__ == "__main__":
    find_chromedriver_url()