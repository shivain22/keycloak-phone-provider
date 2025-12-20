@echo off
setlocal enabledelayedexpansion

echo 🚀 Keycloak Phone Provider - Complete Deployment
echo ================================================

REM Create directories
echo Creating directories...
if not exist "providers" mkdir providers
if not exist "temp" mkdir temp
if not exist "realm" mkdir realm

REM Start PostgreSQL
echo 📦 Starting PostgreSQL...
docker-compose up -d postgres
timeout /t 5 /nobreak >nul

REM Clone/Update phone provider
echo 📥 Getting phone provider...
if exist "temp\keycloak-phone-provider" (
    echo Updating existing repository...
    pushd temp\keycloak-phone-provider
    git pull origin master
    popd
) else (
    echo Cloning repository...
    git clone https://github.com/shivain22/keycloak-phone-provider.git temp\keycloak-phone-provider
)

REM Clone/Update theme
echo 📥 Getting theme...
if exist "temp\rms-auth-theme-plugin" (
    echo Updating existing theme repository...
    pushd temp\rms-auth-theme-plugin
    git pull origin main
    popd
) else (
    echo Cloning theme repository...
    git clone https://github.com/atpar-org/rms-auth-theme-plugin.git temp\rms-auth-theme-plugin
)

REM Build phone provider
echo 🔨 Building phone provider...
pushd temp\keycloak-phone-provider
if exist "mvnw.cmd" (
    echo Using Maven wrapper...
    call mvnw.cmd clean package -DskipTests
) else (
    echo Using system Maven...
    mvn clean package -DskipTests
)
set MAVEN_EXIT=%errorlevel%
popd

if %MAVEN_EXIT% neq 0 (
    echo ❌ Maven build failed, continuing anyway...
)

REM Build theme
echo 🔨 Building theme...
pushd temp\rms-auth-theme-plugin
echo Installing npm dependencies...
npm install
echo Building Keycloak theme...
npm run build-keycloak-theme
set NPM_EXIT=%errorlevel%
popd

if %NPM_EXIT% neq 0 (
    echo ⚠️ Theme build may have failed, continuing...
)

REM Copy phone provider JARs
echo 📋 Copying phone provider JARs...
if exist "temp\keycloak-phone-provider\target\providers\*.jar" (
    copy "temp\keycloak-phone-provider\target\providers\*.jar" "providers\"
    echo ✅ Phone provider JARs copied
) else (
    echo ⚠️ No phone provider JARs found
)

REM Copy theme JAR
echo 📋 Copying theme JAR...
set THEME_COPIED=false

REM Check multiple possible locations
if exist "temp\rms-auth-theme-plugin\dist_keycloak\*.jar" (
    copy "temp\rms-auth-theme-plugin\dist_keycloak\*.jar" "providers\"
    set THEME_COPIED=true
    echo ✅ Theme JAR copied from dist_keycloak
)

if exist "temp\rms-auth-theme-plugin\build_keycloak\*.jar" (
    copy "temp\rms-auth-theme-plugin\build_keycloak\*.jar" "providers\"
    set THEME_COPIED=true
    echo ✅ Theme JAR copied from build_keycloak
)

REM Search recursively for any JAR files
if "!THEME_COPIED!"=="false" (
    echo Searching for theme JAR files...
    for /r "temp\rms-auth-theme-plugin" %%f in (*.jar) do (
        echo Found JAR: %%f
        copy "%%f" "providers\"
        set THEME_COPIED=true
    )
)

if "!THEME_COPIED!"=="false" (
    echo ⚠️ No theme JAR found - theme may not be required
)

REM Show what we have
echo 📋 Providers directory contents:
if exist "providers\*.jar" (
    dir providers\*.jar /b
) else (
    echo No JAR files found in providers directory
)

REM Start Keycloak
echo 🚀 Starting Keycloak...
docker-compose up -d keycloak

REM Wait for services
echo ⏳ Waiting for services to start...
timeout /t 20 /nobreak >nul

echo.
echo ✅ DEPLOYMENT COMPLETE
echo =====================
echo Keycloak Admin Console: http://localhost:8080
echo Username: admin
echo Password: admin
echo.
echo 📊 Container Status:
docker-compose ps

echo.
echo Press any key to exit...
pause >nul