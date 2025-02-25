namespace :pin do
    desc "get pinterest boards"
    # Define the task
    task boards: :environment do
      pinterest_config = YAML.load_file Rails.root.join("config", "pinterest.yml")
      token = pinterest_config["access_token"]

      puts "================== Token =================="
      puts token
      puts "================== End =================="

      app_id = pinterest_config["app_id"]

      require "pinterest"

      # client = Pinterest::Client.new(access_token: token, client_id: app_id)

      client = Pinterest::Client.new(access_token: "pina_AMATKGAXABFS2AQAGAAB6B7JGFHRZFIBQBIQD67JR2VPPWLBBOND2GNQC46BV5IM77RBOW6425SAJIKHMJU435V7H5SWSDAA")

      puts "================== Client =================="
      puts client.inspect
      puts "================== End =================="
      response = client.boards.get_boards

      puts "================== Response =================="
      puts response.inspect
      puts "================== End =================="
    end
end
