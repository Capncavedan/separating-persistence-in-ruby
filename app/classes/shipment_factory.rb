class ShipmentFactory

  def self.create_shipments_from_email(msg)
    if user = User.find_by_tracking_email(msg)
      TrackingNotice.tracking_numbers_from(msg.body.decoded).each do |tracking_number|
        if shipment = user.shipments.find_by_tracking_number(tracking_number.code)
          shipment.update_attributes description: msg.subject
        else
          shipment = user.shipments.create(carrier: tracking_number.carrier, tracking_number: tracking_number.code, description: msg.subject)
        end
        ShipmentUpdater.update_status(shipment)
      end
    end
  end

  def self.find_or_create_with_tracking_notice(tracking_notice)
    shipment = where(tracking_number: tracking_notice.code).first
    return shipment if shipment
    create tracking_number: tracking_notice.code, carrier: tracking_notice.carrier
    ShipmentUpdater.update_status(shipment)
    shipment
  end

end
