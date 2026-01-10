#!/bin/bash

echo "Building Go backend..."
go build -o server ./cmd/server/main.go

echo "Starting Backend on port 8081..."
PORT=8081 ./server &

sleep 2

echo "Starting Frontend on port 5000..."
npm run dev
