@echo off
echo 🚀 Continuing deployment from Maven build...

echo 📋 Copying phone provider JARs...
copy "temp\keycloak-phone-provider\target\providers\*.jar" "providers\" >nul 2>&1
echo ✅ Phone provider JARs copied

echo 🔨 Building theme...
cd temp\rms-auth-theme-plugin
npm install
npm run build-keycloak-theme
cd ..\..

echo 📋 Copying theme JAR...
if exist "temp\rms-auth-theme-plugin\dist_keycloak\*.jar" (
    copy "temp\rms-auth-theme-plugin\dist_keycloak\*.jar" "providers\" >nul 2>&1
    echo ✅ Theme JAR copied
) else (
    echo ⚠️ Theme JAR not found, searching...
    for /r "temp\rms-auth-theme-plugin" %%f in (*.jar) do (
        echo Found: %%f
        copy "%%f" "providers\" >nul 2>&1
    )
)

echo 📋 Providers directory:
dir providers

echo 🚀 Starting Keycloak...
docker-compose up -d keycloak

echo ⏳ Waiting for Keycloak...
timeout /t 30 /nobreak >nul

echo ✅ Deployment completed!
echo Keycloak: http://localhost:8080
echo Username: admin / Password: admin

docker-compose ps
pause