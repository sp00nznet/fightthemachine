#!/bin/bash
# Fight the Machine - Quick Start Script
# Run this script to build and start Fight the Machine in a Docker container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              Fight the Machine                            ║"
echo "║     Kill processes as DOOM monsters in your browser!      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed.${NC}"
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check for docker-compose or docker compose
COMPOSE_CMD=""
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo -e "${RED}Error: docker-compose is not available.${NC}"
    echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

# Parse arguments
ACTION="${1:-start}"

case "$ACTION" in
    start|up)
        echo -e "${YELLOW}Building and starting Fight the Machine container...${NC}"
        $COMPOSE_CMD up -d --build

        echo ""
        echo -e "${GREEN}Fight the Machine is starting up!${NC}"
        echo ""
        echo "Access the game in your browser at:"
        echo -e "  ${GREEN}http://localhost:6080${NC}"
        echo ""
        echo "Wait ~30 seconds for the container to fully initialize."
        echo ""
        echo "Commands:"
        echo "  ./run.sh stop     - Stop the container"
        echo "  ./run.sh logs     - View container logs"
        echo "  ./run.sh restart  - Restart the container"
        echo "  ./run.sh status   - Check container status"
        ;;

    stop|down)
        echo -e "${YELLOW}Stopping container...${NC}"
        $COMPOSE_CMD down
        echo -e "${GREEN}Container stopped.${NC}"
        ;;

    restart)
        echo -e "${YELLOW}Restarting container...${NC}"
        $COMPOSE_CMD restart
        echo -e "${GREEN}Container restarted.${NC}"
        ;;

    logs)
        echo -e "${YELLOW}Showing container logs (Ctrl+C to exit)...${NC}"
        $COMPOSE_CMD logs -f
        ;;

    status)
        echo -e "${YELLOW}Container status:${NC}"
        $COMPOSE_CMD ps
        ;;

    build)
        echo -e "${YELLOW}Building container...${NC}"
        $COMPOSE_CMD build --no-cache
        echo -e "${GREEN}Build complete.${NC}"
        ;;

    shell)
        echo -e "${YELLOW}Opening shell in container...${NC}"
        docker exec -it fightthemachine /bin/bash
        ;;

    *)
        echo "Usage: ./run.sh [command]"
        echo ""
        echo "Commands:"
        echo "  start   - Build and start the container (default)"
        echo "  stop    - Stop the container"
        echo "  restart - Restart the container"
        echo "  logs    - View container logs"
        echo "  status  - Show container status"
        echo "  build   - Rebuild the container image"
        echo "  shell   - Open a shell in the container"
        ;;
esac
