#!/usr/bin/env bash
# Construit le paquet de déploiement Lambda : build/lambda.zip
# Les dépendances sont téléchargées pour Linux x86_64 / Python 3.12 (le runtime Lambda),
# quelle que soit la machine qui exécute le script.
set -euo pipefail

cd "$(dirname "$0")/.."
rm -rf build
mkdir -p build/package

pip install \
  --quiet \
  --requirement app/requirements.txt \
  --target build/package \
  --platform manylinux2014_x86_64 \
  --implementation cp \
  --python-version 3.12 \
  --only-binary=:all:

# Code de l'application, sans les tests ni les caches.
mkdir -p build/package/app
cp app/__init__.py app/models.py build/package/app/
cp -r app/handlers build/package/app/
find build/package -type d -name "__pycache__" -prune -exec rm -rf {} +

(cd build/package && zip -q -r ../lambda.zip .)
echo "Paquet créé : build/lambda.zip ($(du -h build/lambda.zip | cut -f1))"
