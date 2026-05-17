#!/bin/bash

# ============================================================
# 🚀 DEVELOP SERVERLESS APPS WITH FIREBASE - CHALLENGE LAB
# ============================================================

set -e

# ---------- COLORS ----------
GREEN='\033[0;92m'
RED='\033[0;91m'
YELLOW='\033[0;93m'
BLUE='\033[0;94m'
CYAN='\033[0;96m'
BOLD='\033[1m'
NC='\033[0m'

clear

echo -e "${CYAN}${BOLD}"
echo "======================================================="
echo "   DEVELOP SERVERLESS APPS WITH FIREBASE - AUTO LAB"
echo "======================================================="
echo -e "${NC}"

# ---------- USER INPUT ----------
read -p "Enter REGION (example: us-west1): " REGION

if [[ -z "$REGION" ]]; then
  echo -e "${RED}Region cannot be empty.${NC}"
  exit 1
fi

# ---------- PROJECT ----------
PROJECT_ID=$(gcloud config get-value project)

if [[ -z "$PROJECT_ID" ]]; then
  echo -e "${RED}No active GCP project found.${NC}"
  exit 1
fi

echo
echo -e "${GREEN}Using Project:${NC} $PROJECT_ID"
echo -e "${GREEN}Using Region:${NC} $REGION"
echo

# ---------- VARIABLES ----------
DATASET_SERVICE="netflix-dataset-service"
FRONTEND_STAGING_SERVICE="frontend-staging-service"
FRONTEND_PRODUCTION_SERVICE="frontend-production-service"
AR_REPO="rest-api-repo"

# ---------- ENABLE APIS ----------
echo -e "${BLUE}Enabling required APIs...${NC}"

gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  firestore.googleapis.com

# ---------- TASK 1 ----------
echo
echo -e "${CYAN}${BOLD}[TASK 1] Creating Firestore Database${NC}"

gcloud firestore databases create \
  --location=$REGION \
  --type=firestore-native || true

sleep 10

# ---------- CLONE REPO ----------
echo
echo -e "${BLUE}Preparing lab files...${NC}"

rm -rf ~/pet-theory

git clone https://github.com/rosera/pet-theory.git ~/pet-theory

# ---------- TASK 2 ----------
echo
echo -e "${CYAN}${BOLD}[TASK 2] Importing CSV into Firestore${NC}"

cd ~/pet-theory/lab06/firebase-import-csv/solution

npm install

node index.js netflix_titles_original.csv

# ---------- ARTIFACT REGISTRY ----------
echo
echo -e "${CYAN}${BOLD}Creating Artifact Registry Repository${NC}"

gcloud artifacts repositories create $AR_REPO \
  --repository-format=docker \
  --location=$REGION || true

gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

# ---------- TASK 3 ----------
echo
echo -e "${CYAN}${BOLD}[TASK 3] Deploying REST API v0.1${NC}"

cd ~/pet-theory/lab06/firebase-rest-api/solution-01

npm install

gcloud builds submit \
  --tag ${REGION}-docker.pkg.dev/$PROJECT_ID/$AR_REPO/rest-api:0.1

gcloud run deploy $DATASET_SERVICE \
  --image ${REGION}-docker.pkg.dev/$PROJECT_ID/$AR_REPO/rest-api:0.1 \
  --region=$REGION \
  --platform=managed \
  --allow-unauthenticated \
  --max-instances=1 \
  --quiet

SERVICE_URL=$(gcloud run services describe $DATASET_SERVICE \
  --region=$REGION \
  --format='value(status.url)')

echo
echo -e "${GREEN}REST API URL:${NC} $SERVICE_URL"

curl -X GET $SERVICE_URL

# ---------- TASK 4 ----------
echo
echo -e "${CYAN}${BOLD}[TASK 4] Deploying REST API v0.2${NC}"

cd ~/pet-theory/lab06/firebase-rest-api/solution-02

npm install

gcloud builds submit \
  --tag ${REGION}-docker.pkg.dev/$PROJECT_ID/$AR_REPO/rest-api:0.2

gcloud run deploy $DATASET_SERVICE \
  --image ${REGION}-docker.pkg.dev/$PROJECT_ID/$AR_REPO/rest-api:0.2 \
  --region=$REGION \
  --platform=managed \
  --allow-unauthenticated \
  --max-instances=1 \
  --quiet

SERVICE_URL=$(gcloud run services describe $DATASET_SERVICE \
  --region=$REGION \
  --format='value(status.url)')

echo
echo -e "${GREEN}Updated REST API URL:${NC} $SERVICE_URL"

curl -X GET $SERVICE_URL/2019

# ---------- TASK 5 ----------
echo
echo -e "${CYAN}${BOLD}[TASK 5] Deploying Staging Frontend${NC}"

cd ~/pet-theory/lab06/firebase-frontend

sed -i "s|REACT_APP_API_SERVICE|$SERVICE_URL|g" .env

gcloud builds submit \
  --tag ${REGION}-docker.pkg.dev/$PROJECT_ID/$AR_REPO/frontend-staging:0.1

gcloud run deploy $FRONTEND_STAGING_SERVICE \
  --image ${REGION}-docker.pkg.dev/$PROJECT_ID/$AR_REPO/frontend-staging:0.1 \
  --region=$REGION \
  --platform=managed \
  --allow-unauthenticated \
  --max-instances=1 \
  --quiet

STAGING_URL=$(gcloud run services describe $FRONTEND_STAGING_SERVICE \
  --region=$REGION \
  --format='value(status.url)')

echo
echo -e "${GREEN}Staging Frontend URL:${NC} $STAGING_URL"

# ---------- TASK 6 ----------
echo
echo -e "${CYAN}${BOLD}[TASK 6] Deploying Production Frontend${NC}"

cd ~/pet-theory/lab06/firebase-frontend/public

sed -i "s|const API_SERVICE_URL = .*|const API_SERVICE_URL = '$SERVICE_URL/2020';|g" app.js

cd ..

gcloud builds submit \
  --tag ${REGION}-docker.pkg.dev/$PROJECT_ID/$AR_REPO/frontend-production:0.1

gcloud run deploy $FRONTEND_PRODUCTION_SERVICE \
  --image ${REGION}-docker.pkg.dev/$PROJECT_ID/$AR_REPO/frontend-production:0.1 \
  --region=$REGION \
  --platform=managed \
  --allow-unauthenticated \
  --max-instances=1 \
  --quiet

PROD_URL=$(gcloud run services describe $FRONTEND_PRODUCTION_SERVICE \
  --region=$REGION \
  --format='value(status.url)')

# ---------- FINAL OUTPUT ----------
echo
echo -e "${CYAN}${BOLD}=======================================================${NC}"
echo -e "${GREEN}${BOLD}LAB COMPLETED SUCCESSFULLY${NC}"
echo -e "${CYAN}${BOLD}=======================================================${NC}"
echo
echo -e "${GREEN}REST API URL:${NC} $SERVICE_URL"
echo -e "${GREEN}Staging Frontend URL:${NC} $STAGING_URL"
echo -e "${GREEN}Production Frontend URL:${NC} $PROD_URL"
echo
echo -e "${YELLOW}Run these tests manually if needed:${NC}"
echo
echo "curl -X GET $SERVICE_URL"
echo "curl -X GET $SERVICE_URL/2019"
echo