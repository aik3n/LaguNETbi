:: description=conectar a la wifi del mobil
:: testPing=8.8.8.8
netsh interface ipv4 set address name="Wi-Fi" source=dhcp
netsh wlan connect name="wifi Sam" ssid="wifi Sam"
