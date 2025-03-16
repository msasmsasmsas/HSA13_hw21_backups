#!/bin/bash

# Check if backup file is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <backup_file.tar.gz>"
  exit 1
fi

# Variables
BACKUP_FILE="$1"

# Check if file exists
if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: File $BACKUP_FILE does not exist"
  exit 1
fi

# Restore backup
tar -xzf "$BACKUP_FILE"

if [ $? -eq 0 ]; then
  echo "Backup restored successfully from: $BACKUP_FILE"
else
  echo "Restore failed!"
  exit 1
fi