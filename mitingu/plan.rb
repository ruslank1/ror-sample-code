class Plan < ActiveRecord::Base
  has_many :accounts
  belongs_to :site

  scope :public_signups, -> { where(public_signups: true) }
  scope :account_plans,  -> (account) { where("id = :id OR public_signups = :true", id: account.plan_id, true: true) } 

  enum plan_type: [:tiered_plan, :percentage_plan]
  # the rate of price
  def rate_for_reg_price(price, cur = "gbp")
    if tiered_plan?
      cur_pricing = send("pricing_#{cur.downcase}")
      sorted_keys = cur_pricing.keys.sort{ |a,b| a.to_i <=> b.to_i }
      sorted_keys.each_with_index do |key, i|
        if sorted_keys[i + 1]
          if price == key.to_i && price == 0
            return cur_pricing[key].to_f
          elsif price >= key.to_i && price < sorted_keys[i + 1].to_i
            return cur_pricing[sorted_keys[i + 1]].to_f
          end
        else
          return cur_pricing[key].to_f
        end
      end
    else
      if price > 0
        fee = send("perc_fee_#{cur.downcase}")
        cap = send("perc_cap_#{cur.downcase}")
        rate = ((price.to_f * perc_rate.to_f) + fee.to_f).round(2)
        return [rate,cap].min
      else
        return send("perc_free_fee_#{cur.downcase}")
      end
    end
  end

  def perc_rate_display
    perc_rate * 100
  end

  def method_missing(meth, *args, &block)
    if meth.to_s =~ /^pricing_(.+)$/
      cur = Currency.find($1)
      if cur
        cur_pricing = Hash.new
        self.pricing.each do |k,v|
          new_tier = (k.to_f * cur.multiplier).floor
          cur_pricing[new_tier.to_s] = rnd(v.to_f * cur.multiplier)
        end
        return cur_pricing
      else
        super
      end
    elsif meth.to_s =~ /^perc_fee_(.+)$/
      cur = Currency.find($1)
      if cur
        if perc_fee_override && perc_fee_override[cur.code.downcase]
          return perc_fee_override[cur.code.downcase].to_f
        else
          return rnd(perc_fee.to_f * cur.multiplier)
        end
      else
        super
      end
    elsif meth.to_s =~ /^perc_cap_(.+)$/
      cur = Currency.find($1)
      if cur
        if perc_cap_override && perc_cap_override[cur.code.downcase]
          return perc_cap_override[cur.code.downcase].to_f
        else
          return rnd(perc_cap.to_f * cur.multiplier)
        end
      else
        super
      end
    elsif meth.to_s =~ /^perc_free_fee_(.+)$/
      cur = Currency.find($1)
      if cur
        if perc_free_fee_override && perc_free_fee_override[cur.code.downcase]
          return perc_free_fee_override[cur.code.downcase].to_f
        else
          return rnd(perc_free_fee.to_f * cur.multiplier)
        end
      else
        super
      end
    else
      super 
    end
  end

  def all_pricing
    all = Hash.new
    Currency.all.each do |cur|
      code = cur.code.downcase
      all[code] = send("pricing_#{code}")
    end
    return all
  end

  def free_chargable?
    rate_for_reg_price(0) != 0
  end

  private

  def rnd(num)
    return (num * 20).ceil / 20.0
  end

end
