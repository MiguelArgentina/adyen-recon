module ApplicationHelper
    # Renders a badge span for statuses
  def status_badge(status)
    s = status.to_s
    label = case s
            when 'parsed_ok' then 'Parsed (OK)'
            when 'parsed_with_errors' then 'Parsed (Errors)'
            else s.humanize
            end
    css = case s
          when 'parsed_ok','generated' then 'badge badge-success'
          when 'parsed_with_errors','failed' then 'badge badge-error'
          when 'pending' then 'badge badge-muted'
          when 'parsed' then 'badge badge-muted' # legacy parsed treated as neutral
          else 'badge badge-muted'
          end
    content_tag(:span, label, class: css)
  end

    def money_minor(cents, currency, include_unit: true)
      unit = include_unit ? currency : ""
      number_to_currency((cents.to_i) / 100.0, unit: unit)
    end

    def currency_with_icon(currency)
      return "" if currency.blank?

      icon = case currency
             when "EUR" then "💶"
             when "USD" then "💵"
             when "GBP" then "💷"
             when "JPY" then "💴"
             else "💱"
             end

      "#{currency} #{icon}"
    end

  # Convert integer minor units to decimal currency
  def minor_to_amount(minor, currency = nil)
    return '' if minor.nil?
    number = minor.to_f / 100.0
    unit = currency.presence || ''
    sprintf("%s%.2f", unit.blank? ? '' : "#{unit} ", number)
  end
end
