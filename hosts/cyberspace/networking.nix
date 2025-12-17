
{
  ...
}: {
  networking = {
   hostname = "cyberspace"; 
   wireless.iwd = {
     enable = true;
     settings.General.EnableNetworkConfiguration = true;
   };
   nameservers = ["8.8.8.8" "8.8.4.4"];
   networking.networkmanager.wifi.macAdress = "stable-ssid";
  };
  
}
