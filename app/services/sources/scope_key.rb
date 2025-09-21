# frozen_string_literal: true

module Sources
  module ScopeKey
    SEPARATOR = "::"
    HOLDER_PREFIX = "holder"

    module_function

    def build(account_code, account_id)
      code = normalize_part(account_code)
      holder = normalize_part(account_id)

      return nil if code.nil? && holder.nil?

      if code && holder
        "#{code}#{SEPARATOR}#{holder}"
      elsif code
        code
      else
        "#{HOLDER_PREFIX}#{SEPARATOR}#{holder}"
      end
    end

    def parse(scope)
      return [nil, nil] if scope.nil?

      str = scope.to_s.strip
      return [nil, nil] if str.empty?

      if str.start_with?("#{HOLDER_PREFIX}#{SEPARATOR}")
        [nil, normalize_part(str.split(SEPARATOR, 2)[1])]
      elsif str.include?(SEPARATOR)
        code, holder = str.split(SEPARATOR, 2)
        [normalize_part(code), normalize_part(holder)]
      else
        [normalize_part(str), nil]
      end
    end

    def normalize_part(value)
      str = value.to_s.strip
      str.present? ? str : nil
    end
    private_class_method :normalize_part
  end
end
