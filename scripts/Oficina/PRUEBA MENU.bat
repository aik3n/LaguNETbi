:: description=prueba de conexxion
@echo off
rem Script de prueba del menu. No cambia la red.
echo LaguNET bi - prueba de menu
pause
netsh interface ipv4 set address name="Ethernet" static 192.168.250.10 255.255.255.0
:: testPing=192.168.250.10
