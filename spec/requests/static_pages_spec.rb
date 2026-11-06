require "rails_helper"

RSpec.describe "StaticPages", type: :request do
  describe "GET /" do
    before { get root_path }

    it "トップページのサービス紹介が表示される" do
      expect(response).to have_http_status(200)
      expect(response.body).to include("レシートを撮るだけ。")
    end

    it "アプリケーションヘルパーのアプリ名が表示される" do
      expect(response.body).to include(ApplicationController.helpers.app_name)
    end
  end

  describe "GET /（ログインしている）" do
    it "サービス紹介ではなく、ストック一覧（読み取りのフォーム）を表示する" do
      sign_in create(:user)
      get root_path

      expect(response).to have_http_status(200)
      expect(response.body).not_to include("レシートを撮るだけ。")
      expect(response.body).to have_css("form[action='#{receipt_scans_path}']")
    end
  end
end
