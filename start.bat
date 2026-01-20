@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: Everlast AI Backend - Windows Startskript
::
:: Startet den lokalen KI-Server für Everlast AI.
:: Beim ersten Start werden Modelle automatisch heruntergeladen.
::
:: Voraussetzungen: Python 3.10+, Ollama, CUDA (optional)

title Everlast AI Backend

:: Konfiguration
if not defined WHISPER_MODEL set WHISPER_MODEL=medium
if not defined OLLAMA_MODEL set OLLAMA_MODEL=deepseek-r1:8b
if not defined OLLAMA_BASE_URL set OLLAMA_BASE_URL=http://localhost:11434
if not defined BACKEND_PORT set BACKEND_PORT=8080

:: Marker-Datei für Ersteinrichtung
set SETUP_MARKER=%~dp0.setup_complete

:: Parameter verarbeiten
if "%1"=="--setup" goto :force_setup
if "%1"=="--reset" goto :force_setup
if "%1"=="--help" goto :show_help
if "%1"=="-h" goto :show_help
goto :start

:force_setup
if exist "%SETUP_MARKER%" del "%SETUP_MARKER%"
goto :start

:show_help
echo.
echo Everlast AI Backend - Startskript (Windows)
echo.
echo Verwendung: start.bat [OPTIONEN]
echo.
echo Optionen:
echo   --setup, --reset    Ersteinrichtung erneut ausfuehren
echo   --help, -h          Diese Hilfe anzeigen
echo.
echo Umgebungsvariablen:
echo   WHISPER_MODEL       Whisper-Modell (default: medium)
echo   OLLAMA_MODEL        Ollama-Modell (default: deepseek-r1:8b)
echo   BACKEND_PORT        Server-Port (default: 8080)
echo.
exit /b 0

:start
echo.
echo ═══════════════════════════════════════════════════════════
echo        Everlast AI Backend - Lokaler KI-Server
echo ═══════════════════════════════════════════════════════════
echo.

:: === Voraussetzungen prüfen ===

echo Pruefe Voraussetzungen...
echo.

:: Prüfe Python
where python >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [FEHLER] Python nicht gefunden!
    echo.
    echo Bitte installiere Python 3.10+:
    echo   https://www.python.org/downloads/
    echo.
    echo Wichtig: Bei der Installation "Add Python to PATH" aktivieren!
    echo.
    pause
    exit /b 1
)

:: Python Version anzeigen
for /f "tokens=*" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
echo   Python: [OK] %PYTHON_VERSION%

:: Prüfe Ollama
where ollama >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo.
    echo ╔════════════════════════════════════════════════════════════╗
    echo ║                  OLLAMA NICHT INSTALLIERT                  ║
    echo ╚════════════════════════════════════════════════════════════╝
    echo.
    echo Ollama wird fuer die lokale LLM-Generierung benoetigt.
    echo.
    echo Installation:
    echo   1. Oeffne https://ollama.com/download/windows
    echo   2. Lade den Windows-Installer herunter
    echo   3. Installiere Ollama
    echo   4. Starte dieses Skript erneut
    echo.
    set /p OPEN_BROWSER="Browser oeffnen? [J/n] "
    if /i "!OPEN_BROWSER!"=="" set OPEN_BROWSER=J
    if /i "!OPEN_BROWSER!"=="J" start https://ollama.com/download/windows
    if /i "!OPEN_BROWSER!"=="Y" start https://ollama.com/download/windows
    echo.
    pause
    exit /b 1
)
echo   Ollama: [OK] Installiert

:: Prüfe ob Ollama läuft
curl -s "%OLLAMA_BASE_URL%/api/tags" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo   Ollama-Service: [WARNUNG] Nicht gestartet
    echo.
    set /p START_OLLAMA="  Soll Ollama jetzt gestartet werden? [J/n] "
    if /i "!START_OLLAMA!"=="" set START_OLLAMA=J
    if /i "!START_OLLAMA!"=="J" (
        echo   Starte Ollama...
        start /b "" ollama serve >nul 2>&1
        timeout /t 3 /nobreak >nul
        curl -s "%OLLAMA_BASE_URL%/api/tags" >nul 2>&1
        if !ERRORLEVEL! equ 0 (
            echo   Ollama-Service: [OK] Gestartet
        ) else (
            echo   [WARNUNG] Ollama konnte nicht gestartet werden
            echo   Versuche manuell: ollama serve
        )
    )
    if /i "!START_OLLAMA!"=="Y" (
        echo   Starte Ollama...
        start /b "" ollama serve >nul 2>&1
        timeout /t 3 /nobreak >nul
    )
) else (
    echo   Ollama-Service: [OK] Laeuft
)

echo.

:: Virtuelle Umgebung erstellen/aktivieren
if not exist "venv" (
    echo Erstelle virtuelle Umgebung...
    python -m venv venv
    if %ERRORLEVEL% neq 0 (
        echo [FEHLER] Konnte virtuelle Umgebung nicht erstellen
        pause
        exit /b 1
    )
)

