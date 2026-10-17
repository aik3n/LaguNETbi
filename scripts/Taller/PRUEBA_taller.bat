:: testPing=192.168.1.2
@echo off
rem Script de prueba. Update 006 NO lo ejecuta.
echo LaguNET bi popup test
pause
netsh interface ipv4 set address name="Ethernet" static 192.168.1.2 255.255.255.0
