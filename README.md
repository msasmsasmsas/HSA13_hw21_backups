# HSA13_hw21

PostgreSQL backup strategies

This project demonstrates four different backup strategies for a PostgreSQL database containing a single books table.

The backup strategies include:
```
    Full backup - Using pg_dump to capture the entire database.
    Incremental backup - Using WAL archiving to track and replay database changes.
    Differential backup - Using pg_dump --data-only to periodically store only modified data.
    Reverse Delta backup - Storing the latest full dump and applying WAL logs to roll back step-by-step.
```


# PostgreSQL Backup Strategies with Python

This project demonstrates four different backup strategies for a PostgreSQL database containing a single `books` table, integrated with a Python application for data initialization and population.

---

## Prerequisites
- Docker and Docker Compose installed
- Python 3.x (for the app container)
- Git

---

## Project Setup

Start the PostgreSQL and Python app containers:

```
docker compose -f docker-compose.yml up -d
```

Initialize the `books` table schema:

- **Windows:**
```
Get-Content scripts/init.sql | docker exec -i postgresql-b psql -U postgres -d books_db
```
- **Linux/macOS:**
```
PGPASSWORD=postgres docker exec -i postgresql-b psql -U postgres -d books_db < scripts/init.sql
```

Populate the `books` table with sample data (e.g., 100,000 records, batch size 10,000):

```
docker exec -it app python insert_db.py 100000 --batch-size 10000
```

---

## Backup Strategies

### 1. Full Backup (using pg_dump)

A full backup captures the entire database: schema, data, indexes, and constraints.

**Create Full Backup:**
```
time docker exec -t postgresql-b pg_dump -U postgres -d books_db -F c -f /tmp/full_backup.dump
```
- `time` measures the execution duration.

**Copy to Host:**
```
docker cp postgresql-b:/tmp/full_backup.dump ./full_backup.dump
```

**Restore Full Backup:**
```
time docker exec -t postgresql-b pg_restore -U postgres -d books_db /tmp/full_backup.dump
```

---

### 2. Incremental Backup (using WAL)

Incremental backups use Write-Ahead Logging (WAL) to track database changes.

**Ensure WAL Archiving is Enabled:**
- The `postgresql.conf` file must have `wal_level = replica`, `archive_mode = on`, and an `archive_command` set (see configuration above).

**Create Base Backup:**
```
time docker exec postgresql-b pg_basebackup -D /var/lib/postgresql/base_backup -Ft -z -P -X fetch
```
```
docker cp postgresql-b:/var/lib/postgresql/base_backup ./base_backup
```

**Make Changes:**
- Add more records to generate WAL segments:
```
docker exec -it app python insert_db.py 1000 --batch-size 500
```

**Copy WAL Logs:**
```
time docker cp postgresql-b:/var/lib/postgresql/wal_archive ./wal_archive_backup
```

**Restore Incremental Backup:**
1. Stop the container and clear data:
```
docker stop postgresql-b
sudo rm -rf ./postgres_data
```
2. Extract base backup:
```
mkdir ./postgres_data
tar -xvf ./base_backup/base.tar -C ./postgres_data
```
3. Copy base backup to container:
```
docker cp ./postgres_data postgresql-b:/var/lib/postgresql/data
```
4. Start the container:
```
docker start postgresql-b
```
5. Copy WAL logs back:
```
docker cp ./wal_archive_backup postgresql-b:/var/lib/postgresql/wal_archive
```
6. Replay WAL logs:
```
time docker exec postgresql-b psql -U postgres -d books_db -c "SELECT pg_wal_replay_resume();"
```

---

### 3. Differential Backup (using pg_dump --data-only)

Differential backups store only modified data since the last full backup.

**Create Full Backup (Baseline):**
```
time docker exec postgresql-b pg_dump -U postgres -d books_db -F c -f /var/lib/postgresql/data/full_backup.dump
```
```
docker cp postgresql-b:/var/lib/postgresql/data/full_backup.dump ./full_backup.dump
```

**Make Changes:**
```
docker exec -it app python insert_db.py 5000 --batch-size 1000
```

