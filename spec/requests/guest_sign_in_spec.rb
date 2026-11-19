require "rails_helper"

RSpec.describe "GuestSignIn", type: :request do
  describe "ゲストで試すボタン" do
    it "未ログインのトップと、ログイン画面に出す" do
      get root_path
      expect(response.body).to have_css("form[action='#{guest_sign_in_path}'] button", text: I18n.t("shared.guest_sign_in.button"))

      get new_user_session_path
      expect(response.body).to have_css("form[action='#{guest_sign_in_path}'] button", text: I18n.t("shared.guest_sign_in.button"))
    end
  end

  describe "POST /users/guest_sign_in" do
    it "ゲストを作ってログインし、トップへ戻して知らせを出す。トップには見本の品目と「ゲスト」の印が出る" do
      expect { post guest_sign_in_path }.to change(User.where(guest: true), :count).by(1)

      expect(response).to have_http_status(303)
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq(I18n.t("users.sessions.guest_sign_in.signed_in"))

      follow_redirect!
      expect(response.body).to have_css("header span", text: I18n.t("shared.header.guest"))
      GuestUserCreator::SAMPLE_ITEMS.each do |sample|
        expect(response.body).to include(sample[:name])
      end
    end

    it "ログイン中なら、ゲストを作らずにトップへ戻す" do
      sign_in create(:user)

      expect { post guest_sign_in_path }.not_to change(User, :count)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq(I18n.t("devise.failure.already_authenticated"))
    end

    it "同じ IP から決めた回数を超えると、ゲストを作らずに知らせを出す" do
      Users::SessionsController::GUEST_SIGN_INS_PER_HOUR.times do
        post guest_sign_in_path
        delete destroy_user_session_path
      end

      expect { post guest_sign_in_path }.not_to change(User, :count)
      expect(response).to have_http_status(303)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq(I18n.t("users.sessions.guest_sign_in.too_many"))
    end
  end
end
