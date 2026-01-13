{ lib, ... }:

with lib;

{
  options.services.cyberspace = {
    # Service registry for automatic dashboard updates
    registeredServices = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Display name of the service";
          };

          description = mkOption {
            type = types.str;
            description = "Short description of what the service does";
          };

          path = mkOption {
            type = types.str;
            default = "/";
            description = "URL path where the service is accessible";
          };

          icon = mkOption {
            type = types.str;
            default = "🔧";
            description = "Emoji icon for the service";
          };

          enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Whether the service is currently active";
          };

          port = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "Backend port (for display purposes)";
          };

          tags = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Tags/categories for the service (e.g., media, productivity)";
          };
        };
      });
      default = {};
      description = "Registry of services available on this system";
    };
  };

  config = {
    # Register the system dashboard itself
    services.cyberspace.registeredServices.dashboard = {
      name = "System Dashboard";
      description = "System information and service directory";
      path = "/";
      icon = "🚀";
      enabled = true;
      tags = ["system" "monitoring"];
    };
  };
}
