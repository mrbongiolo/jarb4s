class Item < ActiveRecord::Base

  validates :title, uniqueness: true
  #validates :title, :starting_price, :highest_price, :average_price, presence: true

  def starting_price
    Money.new(starting_price_cents, starting_price_currency).format(with_currency: true)
  end
  
  def starting_price=(value)
    value = Money.parse(value) if value.instance_of? String  # otherwise assume, that value is a Money object
    write_attribute :starting_price_cents,    value.cents
    write_attribute :starting_price_currency, value.currency_as_string
  end

  def highest_price
    Money.new highest_price_cents, highest_price_currency
  end
  
  def highest_price=(value)
    value = Money.parse(value) if value.instance_of? String  # otherwise assume, that value is a Money object
    write_attribute :highest_price_cents,    value.cents
    write_attribute :highest_price_currency, value.currency_as_string
  end

  def average_price
    Money.new average_price_cents, average_price_currency
  end
  
  def average_price=(value)
    value = Money.parse(value) if value.instance_of? String  # otherwise assume, that value is a Money object
    write_attribute :average_price_cents,    value.cents
    write_attribute :average_price_currency, value.currency_as_string
  end
end