FROM python:3.9-slim

WORKDIR /App

COPY src src

COPY requirements.txt .

RUN pip install -r requirements.txt

EXPOSE 5000

ENTRYPOINT [ "python" ]

CMD ["src/colors.py"]
