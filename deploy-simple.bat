@echo off
setlocal enabledelayedexpansion

echo 🚀 Starting Keycloak deployment with phone provider and theme...

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
    echo Maven wrapper not found, trying system Maven...
    mvn clean package -DskipTests
    if errorlevel 1 (
        echo ❌ Maven build failed. Please ensure Maven is installed and in PATH.
        echo You can install Maven with: choco install maven
        cd ..\..
        pause
        exit /b 1
    )
)
echo ✅ Phone provider build completed
cd ..\..

echo 🔨 Building theme...
cd temp\rms-auth-theme-plugin
npm install
if errorlevel 1 (
    echo ❌ npm install failed. Please ensure Node.js is installed.
    echo You can install Node.js with: choco install nodejs
    cd ..\..
    pause
    exit /b 1
)
npm run build-keycloak-theme
if errorlevel 1 (
    echo ❌ Theme build failed.
    cd ..\..
    pause
    exit /b 1
)
echo ✅ Theme build completed
cd ..\..

echo 📋 Copying providers to Keycloak...
REM Copy phone provider JARs
if exist "temp\keycloak-phone-provider\target\providers\*.jar" (
    copy "temp\keycloak-phone-provider\target\providers\*.jar" "providers\" >nul 2>&1
    echo ✅ Phone provider JARs copied
) else (
    echo ⚠️ No phone provider JARs found
)

REM Copy theme JAR
set THEME_COPIED=false
if exist "temp\rms-auth-theme-plugin\dist_keycloak\*.jar" (
    copy "temp\rms-auth-theme-plugin\dist_keycloak\*.jar" "providers\" >nul 2>&1
    set THEME_COPIED=true
    echo ✅ Theme JAR copied from dist_keycloak
) else if exist "temp\rms-auth-theme-plugin\build_keycloak\*.jar" (
    copy "temp\rms-auth-theme-plugin\build_keycloak\*.jar" "providers\" >nul 2>&1
    set THEME_COPIED=true
    echo ✅ Theme JAR copied from build_keycloak
) else (
    echo ⚠️ Searching for theme JAR files...
    for /r "temp\rms-auth-theme-plugin" %%f in (*.jar) do (
        echo Found: %%f
        copy "%%f" "providers\" >nul 2>&1
        set THEME_COPIED=true
    )
)

if "!THEME_COPIED!"=="false" (
    echo ⚠️ No theme JAR found
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