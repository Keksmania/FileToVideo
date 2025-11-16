@echo off
setlocal enabledelayedexpansion
goto :main

:AddMissing
set /a missing_count+=1
set "missing_name!missing_count!=%~1"
set "missing_desc!missing_count!=%~2"
exit /b

:CheckCommand
where %~1 >nul 2>&1
if errorlevel 1 (
    call :AddMissing "%~2" "%~3"
) else (
    echo ^> %~2
)
exit /b

:CheckPython
"%PYTHON_CMD%" --version >nul 2>&1
if errorlevel 1 (
    call :AddMissing "Python 3.11" "Install Python 3.11 and ensure '%PYTHON_CMD%' is on PATH (set PYTHON_BIN to override)."
    exit /b
)
set "PY_VERSION="
for /f "tokens=1,2 delims= " %%a in ('"%PYTHON_CMD%" --version 2^>^&1') do (
    if /I "%%a"=="Python" set "PY_VERSION=%%b"
)
if not defined PY_VERSION (
    call :AddMissing "Python 3.11" "Unable to determine Python version."
    exit /b
)
set "PY_MAJOR="
set "PY_MINOR=0"
for /f "tokens=1,2 delims=." %%m in ("%PY_VERSION%") do (
    set "PY_MAJOR=%%m"
    set "PY_MINOR=%%n"
)
if not defined PY_MAJOR (
    call :AddMissing "Python 3.11" "Unable to parse Python version '%PY_VERSION%'."
    exit /b
)
set /a PY_MAJOR_NUM=%PY_MAJOR% >nul 2>&1
set /a PY_MINOR_NUM=%PY_MINOR% >nul 2>&1
if %PY_MAJOR_NUM% LSS 3 (
    call :AddMissing "Python >= 3.11" "Detected %PY_VERSION%. Upgrade recommended."
    exit /b
) else if %PY_MAJOR_NUM% EQU 3 if %PY_MINOR_NUM% LSS 11 (
    call :AddMissing "Python >= 3.11" "Detected %PY_VERSION%. Upgrade recommended."
    exit /b
)
set "PY_AVAILABLE=1"
echo ^> Python %PY_VERSION%
exit /b

:CheckTorch
if not defined PY_AVAILABLE exit /b
set "TORCH_SCRIPT=%TEMP%\f2yt_torch_%RANDOM%_%RANDOM%.py"
> "%TORCH_SCRIPT%" echo import importlib.util
>> "%TORCH_SCRIPT%" echo state = {'installed': False, 'cuda': False, 'version': None}
>> "%TORCH_SCRIPT%" echo spec = importlib.util.find_spec('torch')
>> "%TORCH_SCRIPT%" echo if spec is not None:
>> "%TORCH_SCRIPT%" echo ^    import torch
>> "%TORCH_SCRIPT%" echo ^    state['installed'] = True
>> "%TORCH_SCRIPT%" echo ^    state['version'] = getattr(torch, '__version__', 'unknown')
>> "%TORCH_SCRIPT%" echo ^    try:
>> "%TORCH_SCRIPT%" echo ^        state['cuda'] = bool(torch.cuda.is_available())
>> "%TORCH_SCRIPT%" echo ^    except Exception:
>> "%TORCH_SCRIPT%" echo ^        state['cuda'] = False
>> "%TORCH_SCRIPT%" echo print('INSTALLED=' + ('1' if state['installed'] else '0'))
>> "%TORCH_SCRIPT%" echo print('CUDA=' + ('1' if state['cuda'] else '0'))
>> "%TORCH_SCRIPT%" echo print('VERSION=' + (state['version'] or 'unknown'))
"%PYTHON_CMD%" "%TORCH_SCRIPT%" > "%TEMP%\torch_state.txt" 2>nul
del "%TORCH_SCRIPT%" >nul 2>&1
if errorlevel 1 (
    call :AddMissing "PyTorch" "Install the CUDA-enabled PyTorch build from pytorch.org."
    exit /b
)
set "TORCH_INSTALLED="
set "TORCH_CUDA="
set "TORCH_VERSION=unknown"
for /f "usebackq tokens=1,2 delims==" %%a in ("%TEMP%\torch_state.txt") do (
    if /I "%%a"=="INSTALLED" set "TORCH_INSTALLED=%%b"
    if /I "%%a"=="CUDA" set "TORCH_CUDA=%%b"
    if /I "%%a"=="VERSION" set "TORCH_VERSION=%%b"
)
del "%TEMP%\torch_state.txt" >nul 2>&1
if "!TORCH_INSTALLED!" NEQ "1" (
    call :AddMissing "PyTorch" "Install the CUDA-enabled PyTorch build from pytorch.org."
    exit /b
)
if "!TORCH_CUDA!"=="1" (
    echo ^> PyTorch !TORCH_VERSION! (CUDA available^)
) else (
    echo ^> PyTorch !TORCH_VERSION! (CUDA NOT detected^)
    call :AddMissing "CUDA for PyTorch" "torch.cuda.is_available() returned False. Install NVIDIA drivers/CUDA toolkit."
)
exit /b

:main
echo PythonFileToYoutube dependency check (Windows CMD)
set "missing_count=0"
if defined PYTHON_BIN (
    set "PYTHON_CMD=%PYTHON_BIN%"
) else (
    set "PYTHON_CMD=python"
)
set "PYTHON_CMD=%PYTHON_CMD:"=%"

call :CheckPython
call :CheckTorch
call :CheckCommand ffmpeg "FFmpeg" "Install FFmpeg and ensure it is on PATH."
call :CheckCommand 7z "7-Zip CLI" "Install 7-Zip / p7zip and expose '7z'."
call :CheckCommand par2 "PAR2" "Install par2cmdline and expose 'par2'."
call :CheckCommand nvidia-smi "CUDA / NVIDIA driver" "Install NVIDIA drivers/CUDA toolkit so 'nvidia-smi' works."

if %missing_count% EQU 0 (
    echo All dependencies satisfied.
    exit /b 0
)
echo.
echo Missing dependencies:
for /l %%i in (1,1,%missing_count%) do (
    echo - !missing_name%%i!: !missing_desc%%i!
)
exit /b 1
