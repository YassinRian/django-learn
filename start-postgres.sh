#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "docker-compose not found. Using docker compose instead."
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

# Utility function to check if a container with a specific name exists (running or not)
container_exists() {
    docker ps -a --filter "name=$1" --format "{{.Names}}" | grep -q "$1"
    return $?
}

# Check if containers are already running
POSTGRES_RUNNING=$(docker ps --filter "name=postgres_container" --format "{{.Names}}" | grep -c "postgres_container")
PGADMIN_RUNNING=$(docker ps --filter "name=pgadmin_container" --format "{{.Names}}" | grep -c "pgadmin_container")

# Handle PostgreSQL container
if [ $POSTGRES_RUNNING -eq 1 ]; then
    echo -e "${GREEN}PostgreSQL container is already running.${NC}"
elif container_exists "postgres_container"; then
    echo -e "${YELLOW}PostgreSQL container exists but is not running. Starting it...${NC}"
    docker start postgres_container
else
    echo -e "${YELLOW}Creating and starting PostgreSQL container...${NC}"
    # Temporarily rename the postgres service to avoid naming conflicts
    sed -i 's/container_name: postgres_container/container_name: temp_postgres_container/g' docker-compose.yml
    $COMPOSE_CMD up -d postgres
    # If this fails due to conflicts, try a direct docker run
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Using direct docker command for PostgreSQL...${NC}"
        docker run -d --name postgres_container \
            -e POSTGRES_USER=postgres \
            -e POSTGRES_PASSWORD=your_password \
            -e POSTGRES_DB=pg_django \
            -v postgres_data:/data/postgres \
            -p 5432:5432 \
            postgres:latest
    fi
    # Restore the original name in docker-compose.yml
    sed -i 's/container_name: temp_postgres_container/container_name: postgres_container/g' docker-compose.yml
fi

# Handle pgAdmin container
if [ $PGADMIN_RUNNING -eq 1 ]; then
    echo -e "${GREEN}pgAdmin container is already running.${NC}"
elif container_exists "pgadmin_container"; then
    echo -e "${YELLOW}pgAdmin container exists but is not running. Starting it...${NC}"
    docker start pgadmin_container
else
    echo -e "${YELLOW}Creating and starting pgAdmin container...${NC}"
    # Try using docker-compose
    $COMPOSE_CMD up -d pgadmin
    # If this fails, try a direct docker run
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Using direct docker command for pgAdmin...${NC}"
        docker run -d --name pgadmin_container \
            -e PGADMIN_DEFAULT_EMAIL=your@email.com \
            -e PGADMIN_DEFAULT_PASSWORD=your_password \
            -p 5050:80 \
            dpage/pgadmin4
    fi
fi

# Wait for PostgreSQL to be ready
echo -e "${YELLOW}Waiting for PostgreSQL to start...${NC}"
sleep 5

# Check if PostgreSQL is up
if docker exec postgres_container pg_isready -U postgres > /dev/null 2>&1; then
    echo -e "${GREEN}PostgreSQL is up and running!${NC}"
else
    echo -e "${YELLOW}PostgreSQL is starting up. Give it a few more seconds...${NC}"
    sleep 5
fi

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}PostgreSQL is running on localhost:5432${NC}"
echo -e "${GREEN}  - Database: pg_django${NC}"
echo -e "${GREEN}  - User: postgres${NC}"
echo -e "${GREEN}  - Password: your_password${NC}"
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}pgAdmin is running on http://localhost:5050${NC}"
echo -e "${GREEN}  - Email: your@email.com${NC}"
echo -e "${GREEN}  - Password: your_password${NC}"
echo -e "${GREEN}======================================${NC}"

# How to connect to PostgreSQL with psql
echo -e "${YELLOW}To connect to PostgreSQL with psql, run:${NC}"
echo -e "docker exec -it postgres_container psql -U postgres -d pg_django"

# How to stop the containers
echo -e "${YELLOW}To stop the containers, run:${NC}"
echo -e "$COMPOSE_CMD down"
