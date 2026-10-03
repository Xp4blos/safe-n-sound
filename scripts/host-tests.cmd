@echo off
rem Builds and runs the C++ engine tests on the PC (MSVC Build Tools + DevEco SDK cmake/ninja).
rem Set DEVECO_NATIVE to the SDK's openharmony\native folder if it is not the default below.
setlocal
if "%DEVECO_NATIVE%"=="" set "DEVECO_NATIVE=F:\huwaei\DevEco Studio\sdk\default\openharmony\native"
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul
set "PATH=%DEVECO_NATIVE%\build-tools\cmake\bin;%PATH%"
cd /d "%~dp0.."
cmake -S entry/src/main/cpp/tests -B build-host/tests -G Ninja -DCMAKE_CXX_COMPILER=cl -DCMAKE_BUILD_TYPE=Release >build-host\configure.log 2>&1 || (type build-host\configure.log & exit /b 1)
cmake --build build-host/tests || exit /b 1
build-host\tests\sns_tests.exe
