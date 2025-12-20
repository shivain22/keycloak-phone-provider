#!/bin/bash

set -e

echo "🚀 Starting Keycloak deployment with phone provider and theme..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check and install Maven if not present
echo "🔍 Checking for Maven installation..."
if ! command -v mvn &> /dev/null; then
    echo "📦 Maven not found. Installing Maven..."
    
    # Detect OS and install accordingly
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y maven
        elif command -v yum &> /dev/null; then
            sudo yum install -y maven
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y maven
        else
            echo -e "${RED}❌ Unable to install Maven automatically. Please install manually.${NC}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install maven
        else
            echo -e "${RED}❌ Homebrew not found. Please install Maven manually.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ Unsupported OS. Please install Maven manually.${NC}"
        exit 1
    fi
    
    if command -v mvn &> /dev/null; then
        echo -e "${GREEN}✅ Maven installed successfully${NC}"
    else
        echo -e "${RED}❌ Failed to install Maven${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Maven is already installed${NC}"
fi

# Create necessary directories
mkdir -p providers temp realm

echo "📦 Starting PostgreSQL..."
docker-compose up -d postgres

echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 10

echo "📥 Pulling phone provider repository..."
if [ -d "temp/keycloak-phone-provider" ]; then
    cd temp/keycloak-phone-provider
    git pull origin master
    cd ../..
else
    git clone https://github.com/shivain22/keycloak-phone-provider.git temp/keycloak-phone-provider
fi

echo "📥 Pulling theme repository..."
if [ -d "temp/rms-auth-theme-plugin" ]; then
    cd temp/rms-auth-theme-plugin
    git pull origin main
    cd ../..
else
    git clone https://github.com/atpar-org/rms-auth-theme-plugin.git temp/rms-auth-theme-plugin
fi

echo "🔨 Building phone providers..."
cd temp/keycloak-phone-provider
mvn clean package -DskipTests
cd ../..

echo "🔨 Building theme..."
cd temp/rms-auth-theme-plugin
npm install
npm run build-keycloak-theme
cd ../..

echo "📋 Copying providers to Keycloak..."
# Copy phone provider JARs
cp temp/keycloak-phone-provider/target/providers/*.jar providers/ 2>/dev/null || echo "No phone provider JARs found"

# Copy theme JAR (check common Keycloakify output locations)
if [ -f "temp/rms-auth-theme-plugin/dist_keycloak/keycloak-theme.jar" ]; then
    cp temp/rms-auth-theme-plugin/dist_keycloak/keycloak-theme.jar providers/
elif [ -f "temp/rms-auth-theme-plugin/dist_keycloak/rms-auth-theme.jar" ]; then
    cp temp/rms-auth-theme-plugin/dist_keycloak/rms-auth-theme.jar providers/
elif [ -f "temp/rms-auth-theme-plugin/build_keycloak/keycloak-theme.jar" ]; then
    cp temp/rms-auth-theme-plugin/build_keycloak/keycloak-theme.jar providers/
else
    echo "⚠️  Theme JAR not found in expected locations"
    find temp/rms-auth-theme-plugin -name "*.jar" -type f | head -5
fi

echo "📋 Providers directory contents:"
ls -la providers/

echo "🚀 Starting Keycloak..."
docker-compose up -d keycloak

echo "⏳ Waiting for Keycloak to be ready..."
sleep 30

echo -e "${GREEN}✅ Deployment completed!${NC}"
echo -e "${YELLOW}Keycloak Admin Console: http://localhost:8080${NC}"
echo -e "${YELLOW}Username: admin${NC}"
echo -e "${YELLOW}Password: admin${NC}"
echo ""
echo "📊 Container status:"
docker-compose ps