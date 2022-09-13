#!/bin/bash
set -e
echo "Setting up async replication"
until docker exec source sh -c 'mysql -u root --password=password -e ";"'
do
    echo "Waiting until the source server is up"
    sleep 4
done
echo "Source is up!"

query='CREATE USER IF NOT EXISTS "replicator"@"%" IDENTIFIED BY "password"; GRANT REPLICATION SLAVE ON *.* TO "replicator"@"%"; FLUSH PRIVILEGES;'
docker exec source sh -c "mysql -u root --password=password -e '$query'"

until docker exec replica sh -c 'mysql -u root --password=password -e ";"'
do
    echo "Waiting until the replica server is up"
    sleep 4
done

start_replica_query="CHANGE REPLICATION SOURCE TO SOURCE_HOST='source',SOURCE_USER='replicator',SOURCE_PASSWORD='password',GET_SOURCE_PUBLIC_KEY=1, SOURCE_CONNECT_RETRY=10; START REPLICA;"
start_replica_cmd='mysql -u root --password=password -e "'
start_replica_cmd+="$start_replica_query"
start_replica_cmd+='"'
docker exec replica sh -c "$start_replica_cmd"

echo "Replica status:"
docker exec replica sh -c "mysql -u root --password=password -e 'SHOW SLAVE STATUS \G'"

echo "Source status:"
docker exec source sh -c "mysql -u root --password=password -e 'SHOW MASTER STATUS \G'"

docker exec source sh -c "mysql -u root --password=password -D db1 -e 'CREATE TABLE IF NOT EXISTS test (id int); INSERT INTO test values(1); SELECT * FROM test \G;'"
# Because this is async replication, in case of latency - the table & the record may not be yet replicated!
docker exec replica sh -c "mysql -u root --password=password -D db1 -e 'SELECT * FROM test \G;'"

echo "Async replication started!"