class PinterestController < ApplicationController
  # def index
  #   @pinterest = Pinterest.new
  # end

  # def create
  #   @pinterest = Pinterest.new(pinterest_params)
  #   if @pinterest.save
  #     redirect_to root_path, notice: 'Pin was successfully created.'
  #   else
  #     render :index
  #   end
  # end

  def code
    # redirect_to Pinterest.authorization_url
    # retrieve access token

		puts "================== Params =================="
		puts params.inspect

		puts "================== Code =================="
		code = params[:code]
    puts code
		puts "================== End =================="

		render json: { code: code, params: params.inspect.to_json }

    # store access token

		# session[:access_token] = access_token
    # redirect_to root_path
	end

	def callback

		puts "================== Params =================="
		puts params.inspect

		puts "================== Code =================="
		code = params[:code]
		puts code
		puts "================== End =================="
		render json: { code: code, params: params.inspect.to_json }
	end

end