FROM python:3.12-alpine

WORKDIR /app

RUN apk add --no-cache gcc musl-dev libffi-dev

COPY pyproject.toml setup.py README.md LICENSE ./
COPY bin/ ./bin/

RUN pip install --no-cache-dir cryptography rich .

ENTRYPOINT ["agy-quota"]
CMD ["--help"]
