FROM --platform=linux/amd64 python:3.12

WORKDIR /app

RUN mkdir __logger

# install google chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg
RUN echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list
RUN apt-get update && apt-get install -y google-chrome-stable

# set display port to avoid crash
ENV DISPLAY=:99

RUN pip install --upgrade pip

COPY . /app

RUN pip install -r requirements.txt

RUN google-chrome --version

CMD ["python", "app.py"]