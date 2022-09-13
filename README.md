# Async and Sync replication of MySql DB using Docker

## Requirements
- docker (version 20.10+)
- docker-compose (1.28+)


### Deploy source & replica containers and setup async replication (Only for Linux/Macos)
Go to directory where all configuration files and scripts are:
```bash
cd replica-single-db/docker
```

Execute scripts to start async replication:
```bash
./down.sh && \
 ./deploy.sh && \
 ./startAsyncReplication.sh
```

Start sync replication execute (after setting async replication):
```text
./startSyncReplication.sh
```

### Step-by-step configuration (Works on Windows as well):
```bash
docker-compose down -v
docker-compose up -d

# Wait until the source and replica are up. You can watch logs during that time:
docker-compose logs -f

# Log to Source Mysql console (Wait till the source container is up! It need around 20-30s when starting up for the 1st time)
docker exec -it source mysql -u root --password=password
# Execute query to add replicator user:
CREATE USER IF NOT EXISTS "replicator"@"%" IDENTIFIED BY "password"; GRANT REPLICATION SLAVE ON *.* TO "replicator"@"%"; FLUSH PRIVILEGES;
# To enable sync replication (optional) on source side execute (sync replication will start only if it`s also enabled on replica side):
INSTALL PLUGIN rpl_semi_sync_source SONAME 'semisync_source.so'; SET PERSIST rpl_semi_sync_source_enabled = 1; SET PERSIST rpl_semi_sync_source_timeout = 20000;
# Exit source MySQL console
exit

# Log to Replica Mysql console
docker exec -it replica mysql -u root --password=password
# Execute query to start async replication
CHANGE REPLICATION SOURCE TO SOURCE_HOST='source', SOURCE_USER='replicator', SOURCE_PASSWORD='password', GET_SOURCE_PUBLIC_KEY=1, SOURCE_CONNECT_RETRY=10; START REPLICA;
## Enable sync replication (optional)
INSTALL PLUGIN rpl_semi_sync_replica SONAME 'semisync_replica.so'; SET PERSIST rpl_semi_sync_replica_enabled = 1;
# Exit replica MySQL console
exit

# Restart source container (Needed only to start sync replication. No need to restart source to start async replication)
docker restart source

# Test the replication - Create some test table on source and insert one record:
docker exec source sh -c "mysql -u root --password=password -D db1 -e 'CREATE TABLE IF NOT EXISTS test (id int); INSERT INTO test values(1); SELECT * FROM test \G;'"

# Get the replicated data from replica: 
docker exec source sh -c "mysql -u root --password=password -D db1 -e 'SELECT * FROM test \G;'"
```

## Important info about the sync replication:

```text
With semisynchronous replication, if the source crashes and a failover to a replica is carried out, the failed source should not be reused as the replication source, and should be discarded. It could have transactions that were not acknowledged by any replica, which were therefore not committed before the failover.
If your goal is to implement a fault-tolerant replication topology where all the servers receive the same transactions in the same order, and a server that crashes can rejoin the group and be brought up to date automatically, you can use Group Replication to achieve this." - MySql Documentation
```

Reference list
```text:
Scripts inspired by:
https://hackernoon.com/mysql-master-slave-replication-using-docker-3pp3u97

https://www.digitalocean.com/community/tutorials/how-to-set-up-replication-in-mysql

https://dev.mysql.com/doc/refman/8.0/en/replication-semisync.html
```