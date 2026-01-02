module AccountsHelper
  def summary_card(title:, &block)
    content = capture(&block)
    render "accounts/summary_card", title: title, content: content
  end

  def accountable_type_options
    Accountable::TYPES.map do |type|
      [ type.constantize.display_name, type ]
    end
  end

  def subtype_options_for(accountable_type)
    return [] unless accountable_type.present?

    klass = accountable_type.constantize
    return [] unless klass.const_defined?(:SUBTYPES)

    klass::SUBTYPES.map { |key, labels| [ labels[:long], key ] }
  end
end