:: Aktiviere venv
call venv\Scripts\activate.bat

:: Dependencies installieren falls nötig
if not exist "venv\.installed" (
    echo Installiere Dependencies...
    python -m pip install --upgrade pip
    pip install -r requirements.txt
    if %ERRORLEVEL% neq 0 (
        echo [FEHLER] Konnte Dependencies nicht installieren
        pause
        exit /b 1
    )
    echo. > venv\.installed
)

echo.

:: === Ersteinrichtung ===

if not exist "%SETUP_MARKER%" (
    echo ╔════════════════════════════════════════════════════════════╗
    echo ║              ERSTEINRICHTUNG - Modelle laden               ║
    echo ╚════════════════════════════════════════════════════════════╝
    echo.
    echo Fuer die lokale KI-Verarbeitung werden folgende Modelle benoetigt:
    echo.
    echo   1. Whisper ^(STT^): %WHISPER_MODEL%
    echo      Groesse: ~1.5 GB ^| VRAM: ~5 GB
    echo.
    echo   2. DeepSeek ^(LLM^): %OLLAMA_MODEL%
    echo      Groesse: ~4.5 GB ^| VRAM: ~6 GB
    echo.

    :: Whisper-Modell laden
    echo Pruefe Whisper-Modell...
    set /p DOWNLOAD_WHISPER="Soll das Whisper-Modell '%WHISPER_MODEL%' heruntergeladen werden? [J/n] "
    if /i "!DOWNLOAD_WHISPER!"=="" set DOWNLOAD_WHISPER=J
    if /i "!DOWNLOAD_WHISPER!"=="J" call :download_whisper
    if /i "!DOWNLOAD_WHISPER!"=="Y" call :download_whisper

    echo.

    :: Ollama-Modell laden
    echo Pruefe Ollama-Modell...
    curl -s "%OLLAMA_BASE_URL%/api/tags" 2>nul | findstr /i "%OLLAMA_MODEL%" >nul
    if %ERRORLEVEL% neq 0 (
        set /p DOWNLOAD_OLLAMA="Soll das Ollama-Modell '%OLLAMA_MODEL%' heruntergeladen werden? [J/n] "
        if /i "!DOWNLOAD_OLLAMA!"=="" set DOWNLOAD_OLLAMA=J
        if /i "!DOWNLOAD_OLLAMA!"=="J" call :download_ollama
        if /i "!DOWNLOAD_OLLAMA!"=="Y" call :download_ollama
    ) else (
        echo [OK] Ollama-Modell '%OLLAMA_MODEL%' bereits vorhanden
    )

    :: Setup-Marker erstellen
    echo. > "%SETUP_MARKER%"

    echo.
    echo ═══════════════════════════════════════════════════════════
    echo               Ersteinrichtung abgeschlossen!
    echo ═══════════════════════════════════════════════════════════
    echo.
)

:: === Status anzeigen ===

echo System-Status:
echo.

:: GPU-Info
where nvidia-smi >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "tokens=*" %%i in ('nvidia-smi --query-gpu^=name^,memory.total --format^=csv^,noheader 2^>nul') do echo   GPU: [OK] %%i
) else (
    echo   GPU: [INFO] Keine NVIDIA GPU - CPU-Modus
)

:: Ollama Status
curl -s "%OLLAMA_BASE_URL%/api/tags" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   Ollama: [OK] Erreichbar
) else (
    echo   Ollama: [WARNUNG] Nicht erreichbar ^(starte mit: ollama serve^)
)

echo.
echo Konfiguration:
echo   Whisper-Modell: %WHISPER_MODEL%
echo   Ollama-Modell:  %OLLAMA_MODEL%
echo   Server-Port:    %BACKEND_PORT%

echo.
echo Starte Server...
echo API-Dokumentation: http://localhost:%BACKEND_PORT%/docs
echo.

:: Server starten
python main.py
goto :eof

:: === Hilfsfunktionen ===

:download_whisper
echo.
echo Lade Whisper-Modell '%WHISPER_MODEL%'...
echo Dies kann einige Minuten dauern (ca. 1.5 GB fuer 'medium').
echo.
python -c "from faster_whisper import WhisperModel; print('Initialisiere...'); m = WhisperModel('%WHISPER_MODEL%', device='cpu', compute_type='int8'); print('OK: Modell heruntergeladen und gecacht!')"
if %ERRORLEVEL% equ 0 (
    echo [OK] Whisper-Modell '%WHISPER_MODEL%' bereit
) else (
    echo [FEHLER] Konnte Whisper-Modell nicht laden
)
goto :eof

:download_ollama
echo.
echo Lade Ollama-Modell '%OLLAMA_MODEL%'...
echo Dies kann einige Minuten dauern (ca. 4-5 GB).
echo.
ollama pull %OLLAMA_MODEL%
if %ERRORLEVEL% equ 0 (
    echo [OK] Ollama-Modell '%OLLAMA_MODEL%' bereit
) else (
    echo [FEHLER] Konnte Ollama-Modell nicht laden
)
goto :eof
