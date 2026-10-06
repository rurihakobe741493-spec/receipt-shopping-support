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
end
