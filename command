
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

docker compose -f docker-compose.yml down


