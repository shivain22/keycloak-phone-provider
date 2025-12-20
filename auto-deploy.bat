@echo off
setlocal enabledelayedexpansion

echo 🚀 Keycloak Phone Provider - Complete Deployment
echo ================================================

REM Create directories
if not exist "providers" mkdir providers
if not exist "temp" mkdir temp
if not exist "realm" mkdir realm

REM Start PostgreSQL
echo 📦 Starting PostgreSQL...
docker-compose up -d postgres >nul 2>&1
timeout /t 5 /nobreak >nul

REM Clone/Update repositories
echo 📥 Getting phone provider...
if exist "temp\keycloak-phone-provider" (
    cd temp\keycloak-phone-provider && git pull origin master >nul 2>&1 && cd ..\..
) else (
    git clone https://github.com/shivain22/keycloak-phone-provider.git temp\keycloak-phone-provider >nul 2>&1
)

echo 📥 Getting theme...
if exist "temp\rms-auth-theme-plugin" (
    cd temp\rms-auth-theme-plugin && git pull origin main >nul 2>&1 && cd ..\..
) else (
    git clone https://github.com/atpar-org/rms-auth-theme-plugin.git temp\rms-auth-theme-plugin >nul 2>&1
)

REM Build phone provider
echo 🔨 Building phone provider...
cd temp\keycloak-phone-provider
if exist "mvnw.cmd" (
    call mvnw.cmd clean package -DskipTests -q
) else (
    mvn clean package -DskipTests -q
)
if errorlevel 1 (
    echo ❌ Phone provider build failed
    cd ..\..
    goto :skip_theme
)
cd ..\..

REM Build theme
echo 🔨 Building theme...
cd temp\rms-auth-theme-plugin
npm install --silent >nul 2>&1
npm run build-keycloak-theme >nul 2>&1
cd ..\..

:skip_theme
REM Copy JARs
echo 📋 Copying providers...
copy "temp\keycloak-phone-provider\target\providers\*.jar" "providers\" >nul 2>&1

REM Copy theme JAR from any location
for /r "temp\rms-auth-theme-plugin" %%f in (*.jar) do (
    copy "%%f" "providers\" >nul 2>&1
)

REM Start Keycloak
echo 🚀 Starting Keycloak...
docker-compose up -d keycloak >nul 2>&1

REM Wait and show status
echo ⏳ Waiting for services...
timeout /t 20 /nobreak >nul

echo.
echo ✅ DEPLOYMENT COMPLETE
echo =====================
echo Keycloak: http://localhost:8080
echo Username: admin
echo Password: admin
echo.
echo 📊 Services:
docker-compose ps

echo.
echo 📦 Providers installed:
dir providers /b

pause