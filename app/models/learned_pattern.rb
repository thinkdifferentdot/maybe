class LearnedPattern < ApplicationRecord
  belongs_to :family
  belongs_to :category

  validates :merchant_name, presence: true
  validates :normalized_merchant, presence: true, uniqueness: { scope: :family_id }

  before_validation :normalize_merchant_name

  private

    def normalize_merchant_name
      return if merchant_name.blank?

      self.normalized_merchant = merchant_name.downcase.gsub(/[^a-z0-9\s]/, "").squeeze(" ").strip
    end
end
