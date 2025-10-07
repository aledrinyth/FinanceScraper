FROM --platform=linux/amd64 python:3.12

WORKDIR /app

# --- Install Google Chrome (stable) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg unzip \
    # Add these for Chrome to work properly:
    wget \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    xdg-utils \
&& rm -rf /var/lib/apt/lists/*

RUN install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub \
    | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg \
 && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google.list

RUN apt-get update && apt-get install -y --no-install-recommends \
    google-chrome-stable \
 && rm -rf /var/lib/apt/lists/*


# --- Download the EXACT matching ChromeDriver and install to /usr/local/bin ---
# Uses "Chrome for Testing" official buckets; falls back to latest patch for the major version if needed.
RUN set -eux; \
  CHROME_VERSION="$(google-chrome --version | awk '{print $3}')" ; \
  MAJOR="${CHROME_VERSION%%.*}" ; \
  echo "Detected Chrome version: ${CHROME_VERSION} (major ${MAJOR})"; \
  DRIVER_URL="https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chromedriver-linux64.zip"; \
  if ! curl -fsSL -o /tmp/chromedriver.zip "$DRIVER_URL"; then \
    echo "Exact version not found; falling back to latest patch for major ${MAJOR}"; \
    # Pull the 'latest-patch-versions-per-build-with-downloads' JSON and pick linux64 chromedriver for our MAJOR.*
    curl -fsSL -o /tmp/latest.json https://googlechromelabs.github.io/chrome-for-testing/latest-patch-versions-per-build-with-downloads.json; \
    python3 - <<'PY' > /tmp/url.txt
import json, os, re, sys
   data = json.load(open('/tmp/latest.json'))
   major = os.environ['MAJOR']
   found = False
   for build, meta in data['builds'].items():
       if build.split('.')[0] == major:
           if 'chromedriver' in meta.get('downloads', {}):
               for d in meta['downloads']['chromedriver']:
                   if d['platform'] == 'linux64':
                       print(d['url'])
                       found = True
                       break
           if found:
               break
   if not found:
       raise SystemExit("No linux64 chromedriver URL found for major " + major)
PY; \
    curl -fsSL -o /tmp/chromedriver.zip "$(cat /tmp/url.txt)"; \
  fi; \
  unzip -q /tmp/chromedriver.zip -d /opt/chromedriver; \
  mv /opt/chromedriver/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver; \
  chmod +x /usr/local/bin/chromedriver; \
  rm -rf /opt/chromedriver /tmp/chromedriver.zip /tmp/latest.json /tmp/url.txt

# Avoid headless crashes
ENV DISPLAY=:99

# Python deps
RUN pip install --upgrade pip

COPY . /app
# TIP: remove webdriver_manager from requirements.txt if present
RUN sed -i '/webdriver-manager/d' requirements.txt || true
RUN pip install -r requirements.txt

# Quick sanity check
RUN google-chrome --version && /usr/local/bin/chromedriver --version

CMD ["python", "app.py"]
