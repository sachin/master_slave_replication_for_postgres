#!/bin/bash

# Function to check if a command was successful
check_status() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Function to wait for PostgreSQL to be ready
wait_for_postgres() {
    local host=$1
    local port=$2
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        PGPASSWORD=mypassword psql -h localhost -p $port -U myuser -d mydb -c "SELECT 1;" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "PostgreSQL at $host:$port is ready"
            return 0
        fi
        echo "Waiting for PostgreSQL at $host:$port (attempt $attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done

    echo "Timeout waiting for PostgreSQL at $host:$port"
    return 1
}

# Clean up any existing containers
echo "Cleaning up existing containers..."
docker compose down -v
rm -rf pg_* 
# Start the containers
echo "Starting containers..."
docker compose up -d
check_status "Failed to start containers"

# Wait for master and slaves to be ready
echo "Waiting for PostgreSQL instances to be ready..."
wait_for_postgres "localhost" "5532"  # Master
check_status "Master node failed to start"

wait_for_postgres "localhost" "5533"  # Slave 1
check_status "Slave 1 failed to start"

# Test 1: Create a table on master
echo "\nTest 1: Creating table on master..."
PGPASSWORD=mypassword psql -h localhost -p 5532 -U myuser -d mydb -c "
    CREATE TABLE test_table (id SERIAL PRIMARY KEY, name VARCHAR(50));
    INSERT INTO test_table (name) VALUES ('test1'), ('test2');"
check_status "Failed to create table on master"

# Test 2: Verify replication on slave
echo "\nTest 2: Verifying replication on slave..."
sleep 5  # Give some time for replication to occur
PGPASSWORD=mypassword psql -h localhost -p 5533 -U myuser -d mydb -c "SELECT * FROM test_table;"
check_status "Failed to verify replication on slave"

# Test 3: Check replication status
echo "\nTest 3: Checking replication status..."
PGPASSWORD=mypassword psql -h localhost -p 5532 -U myuser -d mydb -c "SELECT * FROM pg_stat_replication;"
check_status "Failed to check replication status"

# Test 4: Verify read-only status on slave
echo "\nTest 4: Verifying read-only status on slave..."
PGPASSWORD=mypassword psql -h localhost -p 5533 -U myuser -d mydb -c "INSERT INTO test_table (name) VALUES ('test3');" 2>&1 | grep -q "read-only"
if [ $? -eq 0 ]; then
    echo "Slave is correctly in read-only mode"
else
    echo "Error: Slave is not in read-only mode"
    exit 1
 fi

# Test 5: Add more data on master and verify replication
echo "\nTest 5: Adding more data on master and verifying replication..."
PGPASSWORD=mypassword psql -h localhost -p 5532 -U myuser -d mydb -c "INSERT INTO test_table (name) VALUES ('test4'), ('test5');"
check_status "Failed to insert additional data on master"

sleep 5  # Give some time for replication to occur

echo "Verifying data on slave..."
PGPASSWORD=mypassword psql -h localhost -p 5533 -U myuser -d mydb -c "SELECT COUNT(*) FROM test_table;"
check_status "Failed to verify additional data on slave"

# Clean up
echo "\nCleaning up..."
docker compose down -v
check_status "Failed to clean up containers"
rm -rf pg_* 
echo "\nAll tests completed successfully!"