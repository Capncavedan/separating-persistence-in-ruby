class Shipment < ActiveRecord::Base

  include ActiveMerchant::Shipping

  validates_presence_of :tracking_number

  belongs_to :user

  scope :outstanding, -> { where("state != 'delivered'") }
  scope :delivered, -> { where("state = 'delivered'") }

  before_save :increment_update_count
  before_validation :assign_carrier
  after_create :update_status

  state_machine :initial => :new do
    state :in_transit
    state :out_for_delivery
    state :delivery_exception
    state :delivered

    transition all => :in_transit,          :on => :in_transit
    transition all => :out_for_delivery,    :on => :out_for_delivery
    transition all => :delivery_exception,  :on => :delivery_exception
    transition all => :delivered,           :on => :delivered

    after_transition any - :in_transit          => :in_transit,         :do => :send_in_transit_notifications
    after_transition any - :out_for_delivery    => :out_for_delivery,   :do => :send_out_for_delivery_notifications
    after_transition any - :delivery_exception  => :delivery_exception, :do => :send_delivery_exception_notifications
    after_transition any - :delivered           => :delivered,          :do => :send_delivery_notifications
  end

  def send_delivery_notifications
    ShipmentMailer.delivery_notification(self).deliver_now
  end

  def send_delivery_exception_notifications
    ShipmentMailer.delivery_exception_notification(self).deliver_now
  end

  def send_out_for_delivery_notifications
    ShipmentMailer.out_for_delivery_notification(self).deliver_now
  end

  def send_in_transit_notifications
    ShipmentMailer.in_transit_notifications(self).deliver_now
  end

  def increment_update_count
    increment :update_count
  end

  def assign_carrier
    if self.tracking_number && self.carrier.blank?
      if t = TrackingNotice.tracking_numbers_from(self.tracking_number).first
        update_attributes carrier: t.carrier
      end
    end
  end

  def delivery_info
    delivered? ? "Delivered at #{self.delivered_at.to_s}" : 'unknown'
  end

  def self.create_shipments_from_email(msg)
    if user = User.find_by_tracking_email(msg)
      TrackingNotice.tracking_numbers_from(msg.body.decoded).each do |tracking_number|
        if shipment = user.shipments.find_by_tracking_number(tracking_number.code)
          shipment.update_attributes description: msg.subject
        else
          shipment = user.shipments.create(tracking_number: tracking_number.code, description: msg.subject)
        end
      end
    end
  end

  def self.find_or_create_with_tracking_notice(tracking_notice)
    shipment = where(tracking_number: tracking_notice.code).first
    return shipment if shipment
    create tracking_number: tracking_notice.code, carrier: tracking_notice.carrier
  end

  def self.update_all
    self.all.each(&:update_status)
  end

  def self.update_outstanding
    self.outstanding.each(&:update_status)
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

  def carrier_api
    case self.carrier
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

  def update_status
    updates = Hash.new

    begin
      tracking_info = self.carrier_api.find_tracking_info(tracking_number)
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
    self.send(state_call.to_sym) unless state_call.nil?
  end

end
