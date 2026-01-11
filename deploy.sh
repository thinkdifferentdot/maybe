#!/bin/bash
# ===========================================================================
# Quick deployment script for Raspberry Pi 5
# ===========================================================================
#
# This script pulls the latest changes from your fork and rebuilds/restarts
# the application with minimal downtime.
#
# Usage:
#   ./deploy.sh              # Pull latest and deploy
#   ./deploy.sh --force      # Force rebuild without cache
#   ./deploy.sh --no-build   # Just restart, no rebuild
#
# ========================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRANCH="${DEPLOY_BRANCH:-rpi5-docker-deploy}"
COMPOSE_FILE="docker-compose.rpi5.yml"
# Use 'fork' remote if it exists, otherwise use 'origin'
REMOTE="$(git remote | grep '^fork$' || echo 'origin')"

# Change to repo directory
cd "$REPO_DIR"

echo -e "${GREEN}=== Sure Deployment Script ===${NC}"
echo "Repository: $REPO_DIR"
echo "Branch: $BRANCH"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Create one with:"
    echo "  cat > .env << EOF"
    echo "  ANTHROPIC_API_KEY=your_key_here"
    echo "  SECRET_KEY_BASE=$(openssl rand -hex 64)"
    echo "  EOF"
    exit 1
fi

# Parse arguments
FORCE_BUILD=""
NO_BUILD=""
SKIP_PULL=""

for arg in "$@"; do
    case $arg in
        --force)
            FORCE_BUILD="--no-cache"
            shift
            ;;
        --no-build)
            NO_BUILD=1
            shift
            ;;
        --no-pull)
            SKIP_PULL=1
            shift
            ;;
        *)
            ;;
    esac
done

# 1. Pull latest changes
if [ -z "$SKIP_PULL" ]; then
    echo -e "${YELLOW}[1/5] Pulling latest changes from '$REMOTE'...${NC}"
    git fetch "$REMOTE" "$BRANCH"
    git checkout "$BRANCH"
    git reset --hard "$REMOTE/$BRANCH"
    echo -e "${GREEN}✓ Updated to latest code${NC}"
    echo ""
else
    echo -e "${YELLOW}[1/5] Skipping git pull${NC}"
    echo ""
fi

# 2. Check if Docker images need rebuilding
if [ -z "$NO_BUILD" ]; then
    echo -e "${YELLOW}[2/5] Building Docker images...${NC}"
    echo -e "${YELLOW}(This may take a few minutes on RPi5)${NC}"
    docker compose -f "$COMPOSE_FILE" build $FORCE_BUILD
    echo -e "${GREEN}✓ Build complete${NC}"
    echo ""
else
    echo -e "${YELLOW}[2/5] Skipping build${NC}"
    echo ""
fi

# 3. Run database migrations if needed
echo -e "${YELLOW}[3/5] Running database migrations...${NC}"
docker compose -f "$COMPOSE_FILE" run --rm web bin/rails db:prepare
echo -e "${GREEN}✓ Database up to date${NC}"
echo ""

# 4. Precompile assets
echo -e "${YELLOW}[4/5] Precompiling assets...${NC}"
docker compose -f "$COMPOSE_FILE" run --rm web bin/rails assets:precompile
echo -e "${GREEN}✓ Assets precompiled${NC}"
echo ""

# 5. Restart services with minimal downtime
echo -e "${YELLOW}[5/5] Restarting services...${NC}"
docker compose -f "$COMPOSE_FILE" up -d
echo -e "${GREEN}✓ Services restarted${NC}"
echo ""

# 6. Show status
echo -e "${GREEN}=== Deployment Complete ===${NC}"
docker compose -f "$COMPOSE_FILE" ps

echo ""
echo -e "${GREEN}Application is running at: http://$(hostname -I | awk '{print $1}'):3000${NC}"
echo ""
echo "View logs with:"
echo "  docker compose -f $COMPOSE_FILE logs -f"
