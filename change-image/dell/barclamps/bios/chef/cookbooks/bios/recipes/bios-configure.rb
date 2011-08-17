
# Copyright (c) 2011 Dell Inc.
#


include_recipe "bios::bios-common"

debug = node[:bios][:debug]

# Run the statically linked version of setupbios on the ubuntu platform
pgmname = "/usr/sbin/setupbios"
if node[:platform].casecmp("ubuntu") == 0 
  pgmname = "/usr/sbin/setupbios.static"
end

# if we don't have the BIOS utility, we can't setup anything...
unless File.exists?(pgmname)
  @@bios_setup_enable = false 
  node["crowbar"]["status"]["bios"] << "Could not find #{pgmname}: Disabling setup"
end

def get_bag_item_safe (name, descr)
  data_bag_item("crowbar-data", name)
rescue
  log ("couldn't find #{descr} named #{name}")
  node["crowbar"]["status"]["bios"] << "Could not find #{descr} named #{name}"
  nil
end


product = node[:dmi][:system][:product_name].gsub(/\s+/, '')
default_set = "bios-set-#{product}-default"
bios_set = get_bag_item_safe(default_set, "bios defaults")

begin
  ## try to get the per-role set name.
  ## look for role+platform specific, and if not found, use role only.
  ## if neither found, use just defualts.
  bios_set_name = node[:crowbar][:hardware][:bios_set]
  setname = "bios-set-#{bios_set_name}-#{product}"
  bios_over =  get_bag_item_safe(setname, " overrides for #{setname} ")
  if (bios_over.nil?)
    setname = "bios-set-#{bios_set_name}"  
    bios_over ||=  get_bag_item_safe(setname, " overrides for #{setname} ")  
  end
  
  if bios_over.nil?
    log("no role overide settings, setting to defaults" ) { level :warn}
    values = bios_set[:attributes].dup
  else  
    log("using role overide settings from: #{setname}") { level :warn}
    values = bios_set[:attributes].merge(bios_over[:attributes])
  end
  
  bios_tokens "before changes" do
    action :dump
  end if debug
  
  
  values.each { | name, set_value|
    d4_token = set_value[0]
    bash "bios-update-#{name}-#{d4_token}-#{name}" do
      code <<-EOH
        echo /usr/sbin/#{pgmname} set #{d4_token}
        #{pgmname} set #{d4_token}
EOH
      returns [0,1]  # 1 = invalid token for this bios....
    end    
  }
  
  bios_tokens "after changes" do
    action :dump
  end if debug
  
end unless !@@bios_setup_enable or bios_set.nil? 

node.save
