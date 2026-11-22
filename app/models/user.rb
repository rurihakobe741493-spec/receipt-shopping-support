class User < ApplicationRecord
  # ゲストを残しておく時間（これより前に作ったゲストは、次のゲストを作るときに消す）
  GUEST_LIFETIME = 24.hours

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :rememberable, :validatable

  has_many :items, dependent: :destroy

  # 残しておく時間を過ぎたゲスト
  scope :expired_guests, -> { where(guest: true).where(created_at: ...GUEST_LIFETIME.ago) }
end
