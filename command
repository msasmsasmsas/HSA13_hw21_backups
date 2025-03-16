
docker network prune -f
docker compose down
docker-compose up -d


git clone -b main https://github.com/msasmsasmsas/HSA13_hw20_db_sharding .


git init
git remote add origin https://github.com/msasmsasmsas/HSA13_hw20_db_sharding
git config --global --add safe.directory E:/HSA13/HSA13_hw20_db_sharding
git remote add origin https://github.com/msasmsasmsas/HSA13_hw20_db_sharding

git fetch origin
git checkout main
git merge origin/main



docker compose -f docker-compose.yml up -d
#win
Get-Content scripts/init.sql | docker exec -i  postgresql-b psql -U postgres -d books_db
#nix
PGPASSWORD=postgres docker exec -i postgresql-b psql -U postgres -d books_db < scripts/init.sql
docker exec -it app python insert_db.py 1000000 --batch-size 100000

time docker exec -t postgresql-b pg_dump -U postgres -d books_db -F c -f /tmp/full_backup.dump

docker cp postgresql-b:/tmp/full_backup.dump ./full_backup.dump

docker cp ./full_backup.dump postgresql-b:/tmp/full_backup.dump
time docker exec -t postgresql-b pg_restore -U postgres -d books_db /tmp/full_backup.dump

# Incremental Backup with WAL

docker exec -it postgresql-b bash -c "echo 'wal_level = replica' >> /var/lib/postgresql/data/postgresql.conf"
docker exec -it postgresql-b bash -c "echo 'archive_mode = on' >> /var/lib/postgresql/data/postgresql.conf"
docker exec -it postgresql-b bash -c "echo 'archive_command = \"cp %p /var/lib/postgresql/wal_archive/%f\"' >> /var/lib/postgresql/data/postgresql.conf"
docker restart postgresql-b

time docker exec postgresql-b pg_basebackup -D /var/lib/postgresql/base_backup -Ft -z -P -X fetch
docker cp postgresql-b:/var/lib/postgresql/base_backup ./base_backup

docker cp postgresql-b:/var/lib/postgresql/wal_archive ./wal_archive_backup


docker stop postgresql-b
sudo rm -rf ./postgres_data
mkdir ./postgres_data
time tar -xvf ./base_backup/base.tar -C ./postgres_data
docker cp ./postgres_data postgresql-b:/var/lib/postgresql/data
docker cp ./wal_archive_backup postgresql-b:/var/lib/postgresql/wal_archive
docker start postgresql-b
time docker exec postgresql-b psql -U postgres -d books_db -c "SELECT pg_wal_replay_resume();"


# Differential Backup

time docker exec postgresql-b pg_dump -U postgres -d books_db -F c -f /tmp/full_backup.dump
docker cp postgresql-b:/tmp/full_backup.dump ./full_backup.dump

docker exec postgresql-b pg_dump -U postgres -d books_db --schema-only -f /tmp/schema_backup.sql
docker cp postgresql-b:/tmp/schema_backup.sql ./schema_backup.sql

time docker exec postgresql-b pg_dump -U postgres -d books_db --data-only --table=books -f /tmp/books_diff_backup.sql
docker cp postgresql-b:/tmp/books_diff_backup.sql ./books_diff_backup.sql

#restor
docker stop postgresql-b
sudo rm -rf ./postgres_data
mkdir ./postgres_data
docker cp ./schema_backup.sql postgresql-b:/tmp/schema_backup.sql
docker cp ./books_diff_backup.sql postgresql-b:/tmp/books_diff_backup.sql
time docker exec postgresql-b psql -U postgres -d books_db -f /tmp/schema_backup.sql
docker start postgresql-b
time docker exec postgresql-b psql -U postgres -d books_db -f /tmp/books_diff_backup.sql


#Reverse Delta Backup

time docker exec postgresql-b pg_dump -U postgres -d books_db -F c -f /tmp/latest_full_backup.dump
docker cp postgresql-b:/tmp/latest_full_backup.dump ./latest_full_backup.dump

docker cp postgresql-b:/var/lib/postgresql/wal_archive ./wal_archive_backup

#restor
docker stop postgresql-b
sudo rm -rf ./postgres_data
mkdir ./postgres_data
docker cp ./latest_full_backup.dump postgresql-b:/tmp/latest_full_backup.dump
time docker exec postgresql-b pg_restore -U postgres -d books_db /tmp/latest_full_backup.dump
docker cp ./wal_archive_backup postgresql-b:/var/lib/postgresql/wal_archive
docker start postgresql-b
time docker exec postgresql-b psql -U postgres -d books_db -c "SELECT pg_wal_replay_resume();"

docker compose -f docker-compose.yml down


