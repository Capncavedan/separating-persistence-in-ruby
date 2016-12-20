class ShipmentDecorator < Draper::Decorator

  delegate_all

  def delivery_info
    delivered? ? "Delivered at #{self.delivered_at.to_s}" : 'unknown'
  end

end
