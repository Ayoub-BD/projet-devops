FROM python:3.14-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && pip uninstall -y pip

COPY . .

EXPOSE 5000

CMD ["flask", "run", "--host=0.0.0.0"]