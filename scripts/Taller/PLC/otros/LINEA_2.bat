:: description=plc linea 2
:: testPing=192.168.0.1
@echo off
rem Prueba de subcarpeta. No se ejecuta en update 006.
echo PLC Linea 1
netsh interface ipv4 set address name="Ethernet" source=dhcp
ipconfig
