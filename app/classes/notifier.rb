class Notifier

  def self.send_notifications(shipment)
    case shipment.status
    when "in_transit"
      ShipmentMailer.delivery_notification(shipment).deliver_now
    when "delivery_exception"
      ShipmentMailer.delivery_exception_notification(shipment).deliver_now
    when "out_for_delivery"
      ShipmentMailer.out_for_delivery_notification(shipment).deliver_now
    when "delivered"
      ShipmentMailer.in_transit_notifications(shipment).deliver_now
    end
  end

end
