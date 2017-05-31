require 'sinatra'
require 'oci8'
require 'sinatra/json'
require_relative 'db/init'
require 'rack-flash'

def sql(cmd)
  $db ||= DB::connect
  $db.exec cmd
end

def parse_sql(cmd)
  $db ||= DB::connect
  $db.parse cmd
end

def db
  $db ||= DB::connect
end

class Application < Sinatra::Base
  enable :sessions
  use Rack::Flash

  get '/' do
    @rand = sql('SELECT 100 FROM dual').fetch[0].to_i
    erb :hello, :layout => :layout
  end

  get '/client' do
    @flash = flash

    erb :client, :layout => :layout
  end

  post '/client' do

    begin
      cursor = db.parse('
        INSERT INTO CLIENTS (LAST_NAME, FIRST_NAME, MIDDLE_NAME, DOCUMENT) VALUES
         (:1, :2, :3, :4) ')

      cursor.exec params['last_name'], params['first_name'],
           params['middle_name'], params['document']
      db.commit
      flash[:success] = "User successful create"

    rescue OCI8::Exception => e
      flash[:error] = e.to_s
    end

    @flash = flash
    erb :client, :layout => :layout
  end

  get '/order' do
    cursor = db.parse('SELECT last_name, first_name, middle_name FROM clients')
    cursor.exec
    @users = []
    while (user = cursor.fetch_hash)
      @users << user
    end

    cursor = db.parse("SELECT id, name FROM cities")
    cursor.exec
    @cities = []
    while (city = cursor.fetch_hash)
      @cities << city
    end

    erb :order, :layout => :layout
  end

  post '/getRoutes' do
    # departure_city = db.exec("SELECT id FROM cities WHERE name = '#{params['departure_city']}'").fetch_hash["ID"]
    # arrival_city = db.exec("SELECT id FROM cities WHERE name = '#{params['arrival_city']}'").fetch_hash["ID"]

    p params

    cursor = db.parse("
WITH connection (departure_city, arrival_city, flights, path, arrival_airport,
    departure_airport, arrival_date, hops) AS
  (
  (SELECT
      c1.NAME,
      c2.NAME,
      to_char(f.ID),
      c1.NAME ||' - ' ||c2.NAME,
      a2.NAME,
      a1.NAME,
      f.ARRIVAL_DATE,
      1 hops
    FROM
      FLIGHTS f
      JOIN AIRPORTS a1 ON f.DEPARTURE_AIRPORT = a1.ID
      JOIN CITIES c1 ON a1.CITY_ID = c1.ID
      JOIN AIRPORTS a2 ON f.ARRIVAL_AIRPORT = a2.ID
      JOIN CITIES c2 ON a2.CITY_ID = c2.ID
    WHERE f.DEPARTURE_DATE >= to_date('#{params['arrival_date']}','YYYY-MM-DD') AND
f.DEPARTURE_DATE < to_date('#{params['arrival_date']}','YYYY-MM-DD') + 1 )
  UNION ALL
  (SELECT
    c.departure_city,
    c2.NAME,
    c.flights || ',' || to_char(f.ID),
    c.path ||' - ' || c2.NAME,
    a2.NAME,
    c.departure_airport,
    f.ARRIVAL_DATE,
    c.hops + 1
   FROM
    (FLIGHTS f
      JOIN AIRPORTS a1 ON f.DEPARTURE_AIRPORT = a1.ID
      JOIN CITIES c1 ON a1.CITY_ID = c1.ID
      JOIN AIRPORTS a2 ON f.ARRIVAL_AIRPORT = a2.ID
      JOIN CITIES c2 ON a2.CITY_ID = c2.ID)
      JOIN connection c ON c1.NAME = c.arrival_city
          AND f.DEPARTURE_DATE - c.arrival_date >= 0.04
          AND f.DEPARTURE_DATE - c.arrival_date < 0.5
          AND NOT c.path LIKE '%'|| c2.NAME ||'%'
          AND c.arrival_city <> c2.NAME
          AND c.hops < 4
  )
)
SELECT * FROM connection
WHERE departure_city = '#{params['departure_city']}' AND arrival_city = '#{params['arrival_city']}'
")
    cursor.exec

    @res_to = []

    while (flight = cursor.fetch_hash)
      flight['HOPS'] = flight['HOPS'].to_i
      @res_to << flight
    end

    names = params["client"].split ' '

    cursor = db.parse "SELECT ID FROM clients WHERE LAST_NAME = '#{names[0]}' AND
FIRST_NAME = '#{names[1]}' AND MIDDLE_NAME = '#{names[2]}'"
    cursor.exec

    @client = cursor.fetch_hash

    @res_from = []

    if params['return_date'].length > 0
      cursor = db.parse("
WITH connection (departure_city, arrival_city, flights, path, arrival_airport,
    departure_airport, arrival_date, hops) AS
  (
  (SELECT
      c1.NAME,
      c2.NAME,
      to_char(f.ID),
      c1.NAME ||' - ' ||c2.NAME,
      a2.NAME,
      a1.NAME,
      f.ARRIVAL_DATE,
      1 hops
    FROM
      FLIGHTS f
      JOIN AIRPORTS a1 ON f.DEPARTURE_AIRPORT = a1.ID
      JOIN CITIES c1 ON a1.CITY_ID = c1.ID
      JOIN AIRPORTS a2 ON f.ARRIVAL_AIRPORT = a2.ID
      JOIN CITIES c2 ON a2.CITY_ID = c2.ID
    WHERE f.DEPARTURE_DATE >= to_date('#{params['return_date']}','YYYY-MM-DD') AND
f.DEPARTURE_DATE < to_date('#{params['return_date']}','YYYY-MM-DD') + 1 )
  UNION ALL
  (SELECT
    c.departure_city,
    c2.NAME,
    c.flights || ',' || to_char(f.ID),
    c.path ||' - ' || c2.NAME,
    a2.NAME,
    c.departure_airport,
    f.ARRIVAL_DATE,
    c.hops + 1
   FROM
    (FLIGHTS f
      JOIN AIRPORTS a1 ON f.DEPARTURE_AIRPORT = a1.ID
      JOIN CITIES c1 ON a1.CITY_ID = c1.ID
      JOIN AIRPORTS a2 ON f.ARRIVAL_AIRPORT = a2.ID
      JOIN CITIES c2 ON a2.CITY_ID = c2.ID)
      JOIN connection c ON c1.NAME = c.arrival_city
          AND f.DEPARTURE_DATE - c.arrival_date >= 0.04
          AND f.DEPARTURE_DATE - c.arrival_date < 0.5
          AND NOT c.path LIKE '%'|| c2.NAME ||'%'
          AND c.arrival_city <> c2.NAME
          AND c.hops < 4
  )
)
SELECT * FROM connection
WHERE departure_city = '#{params['arrival_city']}' AND arrival_city = '#{params['departure_city']}'
")
      cursor.exec

      while (flight = cursor.fetch_hash)
        flight['HOPS'] = flight['HOPS'].to_i
        @res_from << flight
      end
    end


    res = {
        :flights_to => @res_to,
        :flights_from => @res_from,
        :client => @client,
        :order_date => params['order_date'],
    }

    json res
  end

  post '/createOrder' do
    p params

    cursor = db.parse "
      INSERT INTO ORDERS (ID, CLIENT_ID, ORDER_DATE) VALUES
        (ORDERS_ID_SEQ.nextval, #{params['client_id']}, to_date('#{params['order_date']}', 'YYYY-MM-DD'))
    "

    cursor.exec
    cursor = db.parse "SELECT ORDERS_ID_SEQ.currval FROM dual"
    cursor.exec
    order_id = cursor.fetch[0].to_i
    p order_id
    db.commit


    flights_to = params['flights_to'].split ','
    flights_to.each_with_index do |flight_id, index|
      cursor = db.parse "
                        INSERT INTO ROUTES (ORDER_ID, FLIGHT_ID, POSITION, REVERSE) VALUES
                        (#{order_id}, #{flight_id}, #{index + 1}, 0)
                      "
      cursor.exec
    end

    flights_from = params['flights_from'].split ','
    flights_from.each_with_index do |flight_id, index|
      cursor = db.parse "
                        INSERT INTO ROUTES (ORDER_ID, FLIGHT_ID, POSITION, REVERSE) VALUES
                          (#{order_id}, #{flight_id}, #{index + 1}, 1)
                        "
      cursor.exec
    end
    db.commit

    redirect "/order/#{order_id}"
  end

  get '/order/:id' do
    cursor = db.parse "
              SELECT
                concat(concat(concat(concat(cl.LAST_NAME, ' '), cl.FIRST_NAME), ' '), cl.MIDDLE_NAME) CLIENT,
                cl.DOCUMENT,
                o.ORDER_DATE
              FROM
                ORDERS o
                JOIN CLIENTS cl ON o.CLIENT_ID = cl.ID
              WHERE o.ID = #{params[:id]}
             "
    cursor.exec

    @order_info = cursor.fetch_hash
    p @order_info

    if @order_info.nil?
      status 404
      halt "There is no order with #{params[:id]} id"
    end

    @order_info['DOCUMENT'] = @order_info['DOCUMENT'].to_i

    cursor = db.parse "
                        SELECT
                          r.POSITION,
                          f.CODE,
                          al.NAME          airline,
                          f.DEPARTURE_DATE departure_date,
                          a_d.NAME         departure_airport,
                          c_d.NAME         departure_city,
                          c_d.COUNTRY      departure_country,
                          f.ARRIVAL_DATE   arrival_date,
                          a_a.NAME         arrival_airport,
                          c_a.NAME         arrival_city,
                          c_a.COUNTRY      arrival_country
                        FROM
                          ROUTES r
                          JOIN ORDERS o ON r.ORDER_ID = o.ID
                          JOIN FLIGHTS f ON r.FLIGHT_ID = f.ID
                          JOIN AIRPORTS a_d ON f.DEPARTURE_AIRPORT = a_d.ID
                          JOIN AIRPORTS a_a ON f.ARRIVAL_AIRPORT = a_a.ID
                          JOIN CITIES c_d ON a_d.CITY_ID = c_d.ID
                          JOIN CITIES c_a ON a_a.CITY_ID = c_a.ID
                          JOIN AIRLINES al ON f.AIRLINE_ID = al.ID
                        WHERE o.ID = #{params[:id]} AND REVERSE = 0
                        ORDER BY r.REVERSE, r.POSITION
                      "
    cursor.exec

    @flights_to = []
    while (flight = cursor.fetch_hash)
      @flights_to << flight
    end

    cursor = db.parse "
                        SELECT
                          r.POSITION,
                          f.CODE,
                          al.NAME          airline,
                          f.DEPARTURE_DATE departure_date,
                          a_d.NAME         departure_airport,
                          c_d.NAME         departure_city,
                          c_d.COUNTRY      departure_country,
                          f.ARRIVAL_DATE   arrival_date,
                          a_a.NAME         arrival_airport,
                          c_a.NAME         arrival_city,
                          c_a.COUNTRY      arrival_country
                        FROM
                          ROUTES r
                          JOIN ORDERS o ON r.ORDER_ID = o.ID
                          JOIN FLIGHTS f ON r.FLIGHT_ID = f.ID
                          JOIN AIRPORTS a_d ON f.DEPARTURE_AIRPORT = a_d.ID
                          JOIN AIRPORTS a_a ON f.ARRIVAL_AIRPORT = a_a.ID
                          JOIN CITIES c_d ON a_d.CITY_ID = c_d.ID
                          JOIN CITIES c_a ON a_a.CITY_ID = c_a.ID
                          JOIN AIRLINES al ON f.AIRLINE_ID = al.ID
                        WHERE o.ID = #{params[:id]} AND REVERSE = 1
                        ORDER BY r.REVERSE, r.POSITION
                      "
    cursor.exec

    @flights_from = []
    while (flight = cursor.fetch_hash)
      @flights_from << flight
    end

    res = {
        order_info: @order_info,
        flights_to: @flights_to,
        flights_from: @flights_from
    }

    erb :order_show, :layout => :layout
  end

end