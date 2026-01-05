{pkgs}:
pkgs.writeTextFile {
  name = "gamecontroller-udev-rules";
  text = builtins.readFile ./gamecontroller.rules;
  destination = "/etc/udev/rules.d/70-gamecontroller.rules";
}
