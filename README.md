# HSA13_hw21

PostgreSQL backup strategies

This project demonstrates four different backup strategies for a PostgreSQL database containing a single books table.

The backup strategies include:

    Full backup - Using pg_dump to capture the entire database.
    Incremental backup - Using WAL archiving to track and replay database changes.
    Differential backup - Using pg_dump --data-only to periodically store only modified data.
    Reverse Delta backup - Storing the latest full dump and applying WAL logs to roll back step-by-step.

Example of usage

1. Full backup using pg_dump

A full backup captures everything: schema, data, indexes, and constraints.

```
docker exec -t postgresql-b pg_dump -U postgres -d books_db -F c -f /tmp/full_backup.dump
```

To restore:
```
docker exec -t postgresql-b pg_restore -U postgres -d books_db /tmp/full_backup.dump
```

Important!

Actions before each next backup strategy:
```
    Comment - ./init.sql:/docker-entrypoint-initdb.d/init.sql volume instruction in postgres container before run docker-compose up

    Help script to create table and add some test data for books_db in postgres container:

    ./insert_books.sh   
```

2. Incremental backup using WAL (Write-Ahead Logging)

postgresql.conf with WAL settings enables WAL archiving and stores the WAL files in /var/lib/postgresql/wal_archive

To copy from the container to local machine:

```
docker cp postgresql-b:/var/lib/postgresql/wal_archive ./wal_backup
```
Ensure a proper base backup is taken:
```
docker exec postgresql-b pg_basebackup -D /var/lib/postgresql/base_backup -Ft -z -P -X fetch
docker cp postgresql-b:/var/lib/postgresql/base_backup ./base_backup
```
Perform some database changes to generate new WAL segments

Copy the WAL logs:
```
docker cp postgresql-b:/var/lib/postgresql/wal_archive ./wal_archive_backup
```

Restore the Base Backup
```
docker stop postgresql-b
sudo rm -rf ./postgres_data
```

Extract the base backup:
```
mkdir ./postgres_data
tar -xvf ./base_backup/base.tar -C ./postgres_data
```

Copy the extracted base backup to the container:
```
docker cp ./postgres_data postgresql-b:/var/lib/postgresql/data
```
Start the container: docker start postgresql-b

Copy back the archived WAL logs:
```
docker cp ./wal_archive_backup postgresql-b:/var/lib/postgresql/wal_archive
```

Start WAL replay inside postgres container:
```
docker exec postgresql-b psql -U postgres -d books_db -c "SELECT pg_wal_replay_resume();"
```
3. Differential backup using pg_dump --data-only

Take a full backup of your database using pg_dump:
```
docker exec postgresql-b pg_dump -U postgres -d books_db -F c -f /var/lib/postgresql/data/full_backup.dump
```
Copy the full backup to the host machine:
```
docker cp postgresql-b:/var/lib/postgresql/data/full_backup.dump ./full_backup.dump
```
Perform some data changes for books_db

Back up the schema separately to ensure structural integrity:
```
docker exec postgresql-b pg_dump -U postgres -d books_db --schema-only -f /var/lib/postgresql/data/schema_backup.sql
docker cp postgresql-b:/var/lib/postgresql/data/schema_backup.sql ./schema_backup.sql
```
Instead of dumping the entire database, back up only modified tables:
```
docker exec postgresql-b pg_dump -U postgres -d books_db --data-only --table=books -f /var/lib/postgresql/data/books_diff_backup.sql
```
Copy the backup to the host:
```
docker cp postgresql-b:/var/lib/postgresql/data/books_diff_backup.sql ./books_diff_backup.sql
```
Rolling back to a previous state

Stop the container and remove the database files:
```
docker stop postgresql-b
sudo rm -rf ./wal_archive ./postgres_data
```
Ensure that, during restoration, the schema is restored first, followed by the differential data:
```
docker cp ./schema_backup.sql postgresql-b:/var/lib/postgresql/data/schema_backup.sql
docker cp ./books_diff_backup.sql postgresql-b:/var/lib/postgresql/data/books_diff_backup.sql
```
Apply the schema backup:
```
docker exec postgresql-b psql -U postgres -d books_db -f /var/lib/postgresql/data/schema_backup.sql
```
Start the container: docker start postgresql-b

Apply the differential backup:
```
docker exec postgresql-b psql -U postgres -d books_db -f /var/lib/postgresql/data/books_diff_backup.sql
```
4. Reverse Delta Backup (Last full + WAL differences)

Create a full backup inside the container:
```
docker exec postgresql-b pg_dump -U postgres -d books_db -F c -f /var/lib/postgresql/data/latest_full_backup.dump
```
To copy the backup to the host machine:
```
docker cp postgresql-b:/var/lib/postgresql/data/latest_full_backup.dump ./latest_full_backup.dump
```
Add new records to books_db

Copy the WAL logs from the container to the host:
```
docker cp postgresql-b:/var/lib/postgresql/wal_archive ./wal_archive_backup
```
Rolling back to a previous state

Stop the container and remove the database files:
```
docker stop postgresql-b
sudo rm -rf ./wal_archive ./postgres_data
```
Restore the last full backup:
```
mkdir ./postgres_data
docker cp ./latest_full_backup.dump postgresql-b:/var/lib/postgresql/data/latest_full_backup.dump
docker exec postgresql-b pg_restore -U postgres -d books_db /var/lib/postgresql/data/latest_full_backup.dump
```
Copy back the stored WAL logs:
```
docker cp ./wal_archive_backup postgresql-b:/var/lib/postgresql/wal_archive
```
Start the container: docker start postgresql-b

Then, use postgres point-in-time recovery:
```
docker exec postgresql-b psql -U postgres -d books_db -c "SELECT pg_wal_replay_resume();"
```
Comparison
Backup Type 	Size 	Restore Speed 	Rollback Ability 	Cost
Full (pg_dump) 	Large 	Fast 	Only to last backup 	Storage cost for full backup
Incremental (WAL) 	Small 	Fast (Point-in-time) 	Precise rollback 	Requires WAL archiving setup
Differential (pg_dump --data-only) 	Medium 	Moderate 	Only to last diff backup 	Saves space, but slower rollback
Reverse Delta (pg_dump + WAL) 	Medium (Depends on change frequency; WAL grows quickly) 	Moderate 	Step-by-step rollback to previous known snapshots 	Storage cost for WAL

Full backup – suitable for small amounts of data or infrequent backups.

Incremental – saves storage space but is complex to restore. Suitable for large, frequently changing data.

Differential – a compromise between Full and Incremental, suitable for medium-sized data.

Reverse Delta – convenient when fast recovery of the latest version is important (e.g., for cloud services or CDNs).
