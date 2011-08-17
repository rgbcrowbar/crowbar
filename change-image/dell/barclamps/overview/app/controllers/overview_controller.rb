# Copyright 2011, Dell 
#
# XXX: Dell Copyright
#
# Author: RobHirschfeld 
# 
class OverviewController < ApplicationController

  require 'chef'
  
  #respond_to :html, :json
  
  def index
    taxmap = JSON::load File.open(File.join("config", "taxonomy-roles.json"), 'r')
    @layers = { :count=>-1, :unclassified=>0, :os=>0, :hardware=>0, :network=>0, :crowbar=>0, :monitoring=>0, :performance=>0, :metering=>0, :nova=>0, :swift=>0, :glance=>0, :nova_api=>0, :swift_api=>0, :glance_api=>0, :api_ips=>{}, :api_names=>{} }
    result = NodeObject.all
    result.each do |node|
      node.crowbar_run_list.each do |role|
        if taxmap.has_key? role.name
          taxmap[role.name].each do |layer|
            @layers[layer.to_sym] += 1
            if layer =~ /(.*)_api$/ 
              @layers[:api_ips][layer.to_sym] = node.public_ip
              @layers[:api_names][layer.to_sym] = node.shortname
            end
          end
        else
          @layers[:unclassified] += 1
        end
      end
    end
    @layers[:count] = result.count
    respond_to do |format|
      format.html { }
      format.json { render :json => @layers.to_json }
    end
    #respond_with @layers
  end    

end
