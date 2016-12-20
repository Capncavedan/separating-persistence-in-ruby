class Shipment < ActiveRecord::Base

  validates_presence_of :tracking_number

  belongs_to :user

  scope :outstanding, -> { where("state != 'delivered'") }
  scope :delivered, -> { where("state = 'delivered'") }

  before_save :increment_update_count

  state_machine :initial => :new do
    state :in_transit
    state :out_for_delivery
    state :delivery_exception
    state :delivered

    transition all => :in_transit,          :on => :in_transit
    transition all => :out_for_delivery,    :on => :out_for_delivery
    transition all => :delivery_exception,  :on => :delivery_exception
    transition all => :delivered,           :on => :delivered

    after_transition any => any, :do => :send_notifications
  end

  def send_notifications
    Notifier.send_notifications(self)
  end

  def self.for_index_page(user)
    delivered.newest_to_oldest.limit(50)
  end

  private

  def increment_update_count
    increment :update_count
  end

end
