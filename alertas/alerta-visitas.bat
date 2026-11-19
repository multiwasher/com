@echo off
rem Corre o alerta de visitas inversas (ver alerta-visitas.ps1).
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0alerta-visitas.ps1"
