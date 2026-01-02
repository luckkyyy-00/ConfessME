@echo off
echo ==========================================
echo   Deploying Confess App APIs (Functions)
echo ==========================================

cd functions
echo Installing dependencies...
call npm install
cd ..

echo.
echo Uploading to Firebase...
call firebase deploy --only functions

echo.
echo ==========================================
echo   Deployment Complete!
echo ==========================================
pause
