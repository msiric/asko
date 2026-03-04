-- asko: Initialize per-service databases with pgvector
-- This runs on first PostgreSQL startup only
-- Note: 'asko' database is auto-created by POSTGRES_DB env var
\set ON_ERROR_STOP on

CREATE DATABASE asko_n8n;
CREATE DATABASE asko_openwebui;

\c asko
CREATE EXTENSION IF NOT EXISTS vector;

\c asko_openwebui
CREATE EXTENSION IF NOT EXISTS vector;
