class LunchflowConnection < ApplicationRecord
  include Syncable

  belongs_to :family
  has_many :lunchflow_accounts, dependent: :destroy
  has_many :accounts, through: :lunchflow_accounts

  validates :name, presence: true

  scope :active, -> { where(status: "active") }
  scope :ordered, -> { order(created_at: :desc) }

  def supabase_client
    @supabase_client ||= SupabaseClient.from_settings
  end
end
