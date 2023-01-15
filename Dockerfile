FROM python:3.10

WORKDIR /python-docker

COPY requirements.txt requirements.txt
RUN pip3 install -r requirements.txt

COPY app.py app.py
COPY templates templates/

ENV FLASK_APP=app.py
ENV FLASK_ENV=development

CMD [ "flask", "run", "--host=0.0.0.0"]
