@echo off
setlocal enabledelayedexpansion

echo 🚀 Starting Keycloak deployment with phone provider and theme...

REM Check and install Chocolatey if not present
echo 🔍 Checking for Chocolatey installation...
choco -v >nul 2>&1
if errorlevel 1 (
    echo 📦 Chocolatey not found. Installing Chocolatey...
    echo This requires Administrator privileges. Please run as Administrator if prompted.
    
    REM Install Chocolatey
    powershell -ExecutionPolicy Bypass -File "install-choco.ps1"
    
    if errorlevel 1 (
        echo ❌ Failed to install Chocolatey
        echo Please install Chocolatey manually:
        echo 1. Run PowerShell as Administrator
        echo 2. Run the install-choco.ps1 script
        echo 3. Restart this script
        pause
        exit /b 1
    )
    
    echo ✅ Chocolatey installed successfully
    echo Please restart Command Prompt and run this script again to refresh environment variables.
    pause
    exit /b 0
    
    REM Verify Chocolatey installation
    choco -v >nul 2>&1
    if errorlevel 1 (
        echo ⚠️ Chocolatey installed but not in PATH. Please restart Command Prompt and run this script again.
        pause
        exit /b 1
    )
else (
    echo ✅ Chocolatey is already installed
)

REM Check and install Maven if not present
echo 🔍 Checking for Maven installation...
mvn -version >nul 2>&1
if errorlevel 1 (
    echo 📦 Maven not found. Installing Maven via Chocolatey...
    choco install maven -y
    if errorlevel 1 (
        echo ❌ Failed to install Maven
        pause
        exit /b 1
    )
    echo ✅ Maven installed successfully
    echo Please restart Command Prompt and run this script again to refresh environment variables.
    pause
    exit /b 0
    
    REM Verify Maven installation
    mvn -version >nul 2>&1
    if errorlevel 1 (
        echo ⚠️ Maven installed but not in PATH. Please restart Command Prompt and run this script again.
        pause
        exit /b 1
    )
) else (
    echo ✅ Maven is already installed
)

REM Check and install Node.js if not present
echo 🔍 Checking for Node.js installation...
node -v >nul 2>&1
if errorlevel 1 (
    echo 📦 Node.js not found. Installing Node.js via Chocolatey...
    choco install nodejs -y
    if errorlevel 1 (
        echo ❌ Failed to install Node.js
        pause
        exit /b 1
    )
    echo ✅ Node.js installed successfully
    echo Please restart Command Prompt and run this script again to refresh environment variables.
    pause
    exit /b 0
else (
    echo ✅ Node.js is already installed
)

REM Create necessary directories
if not exist "providers" mkdir providers
if not exist "temp" mkdir temp
if not exist "realm" mkdir realm

echo 📦 Starting PostgreSQL...
docker-compose up -d postgres

echo ⏳ Waiting for PostgreSQL to be ready...
timeout /t 10 /nobreak >nul

echo 📥 Pulling phone provider repository...
if exist "temp\keycloak-phone-provider" (
    cd temp\keycloak-phone-provider
    git pull origin master
    cd ..\..
) else (
    git clone https://github.com/shivain22/keycloak-phone-provider.git temp\keycloak-phone-provider
)

echo 📥 Pulling theme repository...
if exist "temp\rms-auth-theme-plugin" (
    cd temp\rms-auth-theme-plugin
    git pull origin main
    cd ..\..
) else (
    git clone https://github.com/atpar-org/rms-auth-theme-plugin.git temp\rms-auth-theme-plugin
)

echo 🔨 Building phone providers...
cd temp\keycloak-phone-provider
if exist "mvnw.cmd" (
    call mvnw.cmd clean package -DskipTests
) else (
    call mvn clean package -DskipTests
)
cd ..\..

echo 🔨 Building theme...
cd temp\rms-auth-theme-plugin
call npm install
call npm run build-keycloak-theme
cd ..\..

echo 📋 Copying providers to Keycloak...
REM Copy phone provider JARs
if exist "temp\keycloak-phone-provider\target\providers\*.jar" (
    copy "temp\keycloak-phone-provider\target\providers\*.jar" "providers\" >nul 2>&1
) else (
    echo No phone provider JARs found
)

REM Copy theme JAR (check common Keycloakify output locations)
set THEME_COPIED=false
if exist "temp\rms-auth-theme-plugin\dist_keycloak\keycloak-theme.jar" (
    copy "temp\rms-auth-theme-plugin\dist_keycloak\keycloak-theme.jar" "providers\" >nul
    set THEME_COPIED=true
) else if exist "temp\rms-auth-theme-plugin\dist_keycloak\rms-auth-theme.jar" (
    copy "temp\rms-auth-theme-plugin\dist_keycloak\rms-auth-theme.jar" "providers\" >nul
    set THEME_COPIED=true
) else if exist "temp\rms-auth-theme-plugin\build_keycloak\keycloak-theme.jar" (
    copy "temp\rms-auth-theme-plugin\build_keycloak\keycloak-theme.jar" "providers\" >nul
    set THEME_COPIED=true
)

if "!THEME_COPIED!"=="false" (
    echo ⚠️  Theme JAR not found in expected locations
    echo Searching for JAR files in theme directory:
    for /r "temp\rms-auth-theme-plugin" %%f in (*.jar) do (
        echo Found: %%f
        copy "%%f" "providers\" >nul 2>&1
        set THEME_COPIED=true
        goto theme_found
    )
    :theme_found
)

echo 📋 Providers directory contents:
dir providers

echo 🚀 Starting Keycloak...
docker-compose up -d keycloak

echo ⏳ Waiting for Keycloak to be ready...
timeout /t 30 /nobreak >nul

echo.
echo ✅ Deployment completed!
echo Keycloak Admin Console: http://localhost:8080
echo Username: admin
echo Password: admin
echo.
echo 📊 Container status:
docker-compose ps

pause