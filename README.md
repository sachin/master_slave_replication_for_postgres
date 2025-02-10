# PostgreSQL Master-Slave Replication

A robust PostgreSQL master-slave replication setup using Docker containers, providing high availability and read scalability through one master node and three replica nodes.

## Features

- Streaming replication with asynchronous mode
- One master node (primary) and three replica nodes (hot standby)
- Automatic replica synchronization
- Docker-based deployment
- Configurable WAL management
- Trust-based authentication (for demonstration)

## Architecture Overview

- 1 Master Node (Primary)
- 3 Replica Nodes (Hot Standby)
- Streaming Replication
- Asynchronous Replication Mode

## Configuration Details

### Master Node Configuration

- Port: 5532 (Host) -> 5432 (Container)
- WAL Level: replica
- Maximum WAL Senders: 10
- WAL Keep Size: 64MB
- Hot Standby: enabled

### Replica Nodes Configuration

- Replica1: Port 5533 (Host) -> 5432 (Container)
- Replica2: Port 5534 (Host) -> 5432 (Container)
- Replica3: Port 5535 (Host) -> 5432 (Container)
- All replicas are configured as hot standby servers

## Environment Variables

```env
POSTGRES_USER=myuser
POSTGRES_PASSWORD=mypassword
POSTGRES_DB=mydb
REPLICATE_FROM=master
```

## Network Configuration

- Network Name: pg_network
- Network Driver: bridge
- Trust Authentication: Configured for 172.18.0.0/16 network

## Volume Management

- Master Data: ./pg_master_data
- Replica1 Data: ./pg_slave_data1
- Replica2 Data: ./pg_slave_data2
- Replica3 Data: ./pg_slave_data3

## Replication Configuration Details

### Master Node

```conf
# WAL Configuration
wal_level = replica           # Enables WAL archiving and replication
max_wal_senders = 10         # Maximum number of concurrent connections from replica servers
wal_keep_size = 64MB         # Amount of WAL files to retain for replicas
hot_standby = on             # Allows read-only queries on replica servers

# Authentication Configuration
host replication myuser 172.18.0.0/16 trust    # Allows replication connections
host all all 172.18.0.0/16 trust               # Allows regular connections
```

### Replica Nodes

```conf
# Replication Connection
primary_conninfo = 'host=master port=5432 user=myuser password=mypassword'

# Standby Configuration
standby.signal                # Indicates this is a replica server
```

## Deployment Instructions

1. Create the required directories:
   ```bash
   mkdir -p pg_master_data pg_slave_data1 pg_slave_data2 pg_slave_data3
   ```

2. Start the containers:
   ```bash
   docker-compose up -d
   ```

3. Verify replication status on master:
   ```bash
   docker exec -it pg_master psql -U myuser -d mydb -c "SELECT * FROM pg_stat_replication;"
   ```

## Replication Process

1. Master node is configured to allow replication connections
2. Replica nodes perform initial backup using pg_basebackup
3. Replicas continuously stream WAL changes from master
4. Replicas apply received WAL records in real-time

## Key Features

- Streaming replication for minimal replication lag
- Hot standby replicas for read scalability
- Automatic failover capability
- Volume persistence for data durability
- Secure network isolation

## Common Operations

### Check Replication Lag
```sql
SELECT client_addr, state, sent_lsn, write_lsn, flush_lsn, replay_lsn, 
       write_lag, flush_lag, replay_lag
FROM pg_stat_replication;
```

### Monitor Replica Status
```sql
SELECT pid, state, client_addr, sync_state, sync_priority 
FROM pg_stat_replication;
```

## Troubleshooting

1. If replication fails to start:
   - Check network connectivity between containers
   - Verify pg_hba.conf entries
   - Ensure WAL files are available

2. If replication lag increases:
   - Monitor system resources
   - Check network bandwidth
   - Verify WAL keep size settings

3. If replica falls behind:
   - Check available disk space
   - Monitor CPU and memory usage
   - Verify streaming replication status

## Security Considerations

- Trust authentication is used for demonstration
- Production environments should use encrypted passwords
- SSL should be enabled for secure replication
- Network access should be properly restricted

## Maintenance Tasks

1. Regular WAL archiving cleanup
2. Monitor replication slots
3. Backup verification
4. Log rotation management

## Limitations

- Asynchronous replication may have small data lag
- No automatic failover mechanism included
- Trust authentication is not suitable for production

## Best Practices

1. Regular monitoring of replication status
2. Implement proper backup strategy
3. Use SSL for production environments
4. Monitor disk space usage
5. Implement connection pooling for better performance

## Additional Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/current/high-availability.html)
- [Docker Documentation](https://docs.docker.com/)
- [PostgreSQL Replication](https://www.postgresql.org/docs/current/warm-standby.html)