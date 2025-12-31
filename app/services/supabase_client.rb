class SupabaseClient
  attr_reader :url, :key

  def initialize(url:, key:)
    @url = url
    @key = key
  end

  # Class method to create client from settings with fallback hierarchy
  def self.from_settings
    url = ENV["SUPABASE_URL"] ||
          Rails.application.credentials.dig(:supabase, :url) ||
          Setting.supabase_url

    key = ENV["SUPABASE_SERVICE_ROLE_KEY"] ||
          Rails.application.credentials.dig(:supabase, :key) ||
          Setting.supabase_key

    raise "Supabase credentials not configured. Please set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY." if url.blank? || key.blank?

    new(url: url, key: key)
  end

  def from(table_name)
    QueryBuilder.new(self, table_name)
  end

  def invoke_function(function_name, body = {})
    uri = URI("#{@url}/functions/v1/#{function_name}")
    request = Net::HTTP::Post.new(uri)
    headers.each { |k, v| request[k] = v }
    request.body = body.to_json

    response = http_client(uri).request(request)

    raise "Supabase function error: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  end

  def execute_query(path, params = {})
    uri = URI("#{@url}/rest/v1/#{path}")
    uri.query = URI.encode_www_form(params) if params.any?

    request = Net::HTTP::Get.new(uri)
    headers.each { |k, v| request[k] = v }

    response = http_client(uri).request(request)

    raise "Supabase error: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  end

  class QueryBuilder
    def initialize(client, table_name)
      @client = client
      @table_name = table_name
      @filters = {}
      @select_columns = "*"
      @order_column = nil
      @order_direction = nil
      @limit_value = nil
      @single_record = false
    end

    def select(columns)
      @select_columns = columns
      self
    end

    def eq(column, value)
      @filters["#{column}"] = "eq.#{value}"
      self
    end

    def order(column, ascending: true)
      @order_column = column
      @order_direction = ascending ? "asc" : "desc"
      self
    end

    def limit(count)
      @limit_value = count
      self
    end

    def single
      @single_record = true
      @limit_value = 1
      self
    end

    def execute
      params = { select: @select_columns }
      @filters.each { |k, v| params[k] = v }
      params[:order] = "#{@order_column}.#{@order_direction}" if @order_column
      params[:limit] = @limit_value if @limit_value

      result = @client.execute_query(@table_name, params)
      @single_record ? result.first : result
    end
  end

  private

    def http_client(uri)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true
      http.read_timeout = 30
      http.open_timeout = 10

      # Configure SSL to handle certificate verification properly
      # This fixes "certificate verify failed (unable to get certificate CRL)" errors
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.cert_store = OpenSSL::X509::Store.new
      http.cert_store.set_default_paths

      http
    end

    def headers
      {
        "Authorization" => "Bearer #{@key}",
        "apikey" => @key,
        "Content-Type" => "application/json"
      }
    end
end
