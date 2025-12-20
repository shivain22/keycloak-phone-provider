@echo off
echo 🔍 Manual theme build debug...

echo Current directory:
cd

echo Checking theme directory:
if exist "temp\rms-auth-theme-plugin" (
    echo ✅ Theme directory exists
    cd temp\rms-auth-theme-plugin
    
    echo Current directory after cd:
    cd
    
    echo Checking package.json:
    if exist "package.json" (
        echo ✅ package.json exists
        type package.json | findstr "build-keycloak-theme"
    ) else (
        echo ❌ package.json not found
    )
    
    echo Running npm run build-keycloak-theme with verbose output:
    npm run build-keycloak-theme
    echo Exit code: %errorlevel%
    
    echo Checking for output files:
    if exist "dist_keycloak" (
        echo ✅ dist_keycloak directory exists
        dir dist_keycloak
    ) else (
        echo ❌ dist_keycloak not found
    )
    
    if exist "build_keycloak" (
        echo ✅ build_keycloak directory exists  
        dir build_keycloak
    ) else (
        echo ❌ build_keycloak not found
    )
    
    echo Searching for any JAR files:
    for /r . %%f in (*.jar) do echo Found JAR: %%f
    
    cd ..\..
) else (
    echo ❌ Theme directory not found
)

pause