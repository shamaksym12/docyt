# frozen_string_literal: true

class BaseItemValueCalculator
  private

  def calculate_value_with_operator(arg1, arg2, operator) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    value = 0.0
    return value unless arg1 && arg2

    case operator
    when '/'
      value = arg1 / arg2 if arg2.abs > 0.001
    when '+'
      value = arg1 + arg2
    when '-'
      value = arg1 - arg2
    when '%'
      value = arg1 / arg2 * 100.0 if arg2.abs > 0.001
    when '*'
      value = arg1 * arg2
    end
    value.round(2)
  end
end
