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

COPY get_chromedriver_url.py /app/get_chromedriver_url.py

# --- Download the EXACT matching ChromeDriver and install to /usr/local/bin ---
# Uses "Chrome for Testing" official buckets; falls back to latest patch for the major version if needed.
RUN set -eux; \
  CHROME_VERSION="$(google-chrome --version | awk '{print $3}')"; \
  export MAJOR="${CHROME_VERSION%%.*}"; \
  echo "Detected Chrome version: ${CHROME_VERSION} (major version: ${MAJOR})"; \
  # First, try to get the exact version match
  DRIVER_URL="https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chromedriver-linux64.zip"; \
  if ! curl -fsSL -o /tmp/chromedriver.zip "$DRIVER_URL"; then \
    echo "Exact version not found, falling back to latest patch for major version ${MAJOR}..."; \
    # If the exact match fails, download the JSON for the latest patch versions
    curl -fsSL -o /tmp/latest.json https://googlechromelabs.github.io/chrome-for-testing/latest-patch-versions-per-build-with-downloads.json; \
    # Use the separate Python script to find and set the fallback URL
    FALLBACK_URL=$(python3 /app/get_chromedriver_url.py); \
    echo "Found fallback URL: ${FALLBACK_URL}"; \
    curl -fsSL -o /tmp/chromedriver.zip "$FALLBACK_URL"; \
  fi; \
  # Unzip and install ChromeDriver
  unzip -q /tmp/chromedriver.zip -d /opt/chromedriver; \
  mv /opt/chromedriver/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver; \
  chmod +x /usr/local/bin/chromedriver; \
  # Clean up temporary files
  rm -rf /opt/chromedriver /tmp/chromedriver.zip /tmp/latest.json;

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