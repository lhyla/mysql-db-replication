#!/bin/bash
set -e

echo "Starting sync replication"
query="INSTALL PLUGIN rpl_semi_sync_source SONAME 'semisync_source.so';"
start_semisync_source_cmd='mysql -u root --password=password -e "'
start_semisync_source_cmd+="$query"
start_semisync_source_cmd+='"'
docker exec source sh -c "$start_semisync_source_cmd" || true
docker exec source sh -c "mysql -u root --password=password -e 'SET PERSIST rpl_semi_sync_source_enabled = 1;'"

# If transaction is not committed by replica in less than 20s, the replication switches automatically to async replication
# To enable sync replication again - restart of the source is necessary
docker exec source sh -c "mysql -u root --password=password -e 'SET PERSIST rpl_semi_sync_source_timeout = 20000;'"

query="INSTALL PLUGIN rpl_semi_sync_replica SONAME 'semisync_replica.so';"
start_semisync_replica_cmd='mysql -u root --password=password -e "'
start_semisync_replica_cmd+="$query"
start_semisync_replica_cmd+='"'
docker exec replica sh -c "$start_semisync_replica_cmd" || true
docker exec replica sh -c "mysql -u root --password=password -e 'SET PERSIST rpl_semi_sync_replica_enabled = 1;'"

echo "Restarting source"
docker restart source
until docker exec source sh -c 'mysql -u root --password=password -e ";"'
do
    echo "Waiting until the source server is restarted"
    sleep 4
done

echo "Source data:"
docker exec source sh -c "mysql -u root --password=password -D db1 -e 'CREATE TABLE IF NOT EXISTS test (id int); INSERT INTO test values(2); SELECT * FROM test \G;'"

# Because it`s sync replication, data must match between replica and source!
echo "Replica data:"
docker exec replica sh -c "mysql -u root --password=password -D db1 -e 'SELECT * FROM test \G;'"

echo "Sync replication started!"