#!/bin/bash

# Check if directory path is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <directory_to_backup>"
  exit 1
fi

# Variables
SOURCE_DIR="$1"
BACKUP_NAME="backup-$(date +%Y%m%d-%H%M).tar.gz"

# Create backup
tar -czf "$BACKUP_NAME" "$SOURCE_DIR"

if [ $? -eq 0 ]; then
  echo "Backup created successfully: $BACKUP_NAME"
else
  echo "Backup failed!"
  exit 1
fi