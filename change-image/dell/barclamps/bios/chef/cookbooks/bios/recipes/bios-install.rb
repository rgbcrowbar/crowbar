
# Copyright (c) 2011 Dell Inc.



include_recipe "bios::bios-common"


updater_map = {
  "C6100" => "/updates/PECC6100_BIOS_LX_1.57.BIN",
  "C1100" =>"/updates/PECC1100_BIOS_LX_R291694.BIN",
  "PowerEdge R710" => "/updates/BIOS_LX_2.0.7_R256670.BIN",
  "PowerEdge C2100" => "/updates/PECC2100_BIOS_LX_R291690.BIN",
  "PowerEdge C6105" =>"/updates/PECC6105_BIOS_LX_1.7.2.BIN"
}

product = node[:dmi][:system][:product_name]
pgm = updater_map[product]
if pgm.nil?
  log ("no updater for this (#{product}) platform") { level :warn }
  @@bios_update_enable = false
else
  # if we don't have the BIOS utility, we can't setup anything...
  @@bios_update_enable = false unless ::File.exists?(pgm)
end



begin
  cmd = "#{pgm} -q -f"
  log("bios-install #{cmd}]") {level :info} 

  # 0 means success and 3 means already at that level.  Should never get 0 anymore.
  bash "bios-flash" do
    code <<-EOH
      export TERM=dumb
      #{cmd}
      if [ $? -eq 2 -o $? -eq 6 ] ; then
        echo "Reboot required"
        reboot
        sleep 120
      fi
EOH
    returns [0,3]
  end
end if @@bios_update_enable

