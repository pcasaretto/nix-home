_: {
  networking = {
   hostName = "cyberspace";
   wireless.iwd = {
     enable = true;
     settings.General.EnableNetworkConfiguration = true;
   };
   nameservers = ["8.8.8.8" "8.8.4.4"];
   networkmanager.wifi.macAddress = "stable-ssid";

   # Configure dhcpcd to ignore malformed DHCP option 24 from router
   dhcpcd = {
     enable = true;
     extraConfig = ''
       # Ignore malformed DHCP option 24 (DNS domain name)
       # This prevents warnings about malformed embedded options
       nooption domain_name
     '';
   };
  };

}
