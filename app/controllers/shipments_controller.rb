class ShipmentsController < ApplicationController

  def index
    @shipments = user.shipments.outstanding.order("updated_at DESC").limit(50)
  end

end