**Backup Schema Separately:**
```
time docker exec postgresql-b pg_dump -U postgres -d books_db --schema-only -f /var/lib/postgresql/data/schema_backup.sql
```
```
docker cp postgresql-b:/var/lib/postgresql/data/schema_backup.sql ./schema_backup.sql
```

**Backup Modified Data:**
```
time docker exec postgresql-b pg_dump -U postgres -d books_db --data-only --table=books -f /var/lib/postgresql/data/books_diff_backup.sql
```
```
docker cp postgresql-b:/var/lib/postgresql/data/books_diff_backup.sql ./books_diff_backup.sql
```

**Restore Differential Backup:**
1. Stop the container and clear data:
```
docker stop postgresql-b
sudo rm -rf ./postgres_data ./wal_archive
```
2. Copy schema and differential data:
```
docker cp ./schema_backup.sql postgresql-b:/var/lib/postgresql/data/schema_backup.sql
docker cp ./books_diff_backup.sql postgresql-b:/var/lib/postgresql/data/books_diff_backup.sql
```
3. Apply schema:
```
time docker exec postgresql-b psql -U postgres -d books_db -f /var/lib/postgresql/data/schema_backup.sql
```
4. Start the container:
```
docker start postgresql-b
```
5. Apply differential data:
```
time docker exec postgresql-b psql -U postgres -d books_db -f /var/lib/postgresql/data/books_diff_backup.sql
```

---

### 4. Reverse Delta Backup (Latest Full + WAL)

Reverse Delta backups store the latest full backup and use WAL logs to roll back to previous states.

**Create Latest Full Backup:**
```
time docker exec postgresql-b pg_dump -U postgres -d books_db -F c -f /var/lib/postgresql/data/latest_full_backup.dump
```
```
docker cp postgresql-b:/var/lib/postgresql/data/latest_full_backup.dump ./latest_full_backup.dump
```

**Make Changes:**
```
docker exec -it app python insert_db.py 2000 --batch-size 500
```

**Copy WAL Logs:**
```
time docker cp postgresql-b:/var/lib/postgresql/wal_archive ./wal_archive_backup
```

**Restore Reverse Delta Backup:**
1. Stop the container and clear data:
```
docker stop postgresql-b
sudo rm -rf ./postgres_data ./wal_archive
```
2. Copy and restore the latest full backup:
```
mkdir ./postgres_data
docker cp ./latest_full_backup.dump postgresql-b:/var/lib/postgresql/data/latest_full_backup.dump
time docker exec postgresql-b pg_restore -U postgres -d books_db /var/lib/postgresql/data/latest_full_backup.dump
```
3. Copy WAL logs back:
```
docker cp ./wal_archive_backup postgresql-b:/var/lib/postgresql/wal_archive
```
4. Start the container:
```
docker start postgresql-b
```
5. Replay WAL logs for point-in-time recovery:
```
time docker exec postgresql-b psql -U postgres -d books_db -c "SELECT pg_wal_replay_resume();"
```

---

## Comparison of Backup Strategies

| Backup Type                  | Size                          | Restore Speed         | Rollback Ability            | Cost                          |
|------------------------------|-------------------------------|-----------------------|-----------------------------|-------------------------------|
| Full (pg_dump)              | Large                        | Fast                 | Only to last backup         | High storage cost            |
| Incremental (WAL)           | Small                        | Fast (Point-in-time) | Precise rollback            | WAL archiving setup          |
| Differential (pg_dump --data-only) | Medium                  | Moderate             | Only to last diff backup    | Saves space, slower rollback |
| Reverse Delta (pg_dump + WAL) | Medium (WAL grows quickly) | Moderate             | Step-by-step rollback       | Storage cost for WAL         |

### Recommendations:
- **Full Backup:** Ideal for small datasets or infrequent backups.  
- **Incremental Backup:** Best for large, frequently changing data with minimal storage use.  
- **Differential Backup:** A compromise for medium-sized datasets with moderate rollback needs.  
- **Reverse Delta Backup:** Useful for fast recovery of the latest state (e.g., cloud services).

---
