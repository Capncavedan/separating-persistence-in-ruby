class ShipmentUpdater

  include ActiveMerchant::Shipping

  def self.update_all
    Shipment.all.each do |shipment|
      update_status(shipment)
    end
  end

  def self.update_outstanding
    Shipment.outstanding.each do |shipment|
      update_status(shipment)
    end
  end

  def ups_api
    @ups_api ||= UPS.new(login: UPS_LOGIN, password: UPS_PASSWORD, key: UPS_KEY)
  end

  def fedex_api
    @fedex_api ||= FedEx.new(test: CARRIER_TEST, login: FEDEX_LOGIN, password: FEDEX_PASSWORD, key: FEDEX_KEY, account: FEDEX_ACCOUNT)
  end

  def usps_api
    @usps_api ||= USPS.new(login: USPS_LOGIN, password: USPS_PASSWORD, test: CARRIER_TEST)
  end

  def carrier_api(shipment)
    case shipment.carrier
    when 'UPS'
      ups_api
    when 'FedEx'
      fedex_api
    when 'USPS'
      usps_api
    else
      nil
    end
  end

  def self.update_status(shipment)
    updates = Hash.new

    begin
      tracking_info = carrier_api(shipment).find_tracking_info(shipment.tracking_number)
    rescue Exception => e
      #puts "DBG: e: #{e}"
    end
    return if tracking_info.nil?

    if tracking_info.params["Shipment"] && tracking_info.params["Shipment"]["ScheduledDeliveryDate"]
      updates[:scheduled_delivery_date] = Date.parse(tracking_info.params["Shipment"]["ScheduledDeliveryDate"])
    end

    state_call = nil
    if event = tracking_info.shipment_events.last
      #logger.info "DBG: event.to_yaml: #{event.to_yaml}""
      updates[:carrier_state] = event.name.downcase unless event.name.blank?

      state_call = 'out_for_delivery'    if updates[:carrier_state] =~ /for delivery$/
      state_call = 'delivery_exception'  if updates[:carrier_state] =~ /delivery exception/
      state_call = 'delivered'           if updates[:carrier_state] =~ /delivered/
      state_call = 'in_transit'          if updates[:carrier_state] =~ /in transit/

      updates[:last_location] = "#{event.location.city}, #{event.location.state}" if event.location
    end

    tracking_info.shipment_events.select{|e| e.name.downcase == 'delivered'}.each do |event|
      updates[:delivered_at] = event.time
    end
    update_attributes updates
    logger.info "DBG: state_call: #{state_call}"
    shipment.send(state_call.to_sym) unless state_call.nil?
  end

end
