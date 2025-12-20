@echo off
C:\Users\shiva\eclipse-workspace\keycloak-phone-provider-parent\keycloak-26.4.7\bin\kc.bat start-dev ^
    --spi-phone-default-service=msg91 ^
    --spi-phone-default-token-expires-in=60 ^
    --spi-phone-default-source-hour-maximum=10 ^
    --spi-phone-default-target-hour-maximum=3 ^
    --spi-phone-default-testrealm-duplicate-phone=false ^
    --spi-phone-default-testrealm-default-number-regex=^\+?\d+$ ^
    --spi-phone-default-testrealm-valid-phone=true ^
    --spi-phone-default-testrealm-canonicalize-phone-numbers=E164 ^
    --spi-phone-default-testrealm-phone-default-region=US ^
    --spi-phone-default-testrealm-compatible=false ^
    --spi-phone-default-testrealm-otp-expires=3600