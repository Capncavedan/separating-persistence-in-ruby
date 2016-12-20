class ShipmentsController < ApplicationController

  def index
    @shipments = Shipments.for_index_page(user).decorate
  end

end
