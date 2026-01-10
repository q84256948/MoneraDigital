#!/bin/bash

echo "Starting production server..."

export GIN_MODE=release

./server
