class SupabaseClient
  attr_reader :url

  def initialize(url:, key:)
    @url = url
    @key = key
  end

  def from(table_name)
    QueryBuilder.new(self, table_name)
  end

  def invoke_function(function_name, body = {})
    uri = URI("#{@url}/functions/v1/#{function_name}")
    request = Net::HTTP::Post.new(uri)
    headers.each { |k, v| request[k] = v }
    request.body = body.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    raise "Supabase function error: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  end

  def execute_query(path, params = {})
    uri = URI("#{@url}/rest/v1/#{path}")
    uri.query = URI.encode_www_form(params) if params.any?

    request = Net::HTTP::Get.new(uri)
    headers.each { |k, v| request[k] = v }

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

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

    def headers
      {
        "Authorization" => "Bearer #{@key}",
        "apikey" => @key,
        "Content-Type" => "application/json"
      }
    end
end
