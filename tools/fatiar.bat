@echo off
setlocal enabledelayedexpansion

rem Atalho para tools/fatiar_sprites.gd — evita digitar o caminho do binario e o
rem `--headless -s res://...` toda vez.
rem
rem     tools\fatiar.bat --entrada=C:\caminho\itens.png --listar
rem     tools\fatiar.bat --ajuda
rem
rem Acha a Godot em tres lugares, nesta ordem: a variavel GODOT, o PATH, e os
rem caminhos onde ela costuma estar nesta maquina. Se nao achar, diz onde por.

set "RAIZ=%~dp0.."

if defined GODOT (
    set "BIN=%GODOT%"
    goto :encontrado
)

where godot >nul 2>nul
if %errorlevel%==0 (
    set "BIN=godot"
    goto :encontrado
)

for %%C in (
    "D:\games\Godot_v4.7.1-stable_win64_console.exe"
    "D:\games\Godot_v4.7.1-stable_win64.exe"
    "C:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe"
) do (
    if exist %%C (
        set "BIN=%%~C"
        goto :encontrado
    )
)

echo.
echo Nao achei o executavel da Godot.
echo.
echo Aponte para ele com uma variavel e rode de novo:
echo     set GODOT=D:\caminho\Godot_v4.7.1-stable_win64_console.exe
echo     tools\fatiar.bat %*
echo.
exit /b 1

:encontrado
rem Sem argumento nenhum, ou com --janela, abre a versao com tela. Com
rem argumentos, roda no terminal.
if "%~1"=="" goto :janela
if /i "%~1"=="--janela" goto :janela

"%BIN%" --headless --path "%RAIZ%" -s res://tools/fatiar_sprites.gd -- %*
exit /b %errorlevel%

:janela
"%BIN%" --path "%RAIZ%" res://tools/fatiar_visual.tscn
exit /b %errorlevel%
