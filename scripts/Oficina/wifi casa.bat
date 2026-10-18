:: description=conectar a la wifi de casa
:: testPing=192.168.2.3
netsh interface ipv4 set address name="Wi-Fi" source=dhcp
netsh wlan connect name="Lowi82B5" ssid="Lowi82B5"
