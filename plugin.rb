# name: df-core
# about: A common functionality of my Discourse plugins.
# version: 1.2.0
# authors: Dmitry Fedyuk
# url: https://discourse.pro
#register_asset 'javascripts/lib/sprintf.js'
register_asset 'javascripts/admin.js', :admin
register_asset 'lib/magnific-popup/main.js'
register_asset 'stylesheets/main.scss'
pluginAppPath = "#{Rails.root}/plugins/df-core/app/"
Discourse::Application.config.autoload_paths += Dir["#{pluginAppPath}models", "#{pluginAppPath}controllers"]
# 2016-12-19
# Требуется для гема «airbrake»: https://rubygems.org/gems/airbrake/versions/5.6.1
gem 'airbrake-ruby', '1.6.0'
# 2016-12-19
# https://meta.discourse.org/t/54462
# «The Plugin::Instance.find_all method incorrectly treats every file with the «plugin.rb» name
# as a Discourse plugin».
gem 'dfg-airbrake', '5.6.2', {require_name: 'airbrake'}
# 2016-12-19
# В Airbrake 5 API поменялся:
# https://github.com/airbrake/airbrake/blob/v5.6.1/docs/Migration_guide_from_v4_to_v5.md#general-changes
Airbrake.configure do |c|
=begin
2016-12-19
«The development_environments option was renamed to ignore_environments.
Its behaviour was also slightly changed.
By default, the library sends exceptions in all environments,
so you don't need to assign an empty Array anymore to get this behavior.»
https://github.com/airbrake/airbrake/blob/v5.6.1/docs/Migration_guide_from_v4_to_v5.md#development-environments
=end
	# 2016-12-19
	# https://github.com/airbrake/airbrake/blob/v5.6.1/docs/Migration_guide_from_v4_to_v5.md#port
	c.host = 'http://log.dmitry-fedyuk.com'
	# 2016-12-19
	# Берётся из адреса: http://log.dmitry-fedyuk.com/apps/559ed7e76d61673d30000000
	c.project_id = '559ed7e76d61673d30000000'
	c.project_key = 'c07658a7417f795847b2280bc2fd7a79'
=begin
2016-12-19
«You must set this if you want Airbrake backtraces to link to GitHub.
In Rails projects this value should typically be equal to Rails.root.»
https://github.com/airbrake/airbrake/blob/v5.6.1/docs/Migration_guide_from_v4_to_v5.md#user-content-project-root

«Providing this option helps us to filter out repetitive data from backtrace frames
and link to GitHub files from our dashboard.»
https://github.com/airbrake/airbrake-ruby/blob/v1.6.0/README.md#root_directory

Заметил, что отныне без этой опции стек вызовов не раскрашивается.
=end
	c.root_directory = Rails.root
end
=begin
2016-12-19
Используется из dfg-paypal:
https://github.com/discourse-pro/dfg-paypal/blob/0.8.2/lib/paypal/nvp/request.rb#L4
https://github.com/discourse-pro/dfg-paypal/blob/0.8.2/lib/paypal/payment/response/reference.rb#L4
=end
gem 'attr_required', '1.0.0'
# 2016-12-12
# Оригинальный https://github.com/nov/paypal-express перестал работать:
# https://github.com/nov/paypal-express/issues/99
# Мой гем: https://rubygems.org/gems/dfg-paypal
# https://github.com/discourse-pro/dfg-paypal
gem 'dfg-paypal', '0.8.2', {require_name: 'paypal'}
Paypal::Util.module_eval do
=begin
	2015-07-10
	Чтобы гем не передавал параметры со значением "0.00"
	(чувствую, у меня из-за них пока не работает...)
	{
	  "PAYERID" => "UES9EX5HHA8ZJ",
	  "PAYMENTREQUEST_0_AMT" => "0.00",
	  "PAYMENTREQUEST_0_PAYMENTACTION" => "Sale",
	  "PAYMENTREQUEST_0_SHIPPINGAMT" => "0.00",
	  "PAYMENTREQUEST_0_TAXAMT" => "0.00",
	  "TOKEN" => "EC-6MJ94873BM276735F"
	}
=end
	def self.formatted_amount(x)
		result = sprintf("%0.2f", BigDecimal.new(x.to_s).truncate(2))
		'0.00' == result ? '' : result
	end
end
Paypal::NVP::Request.module_eval do
	def post(method, params)
		allParams = common_params.merge(params).merge(:METHOD => method)
=begin
2016-12-19
В Airbrake 5 синтаксис notify изменился:
https://github.com/airbrake/airbrake/blob/v5.6.1/docs/Migration_guide_from_v4_to_v5.md#notify
«The support for api_key, error_message, backtrace, parameters and session was removed.»
https://github.com/airbrake/airbrake-ruby/blob/v1.6.0/README.md#airbrakenotify
=end
		Airbrake.notify "POST #{method}", allParams.merge('URL' => self.class.endpoint)
		RestClient.post(self.class.endpoint, allParams)
	end
	alias_method :core__request, :request
	def request(method, params = {})
		# http://stackoverflow.com/a/4686157
		if :SetExpressCheckout == method
			# 2015-07-10
			# Это поле обязательно для заполнение, однако гем его почему-то не заполняет.
			# «Version of the callback API.
			# This field is required when implementing the Instant Update Callback API.
			# It must be set to 61.0 or a later version.
			# This field is available since version 61.0.»
			# https://developer.paypal.com/docs/classic/api/merchant/SetExpressCheckout_API_Operation_NVP/#localecode
			params[:CALLBACKVERSION] = self.version
		end
		core__request method, params
	end
end
require 'site_setting_extension'
SiteSettingExtension.module_eval do
	alias_method :core__types, :types
	def types
		result = @types
		if not result
			result = core__types
			result[:df_editor] = result.length + 1;
			# 2015-08-31
			# input type=password
			result[:df_password] = result.length + 1;
			# 2015-08-27
			# textarea без редактора
			result[:df_textarea] = result.length + 1;
			result[:paypal_buttons] = result.length + 1;
			result[:paid_membership_plans] = result.length + 1;
		end
		return result
	end
end
after_initialize do
	module ::Df::Core
		class Engine < ::Rails::Engine
			engine_name 'df_core'
			isolate_namespace ::Df::Core
		end
	end
	::Df::Core::Engine.routes.draw do
		get '/thumb/:width/:height' => 'thumb#index'
	end
	Discourse::Application.routes.append do
		mount ::Df::Core::Engine, at: '/df/core'
	end	
end