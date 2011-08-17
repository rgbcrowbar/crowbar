# Copyright 2011, Dell
#
# XXX: Dell Copyright
#

class RaidController < BarclampController
  def initialize
    @service_object = RaidService.new logger
  end
end
