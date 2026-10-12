:: description=plc linea 1
:: testPing=192.168.1.1
@echo off
rem Prueba de subcarpeta. No se ejecuta en update 006.
echo PLC Linea 1
pause
netsh interface ipv4 set address name="Wi-Fi" source=dhcp
netsh wlan connect name ="Oficina" ssid ="Oficina"
