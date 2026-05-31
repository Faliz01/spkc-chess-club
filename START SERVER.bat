@echo off
echo Starting SPKC Chess Club server...
start "" http://localhost:8000/spkc-chess-club.html
python -m http.server 8000
pause
